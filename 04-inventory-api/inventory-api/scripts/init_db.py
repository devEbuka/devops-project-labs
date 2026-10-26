"""One-off schema initializer. Run once via SSM, not on every app boot."""
from app.database import Base, engine
from app import models  # noqa: F401 — registers models

if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
    print("Database schema initialized (existing tables left intact).")
