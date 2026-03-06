"""Daily reminder job — runs every morning at 08:00.
Sends push notifications for:
  • Urgent/high-priority tasks due today
  • Events happening today
"""
from datetime import datetime
from app.database import SessionLocal
from app.users.models import User
from app.tasks.models import Task, TaskStatus, TaskPriority
from app.events.models import Event
from app.notifications.push import send_expo_push


def send_daily_reminders() -> None:
    db = SessionLocal()
    try:
        today = datetime.now().date()
        users = db.query(User).filter(User.push_token.isnot(None)).all()

        for user in users:
            user_family_ids = [f.id for f in user.families]

            # Urgent / haute tasks due today (personal or family)
            urgent_tasks = db.query(Task).filter(
                Task.status == TaskStatus.en_attente,
                Task.due_date == today,
                Task.priority.in_([TaskPriority.urgente, TaskPriority.haute]),
                Task.assigned_to_id == user.id
            ).all()

            # Also personal urgent tasks created by this user
            personal_urgent = db.query(Task).filter(
                Task.status == TaskStatus.en_attente,
                Task.due_date == today,
                Task.priority.in_([TaskPriority.urgente, TaskPriority.haute]),
                Task.created_by_id == user.id,
                Task.assigned_to_id.is_(None),
            ).all()

            all_urgent = {t.id: t for t in urgent_tasks + personal_urgent}.values()

            # Events today in any family this user belongs to
            today_events = db.query(Event).filter(
                Event.date == today,
                Event.family_id.in_(user_family_ids)
            ).all()

            lines = []
            if all_urgent:
                task_titles = ", ".join(t.title for t in list(all_urgent)[:3])
                suffix = f" (+{len(list(all_urgent)) - 3} autres)" if len(list(all_urgent)) > 3 else ""
                lines.append(f"📋 Tâches urgentes : {task_titles}{suffix}")
            if today_events:
                evt_titles = ", ".join(e.title for e in today_events[:2])
                suffix = f" (+{len(today_events) - 2} autres)" if len(today_events) > 2 else ""
                lines.append(f"📅 Événements : {evt_titles}{suffix}")

            if lines:
                body = " | ".join(lines)
                send_expo_push(user.push_token, "Bonjour ! Votre journée 👋", body)

    except Exception:
        pass
    finally:
        db.close()
