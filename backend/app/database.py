import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Railway sets DATABASE_URL automatically; fallback to local dev
_raw_url = os.environ.get(
    "DATABASE_URL",
    "postgresql://postgres:test.@localhost:5432/family_planner"
)
# SQLAlchemy requires postgresql:// not postgres:// (Heroku/Railway compat)
DATABASE_URL = _raw_url.replace("postgres://", "postgresql://", 1)

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,      # verify connection before use (handles stale connections)
    pool_size=5,
    max_overflow=10,
    pool_recycle=300,        # recycle connections every 5 min
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()