import os as _os
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


@asynccontextmanager
async def lifespan(app: FastAPI):
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
