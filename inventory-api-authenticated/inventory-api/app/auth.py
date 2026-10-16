"""Authentication: Argon2id password hashes, short-lived HS256 JWTs, DB-backed roles."""
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, VerificationError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import InvalidTokenError
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import User

hasher = PasswordHasher()
bearer = HTTPBearer(auto_error=False)
AUTH_ERROR = HTTPException(status_code=401, detail="Invalid or expired credentials", headers={"WWW-Authenticate": "Bearer"})


def hash_password(password: str) -> str:
    return hasher.hash(password)


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        return hasher.verify(stored_hash, password)
    except (VerifyMismatchError, VerificationError):
        return False


def create_token(user: User) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {"sub": str(user.id), "iat": now, "exp": now + timedelta(minutes=settings.jwt_expire_minutes)},
        settings.jwt_secret,
        algorithm="HS256",
    )


def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AUTH_ERROR
    try:
        payload = jwt.decode(credentials.credentials, settings.jwt_secret, algorithms=["HS256"], options={"require": ["exp", "sub", "iat"]})
        subject = payload["sub"]
        if not isinstance(subject, str) or not subject.isdecimal():
            raise InvalidTokenError("Invalid subject")
        user = db.get(User, int(subject))
    except (InvalidTokenError, ValueError):
        raise AUTH_ERROR
    if user is None or not user.is_active:
        raise AUTH_ERROR
    return user


def admin_only(user: User = Depends(current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return user
