"""
Daily scheduled jobs for family feature flags:
- create_daily_prayer_tasks(): creates 5 prayer tasks for each member of prayer-enabled families
- create_daily_motivation_messages(): picks a daily motivational quote and notifies members
"""
import random
import logging
from datetime import date, datetime

import requests as _requests

from app.database import SessionLocal
from app.families.models import Family, DailyMessage
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

# Prayer names in French
_PRAYERS = ["Fajr", "Dhouhr", "Asr", "Maghrib", "Isha"]


def _fetch_paris_prayer_times() -> dict[str, str] | None:
    """Fetch today's prayer times for Paris using AlAdhan API (method 12 = UOIF France)."""
    url = "https://api.aladhan.com/v1/timingsByCity"
    params = {"city": "Paris", "country": "France", "method": "12"}
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
        logger.error(f"[daily_jobs] Failed to fetch prayer times: {e}")
        return None


def run_prayer_tasks_for_family(family, db) -> None:
    """Create today's prayer tasks for a single family using an existing DB session."""
    today = date.today()
    timings = _fetch_paris_prayer_times()
    if not timings:
        logger.warning("[daily_jobs] No prayer timings fetched, skipping prayer tasks for family %s", family.id)
        return
    for member in family.members:
        for prayer_name, prayer_time in timings.items():
            title = f"🕌 Prière {prayer_name} — {prayer_time}"
            existing = db.query(Task).filter(
                Task.title == title,
                Task.family_id == family.id,
                Task.assigned_to_id == member.id,
                Task.due_date == today,
            ).first()
            if existing:
                continue
            db.add(Task(
                title=title,
                description=f"Prière {prayer_name} à {prayer_time} (heure de Paris)",
                status=TaskStatus.en_attente,
                priority=TaskPriority.normale,
                visibility=TaskVisibility.prive,
                family_id=family.id,
                created_by_id=family.created_by_id,
                assigned_to_id=member.id,
                due_date=today,
            ))


def run_motivation_message_for_family(family, db) -> None:
    """Create today's motivation message for a single family using an existing DB session."""
    today = date.today()
    existing = db.query(DailyMessage).filter(
        DailyMessage.family_id == family.id,
        DailyMessage.date == today,
    ).first()
    if existing:
        return
    day_of_year = today.timetuple().tm_yday
    quote = _QUOTES[(day_of_year + family.id) % len(_QUOTES)]
    db.add(DailyMessage(family_id=family.id, message=quote, date=today))
    for member in family.members:
        db.add(Notification(
            message=f"💬 Message du jour : {quote}",
            user_id=member.id,
            created_by_id=family.created_by_id,
        ))
        if member.push_token:
            send_push(member.push_token, "💬 Message du jour", quote, url="/home")


def create_daily_prayer_tasks() -> None:
    """For each family with prayer_enabled, create 5 prayer tasks for all members."""
    db = SessionLocal()
    try:
        today = date.today()
        families = db.query(Family).filter(Family.prayer_enabled == True).all()  # noqa: E712
        if not families:
            return

        timings = _fetch_paris_prayer_times()
        if not timings:
            logger.warning("[daily_jobs] No prayer timings fetched, skipping prayer tasks")
            return

        for family in families:
            for member in family.members:
                for prayer_name, prayer_time in timings.items():
                    title = f"🕌 Prière {prayer_name} — {prayer_time}"
                    # Check if already created today for this member/family
                    existing = db.query(Task).filter(
                        Task.title == title,
                        Task.family_id == family.id,
                        Task.assigned_to_id == member.id,
                        Task.due_date == today,
                    ).first()
                    if existing:
                        continue
                    task = Task(
                        title=title,
                        description=f"Prière {prayer_name} à {prayer_time} (heure de Paris)",
                        status=TaskStatus.en_attente,
                        priority=TaskPriority.normale,
                        visibility=TaskVisibility.prive,
                        family_id=family.id,
                        created_by_id=family.created_by_id,
                        assigned_to_id=member.id,
                        due_date=today,
                    )
                    db.add(task)
        db.commit()
        logger.info(f"[daily_jobs] Prayer tasks created for {len(families)} families")
    except Exception as e:
        logger.error(f"[daily_jobs] Error creating prayer tasks: {e}")
        db.rollback()
    finally:
        db.close()


def create_daily_motivation_messages() -> None:
    """For each family with motivation_enabled, pick a daily quote and notify all members."""
    db = SessionLocal()
    try:
        today = date.today()
        families = db.query(Family).filter(Family.motivation_enabled == True).all()  # noqa: E712

        for family in families:
            # Check if message already created today for this family
            existing = db.query(DailyMessage).filter(
                DailyMessage.family_id == family.id,
                DailyMessage.date == today,
            ).first()
            if existing:
                continue

            # Pick a deterministic quote for the day based on day-of-year + family id
            day_of_year = today.timetuple().tm_yday
            quote_index = (day_of_year + family.id) % len(_QUOTES)
            quote = _QUOTES[quote_index]

            # Save daily message
            msg_record = DailyMessage(
                family_id=family.id,
                message=quote,
                date=today,
            )
            db.add(msg_record)

            # Notify all members
            for member in family.members:
                notif = Notification(
                    message=f"💬 Message du jour : {quote}",
                    user_id=member.id,
                    created_by_id=family.created_by_id,
                )
                db.add(notif)
                if member.push_token:
                    send_push(
                        member.push_token,
                        "💬 Message du jour",
                        quote,
                        url="/home",
                    )

        db.commit()
        logger.info(f"[daily_jobs] Motivation messages created for {len(families)} families")
    except Exception as e:
        logger.error(f"[daily_jobs] Error creating motivation messages: {e}")
        db.rollback()
    finally:
        db.close()
