from fastapi import FastAPI, Security
from fastapi.security import HTTPBearer
from fastapi.staticfiles import StaticFiles
from backend.app.database import engine, Base
from backend.app.users.models import User
from backend.app.families.models import Family, user_family_table, FamilyInvitation
from backend.app.events.models import Event
from backend.app.tasks.models import Task
from backend.app.notifications.models import Notification
from backend.app.auth.routes import router as auth_router
from backend.app.users.routes import router as users_router
from backend.app.families.routes import router as families_router
from backend.app.events.routes import router as events_router
from backend.app.tasks.routes import router as tasks_router
from backend.app.notifications.routes import router as notifications_router


app = FastAPI(title="Family Planner API")

app.mount("/static", StaticFiles(directory="backend/app/static"), name="static")

bearer_scheme = HTTPBearer()

Base.metadata.create_all(bind=engine)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(families_router)
app.include_router(events_router)
app.include_router(tasks_router)
app.include_router(notifications_router)


@app.get("/")
def health_check():
    return {"status": "ok"}
