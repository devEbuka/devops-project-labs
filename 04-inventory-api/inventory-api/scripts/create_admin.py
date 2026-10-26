"""One-off admin bootstrap. Supply credentials via environment, never CLI args."""
import os
from sqlalchemy import select
from app.auth import hash_password
from app.database import SessionLocal
from app.models import User


def main():
    email = os.environ.get("ADMIN_EMAIL", "").strip().lower()
    password = os.environ.get("ADMIN_PASSWORD", "")
    if not email or "@" not in email or len(password) < 12:
        raise SystemExit("Set ADMIN_EMAIL and ADMIN_PASSWORD (12+ characters) securely")
    with SessionLocal.begin() as db:
        existing = db.scalar(select(User).where(User.email == email))
        if existing:
            raise SystemExit("Account exists; refusing to change its role or password")
        db.add(User(email=email, password_hash=hash_password(password), role="admin"))
    print("Admin account created")


if __name__ == "__main__":
    main()
