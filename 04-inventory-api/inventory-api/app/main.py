import logging
import os
import socket
from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException, Query, Response
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from sqlalchemy.orm import Session

from app.auth import admin_only, create_token, current_user, hash_password, verify_password, hasher
from app.auth_schemas import LoginRequest, RegisterRequest, TokenResponse, UserOut
from app.config import settings
from app.database import get_db
from app.models import Product, StockMovement, User
from app.schemas import ProductCreate, ProductOut, ProductUpdate, StockAdjust, StockMovementOut

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)
app = FastAPI(title=settings.app_name, version="2.0.0")

# Spend comparable CPU time hashing a dummy password for nonexistent accounts.
DUMMY_HASH = hash_password("not-the-correct-password")
MAX_FAILURES = 5
LOCK_MINUTES = 15


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}


@app.get("/ready", tags=["health"])
def ready(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ready"}
    except SQLAlchemyError:
        logger.exception("Database readiness check failed")
        raise HTTPException(status_code=503, detail="Database unavailable")


@app.get("/instance", tags=["diagnostics"])
def instance(user: User = Depends(current_user)):
    return {"hostname": socket.gethostname(), "instance_id": os.getenv("INSTANCE_ID", "unknown")}


@app.post("/auth/register", response_model=UserOut, status_code=201, tags=["auth"])
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    user = User(email=str(payload.email).lower(), password_hash=hash_password(payload.password), role="viewer")
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Account already exists")
    db.refresh(user)
    return user


@app.post("/auth/login", response_model=TokenResponse, tags=["auth"])
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    # Row lock serializes failure counters across ASG instances (PostgreSQL).
    user = db.scalar(select(User).where(User.email == str(payload.email).lower()).with_for_update())
    if user is None:
        verify_password(payload.password, DUMMY_HASH)
        raise HTTPException(status_code=401, detail="Invalid credentials")
    now = datetime.now(timezone.utc)
    if user.locked_until is not None:
        until = user.locked_until
        if until.tzinfo is None:
            until = until.replace(tzinfo=timezone.utc)
        if until > now:
            raise HTTPException(status_code=429, detail="Account temporarily locked. Try later")
        user.locked_until = None
        user.failed_attempts = 0
    valid = verify_password(payload.password, user.password_hash)
    if not valid or not user.is_active:
        user.failed_attempts += 1
        if user.failed_attempts >= MAX_FAILURES:
            user.locked_until = now + timedelta(minutes=LOCK_MINUTES)
        db.commit()
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if hasher.check_needs_rehash(user.password_hash):
        user.password_hash = hash_password(payload.password)
    user.failed_attempts = 0
    user.locked_until = None
    db.commit()
    return TokenResponse(access_token=create_token(user))


@app.get("/auth/me", response_model=UserOut, tags=["auth"])
def me(user: User = Depends(current_user)):
    return user


@app.post("/products", response_model=ProductOut, status_code=201, tags=["products"])
def create_product(payload: ProductCreate, db: Session = Depends(get_db), user: User = Depends(admin_only)):
    product = Product(**payload.model_dump())
    db.add(product)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="SKU already exists")
    db.refresh(product)
    return product


@app.get("/products", response_model=list[ProductOut], tags=["products"])
def list_products(limit: int = Query(default=50, ge=1, le=100), offset: int = Query(default=0, ge=0),
                  db: Session = Depends(get_db), user: User = Depends(current_user)):
    return db.scalars(select(Product).order_by(Product.id).offset(offset).limit(limit)).all()


@app.get("/products/{product_id}", response_model=ProductOut, tags=["products"])
def get_product(product_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@app.patch("/products/{product_id}", response_model=ProductOut, tags=["products"])
def update_product(product_id: int, payload: ProductUpdate, db: Session = Depends(get_db), user: User = Depends(admin_only)):
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    return product


@app.delete("/products/{product_id}", status_code=204, tags=["products"])
def delete_product(product_id: int, db: Session = Depends(get_db), user: User = Depends(admin_only)):
    product = db.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    db.delete(product)
    db.commit()
    return Response(status_code=204)


@app.post("/products/{product_id}/stock", response_model=StockMovementOut, tags=["inventory"])
def adjust_stock(product_id: int, payload: StockAdjust, db: Session = Depends(get_db), user: User = Depends(admin_only)):
    if payload.delta == 0:
        raise HTTPException(status_code=422, detail="Stock adjustment must be non-zero")
    product = db.scalar(select(Product).where(Product.id == product_id).with_for_update())
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    new_quantity = product.quantity + payload.delta
    if new_quantity < 0:
        raise HTTPException(status_code=409, detail="Insufficient stock")
    product.quantity = new_quantity
    movement = StockMovement(product_id=product.id, delta=payload.delta,
                             resulting_quantity=new_quantity, reason=payload.reason)
    db.add(movement)
    db.commit()
    db.refresh(movement)
    return movement


@app.get("/products/{product_id}/movements", response_model=list[StockMovementOut], tags=["inventory"])
def list_movements(product_id: int, db: Session = Depends(get_db), user: User = Depends(current_user)):
    if db.get(Product, product_id) is None:
        raise HTTPException(status_code=404, detail="Product not found")
    return db.scalars(select(StockMovement).where(StockMovement.product_id == product_id)
                      .order_by(StockMovement.id.desc()).limit(100)).all()


@app.get("/inventory/summary", tags=["inventory"])
def inventory_summary(db: Session = Depends(get_db), user: User = Depends(current_user)):
    count, units, value = db.execute(select(func.count(Product.id),
        func.coalesce(func.sum(Product.quantity), 0),
        func.coalesce(func.sum(Product.price * Product.quantity), 0))).one()
    return {"products": count, "total_units": units, "inventory_value": str(value)}
