import os as _os
import time
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.database import Base
from app.users.models import User
from app.families.models import Family, user_family_table, FamilyInvitation
from app.events.models import Event
from app.tasks.models import Task
from app.notifications.models import Notification
from app.shopping.models import ShoppingList, ShoppingItem
from app.notes.models import FamilyNote
from app.auth.models import VerificationCode  # noqa
from app.auth.routes import router as auth_router
from app.users.routes import router as users_router
from app.families.routes import router as families_router
from app.events.routes import router as events_router
from app.tasks.routes import router as tasks_router
from app.notifications.routes import router as notifications_router
from app.shopping.routes import router as shopping_router
from app.notes.routes import router as notes_router
from app.reminders import send_daily_reminders

scheduler = AsyncIOScheduler()
logger = logging.getLogger(__name__)


def _wait_for_db(max_retries: int = 10, delay: float = 3.0) -> None:
    """Wait until the database is ready (handles Railway cold-start race)."""
    from app.database import engine
    from sqlalchemy import text
    for attempt in range(1, max_retries + 1):
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            logger.info("Database is ready.")
            return
        except Exception as e:
            logger.warning(f"DB not ready (attempt {attempt}/{max_retries}): {e}")
            if attempt < max_retries:
                time.sleep(delay)
    logger.error("Could not connect to the database after retries. Starting anyway.")


@asynccontextmanager
async def lifespan(app: FastAPI):
    _wait_for_db()

    # ── Alembic migration version ─────────────────────────────────────────────
    try:
        from alembic.runtime.migration import MigrationContext
        from app.database import engine
        with engine.connect() as _conn:
            _mig_ctx = MigrationContext.configure(_conn)
            _current_rev = _mig_ctx.get_current_revision()
        print(f"[ALEMBIC] Current migration revision: {_current_rev}", flush=True)
    except Exception as _e:
        print(f"[ALEMBIC] Could not read revision: {_e}", flush=True)

    # ── VAPID env var diagnostic ──────────────────────────────────────────
    _vapid_key = _os.environ.get("VAPID_PRIVATE_KEY", "")
    _vapid_pub = _os.environ.get("VAPID_PUBLIC_KEY", "")
    print(
        f"[ENV] VAPID: "
        f"PRIVATE_KEY={'SET(' + str(len(_vapid_key)) + ' chars)' if _vapid_key else 'MISSING'}, "
        f"PUBLIC_KEY={'SET(' + str(len(_vapid_pub)) + ' chars)' if _vapid_pub else 'MISSING'}",
        flush=True,
    )

    # ── Brevo SMTP env var diagnostic ──────────────────────────────────
    _brevo_user = _os.environ.get("BREVO_SMTP_USER", "")
    _brevo_key = _os.environ.get("BREVO_SMTP_KEY", "")
    print(
        f"[ENV] BREVO: "
        f"SMTP_USER={'SET(' + _brevo_user[:6] + '...)' if _brevo_user else 'MISSING'}, "
        f"SMTP_KEY={'SET(' + str(len(_brevo_key)) + ' chars)' if _brevo_key else 'MISSING'}",
        flush=True,
    )

    # Daily reminder at 08:00 every day
    scheduler.add_job(send_daily_reminders, "cron", hour=8, minute=0, id="daily_reminders")
    scheduler.start()
    yield
    scheduler.shutdown()


app = FastAPI(title="Family Planner API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Works both locally (run from project root) and on Railway
_static_dir = _os.path.join(_os.path.dirname(__file__), "static")
_os.makedirs(_static_dir, exist_ok=True)
app.mount("/static", StaticFiles(directory=_static_dir), name="static")

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(families_router)
app.include_router(events_router)
app.include_router(tasks_router)
app.include_router(notifications_router)
app.include_router(shopping_router)
app.include_router(notes_router)


@app.get("/")
def health_check():
    return {"status": "ok"}
