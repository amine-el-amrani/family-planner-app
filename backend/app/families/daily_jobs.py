"""
Daily scheduled jobs:
- create_daily_prayer_tasks(): creates 5 prayer tasks per user with prayer_enabled=True
- create_daily_motivation_messages(): sends a daily motivational quote per user with motivation_enabled=True
- generate_recurring_tasks(): generates daily task instances from recurring task templates
- send_morning_briefing(): sends a push/in-app notification with today's task count + events
"""
import logging
from datetime import date

import requests as _requests

from app.database import SessionLocal
from app.families.models import DailyMessage
from app.tasks.models import Task, TaskStatus, TaskVisibility, TaskPriority
from app.notifications.models import Notification
from app.notifications.push import send_push

logger = logging.getLogger(__name__)

# 30 curated French motivational quotes
_QUOTES = [
    "Chaque matin est une nouvelle chance de faire mieux. 🌅",
    "La force ne vient pas de ce que tu peux faire, mais de ce que tu pensais ne pas pouvoir faire. 💪",
    "Ensemble, on va plus loin. En famille, on est plus forts. 🏠",
    "Une petite tâche accomplie vaut mieux qu'un grand projet remis à demain. ✅",
    "La patience est l'art d'espérer. Avancez avec confiance. 🌟",
    "Votre effort d'aujourd'hui est la réussite de demain. 🚀",
    "La famille est le premier lieu où l'on apprend à aimer. ❤️",
    "Chaque jour est une page blanche — écrivez quelque chose de beau. 📖",
    "Le succès, c'est avancer un pas à la fois, tous les jours. 👣",
    "Soyez la raison du sourire de quelqu'un aujourd'hui. 😊",
    "Les grandes choses se font par des séries de petites choses réunies. 🎯",
    "La gratitude transforme ce que l'on a en suffisance. Merci pour ce jour ! 🙏",
    "Vos enfants regardent ce que vous faites, pas seulement ce que vous dites. 👀",
    "Un foyer heureux est le plus grand bonheur. Cultivez-le chaque jour. 🌿",
    "L'organisation est la clé d'une vie sereine. Un pas à la fois ! 🗂️",
    "La discipline, c'est choisir entre ce que tu veux maintenant et ce que tu veux vraiment. 🎯",
    "Ensemble on est invincibles. La famille, c'est notre superpouvoir. ⚡",
    "Commencez là où vous êtes. Utilisez ce que vous avez. Faites ce que vous pouvez. 🌈",
    "Les petits gestes quotidiens construisent de grands souvenirs. 💛",
    "La persévérance est ce qui rend l'impossible possible. Continuez ! 🔥",
    "Prendre soin de sa famille, c'est prendre soin de soi. 🤝",
    "Chaque tâche accomplie est une victoire. Célébrez vos succès ! 🏆",
    "La solidarité commence à la maison. Agissez ensemble ! 🤲",
    "Un sourire le matin, et toute la journée est meilleure. ☀️",
    "Investir du temps avec sa famille, c'est le meilleur investissement. 💎",
    "La volonté d'agir, voilà le secret du succès. En avant ! 🏃",
    "Chaque membre de la famille est un trésor. Chérissez-vous mutuellement. 💝",
    "La constance est le chemin vers la grandeur. Soyez constants ! 🌊",
    "Aujourd'hui est le meilleur jour pour commencer. N'attendez pas demain. ⏰",
    "Votre famille mérite le meilleur de vous — pas le reste. Donnez le meilleur ! ✨",
]

# API keys (AlAdhan uses "Dhuhr", not "Dhouhr")
_PRAYERS = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
# French display names for task titles
_PRAYER_DISPLAY = {"Fajr": "Fajr", "Dhuhr": "Dhouhr", "Asr": "Asr", "Maghrib": "Maghrib", "Isha": "Isha"}


def _fetch_prayer_times(city: str = 'Paris', country: str = 'France') -> dict[str, str] | None:
    """Fetch today's prayer times for a city using AlAdhan API (method 12 = UOIF France)."""
    url = "https://api.aladhan.com/v1/timingsByCity"
    params = {"city": city, "country": country, "method": "12"}
    try:
        response = _requests.get(url, params=params, timeout=8.0)
        response.raise_for_status()
        data = response.json()
        timings = data.get("data", {}).get("timings", {})
        result = {}
        for prayer in _PRAYERS:
            t = timings.get(prayer)
            if t:
                result[prayer] = t
        return result if result else None
    except Exception as e:
        logger.error(f"[daily_jobs] Failed to fetch prayer times for {city}: {e}")
        return None


# ── Per-user helpers (called on immediate activation) ─────────────────────────

def run_prayer_tasks_for_user(user, db) -> None:
    """Create today's prayer tasks for a single user using an existing DB session."""
    today = date.today()
    city = getattr(user, 'prayer_city', None) or 'Paris'
    timings = _fetch_prayer_times(city=city)
    if not timings:
        logger.warning("[daily_jobs] No prayer timings fetched for %s, skipping for user %s", city, user.id)
        return
    for prayer_key, prayer_time in timings.items():
        display = _PRAYER_DISPLAY.get(prayer_key, prayer_key)
        title = f"🕌 Prière {display} — {prayer_time}"
        existing = db.query(Task).filter(
            Task.title == title,
            Task.created_by_id == user.id,
            Task.assigned_to_id == user.id,
            Task.due_date == today,
        ).first()
        if existing:
            continue
        db.add(Task(
            title=title,
            description=f"Prière {display} à {prayer_time} (heure de {city})",
            status=TaskStatus.en_attente,
            priority=TaskPriority.normale,
            visibility=TaskVisibility.prive,
            family_id=None,
            created_by_id=user.id,
            assigned_to_id=user.id,
            due_date=today,
            category='Spirituel',
        ))


def run_motivation_message_for_user(user, db) -> None:
    """Create today's motivation message for a single user using an existing DB session."""
    today = date.today()
    existing = db.query(DailyMessage).filter(
        DailyMessage.user_id == user.id,
        DailyMessage.date == today,
    ).first()
    if existing:
        return
    day_of_year = today.timetuple().tm_yday
    quote = _QUOTES[(day_of_year + user.id) % len(_QUOTES)]
    db.add(DailyMessage(user_id=user.id, message=quote, date=today))
    db.add(Notification(
        message=f"💬 Message du jour : {quote}",
        user_id=user.id,
        created_by_id=user.id,
    ))
    if user.push_token:
        send_push(user.push_token, "💬 Message du jour", quote, url="/home")


# ── Cron jobs ─────────────────────────────────────────────────────────────────

def generate_recurring_tasks() -> None:
    """Generate task instances for the next 7 days for all active recurring tasks."""
    from datetime import timedelta
    from app.tasks.models import RecurringTask
    from app.recurring_tasks.routes import _should_run_today, _create_task_instance

    db = SessionLocal()
    try:
        today = date.today()
        rts = db.query(RecurringTask).filter(RecurringTask.is_active == True).all()  # noqa: E712
        for rt in rts:
            for offset in range(7):
                target = today + timedelta(days=offset)
                if _should_run_today(rt, target):
                    _create_task_instance(rt, target, db)
        db.commit()
        logger.info(f"[daily_jobs] Recurring tasks generated (7-day window) from {today}")
    except Exception as e:
        logger.error(f"[daily_jobs] Error generating recurring tasks: {e}")
        db.rollback()
    finally:
        db.close()


def create_daily_prayer_tasks() -> None:
    """For each user with prayer_enabled, create 5 prayer tasks for today."""
    from app.users.models import User
    db = SessionLocal()
    try:
        users = db.query(User).filter(User.prayer_enabled == True).all()  # noqa: E712
        if not users:
            return
        for user in users:
            run_prayer_tasks_for_user(user, db)
        db.commit()
        logger.info(f"[daily_jobs] Prayer tasks created for {len(users)} users")
    except Exception as e:
        logger.error(f"[daily_jobs] Error creating prayer tasks: {e}")
        db.rollback()
    finally:
        db.close()


def create_daily_motivation_messages() -> None:
    """For each user with motivation_enabled, send a daily motivational quote."""
    from app.users.models import User
    db = SessionLocal()
    try:
        users = db.query(User).filter(User.motivation_enabled == True).all()  # noqa: E712
        for user in users:
            run_motivation_message_for_user(user, db)
        db.commit()
        logger.info(f"[daily_jobs] Motivation messages created for {len(users)} users")
    except Exception as e:
        logger.error(f"[daily_jobs] Error creating motivation messages: {e}")
        db.rollback()
    finally:
        db.close()


def send_morning_briefing() -> None:
    """
    Send a morning briefing notification to every user who has a push token.
    Includes: number of pending tasks today (excluding prayer tasks) + today's events.
    """
    from app.users.models import User
    from app.events.models import Event

    db = SessionLocal()
    try:
        today = date.today()
        users = db.query(User).filter(User.push_token != None).all()  # noqa: E711

        _OPENERS = [
            "Bonne journée ! 🌅",
            "Prêt(e) pour cette belle journée ? ☀️",
            "C'est parti ! 💪",
            "Une nouvelle journée, de nouvelles victoires ! 🏆",
            "En avant pour aujourd'hui ! 🚀",
        ]

        _FREE_DAY = [
            "Rien au programme aujourd'hui — vous êtes en vacances ! 🏖️",
            "Journée libre ! Profitez-en bien 😎",
            "Agenda vide aujourd'hui. Reposez-vous, vous le méritez ! 🌴",
            "Pas de tâches, pas d'événements. C'est votre jour de détente ! ☕",
            "Le planning est vide aujourd'hui — savourez chaque moment ! 🎉",
            "Journée zen au programme. Rien à faire, tout à vivre ! 🧘",
            "Aujourd'hui c'est repos — recharge les batteries ! 🔋",
        ]

        for user in users:
            if not user.push_token:
                continue

            # Count pending tasks today, excluding prayer tasks
            task_count = db.query(Task).filter(
                Task.assigned_to_id == user.id,
                Task.due_date == today,
                Task.status == TaskStatus.en_attente,
                ~Task.title.like("🕌 Prière%"),
            ).count()
            # Also count tasks created by the user that are not assigned to anyone else
            personal_count = db.query(Task).filter(
                Task.created_by_id == user.id,
                Task.assigned_to_id == None,  # noqa: E711
                Task.due_date == today,
                Task.status == TaskStatus.en_attente,
                ~Task.title.like("🕌 Prière%"),
            ).count()
            total_tasks = task_count + personal_count

            # Collect today's events in user's families
            today_events = []
            for family in user.families:
                for event in family.events:
                    if event.date == today:
                        today_events.append(event.title)

            day_seed = today.timetuple().tm_yday + user.id

            # Build message
            if total_tasks == 0 and not today_events:
                # Free day — always send an encouraging "nothing today" message
                body = _FREE_DAY[day_seed % len(_FREE_DAY)]
                title = "🗓️ Votre journée commence !"
                db.add(Notification(message=body, user_id=user.id, created_by_id=user.id))
                send_push(user.push_token, title, body, url="/home")
                continue

            opener = _OPENERS[day_seed % len(_OPENERS)]
            lines = [opener]
            if total_tasks > 0:
                if total_tasks == 1:
                    lines.append("Vous avez 1 tâche à accomplir aujourd'hui.")
                else:
                    lines.append(f"Vous avez {total_tasks} tâches à accomplir aujourd'hui.")
            if today_events:
                if len(today_events) == 1:
                    lines.append(f"Événement du jour : {today_events[0]} 📅")
                else:
                    lines.append(f"{len(today_events)} événements aujourd'hui : {', '.join(today_events[:2])}{'...' if len(today_events) > 2 else ''} 📅")

            body = " ".join(lines)
            title = "🗓️ Votre journée commence !"

            # In-app notification
            db.add(Notification(
                message=body,
                user_id=user.id,
                created_by_id=user.id,
            ))

            # Push notification
            if user.push_token:
                send_push(user.push_token, title, body, url="/home")

        db.commit()
        logger.info(f"[daily_jobs] Morning briefing sent to {len(users)} users")
    except Exception as e:
        logger.error(f"[daily_jobs] Error sending morning briefing: {e}")
        db.rollback()
    finally:
        db.close()
