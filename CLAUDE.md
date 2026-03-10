# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A family planning app with a **FastAPI backend + PostgreSQL database deployed on Railway**, and a **Flutter frontend deployed on Vercel** (web + mobile). The React Native frontend in `frontend/` is legacy and kept for reference only — do not modify it.

---

## Backend (FastAPI + PostgreSQL)

### Key Commands
```bash
# Install dependencies
cd backend && poetry install

# Run locally
poetry run uvicorn backend.app.main:app --reload --port 8000

# Run database migrations
poetry run alembic -c backend/alembic.ini upgrade head

# Generate a new migration
poetry run alembic -c backend/alembic.ini revision --autogenerate -m "description"
```

### Structure
```
backend/app/
├── main.py          # FastAPI entry point — CORS, routers, APScheduler daily reminder
├── database.py      # SQLAlchemy engine + SessionLocal (Railway postgres:// → postgresql:// fix)
├── auth/            # JWT login/register — security.py, deps.py (get_current_user)
├── users/           # GET/PUT /users/me, profile image upload, karma stats
├── tasks/           # CRUD, /tasks/today, /tasks/agenda, status changes with karma
├── families/        # Families, members, invitations (send/accept/reject)
├── events/          # Event CRUD + RSVP (pending/going/not_going)
├── shopping/        # ShoppingList + ShoppingItem CRUD with toggle
├── notifications/   # List, mark-read (DELETE), mark-all-read
└── notes/           # FamilyNote CRUD per family
```

### Architecture Notes
- **Auth**: JWT via `python-jose`. All protected routes use `Depends(get_current_user)`.
- **Karma**: +10 when task → `fait` (awarded to assignee if assigned, else creator). -10 if unchecked (floor 0). Logic in `tasks/routes.py`.
- **Push notifications**: Pywebpush (VAPID). `push.py` sends to registered `push_token` on user. Backend reads `VAPID_PRIVATE_KEY`, `VAPID_PUBLIC_KEY` from env.
- **Scheduled tasks**: APScheduler in `main.py` — daily reminder at 8 AM.
- **Deployment**: Railway via `Procfile` (`alembic upgrade head` then `uvicorn`).

### Task Status/Priority/Visibility Enums
- Status: `en_attente`, `fait`, `annule`
- Priority: `normale`, `haute`, `urgente`
- Visibility: `prive`, `famille`

---

## Flutter Frontend

### Key Commands
```bash
# Flutter binary
C:\Users\Amine\flutter_sdk\flutter\bin\flutter.bat

# Run app
flutter.bat run

# Run on specific device
flutter.bat devices
flutter.bat run -d <device-id>

# Build web (for Vercel deploy)
flutter.bat build web --release --no-wasm-dry-run

# Deploy to Vercel
cd frontend_flutter && npx vercel --prod

# Analyze for errors
flutter.bat analyze
```

### Structure
```
frontend_flutter/lib/
├── main.dart                    # Entry point — AuthProvider init, GoRouter, fr_FR locale
├── core/
│   ├── api_client.dart          # Dio singleton — JWT interceptor, TTL cache, ngrok header
│   └── constants.dart           # kApiBaseUrl
├── theme/app_theme.dart         # Design tokens (class C) — primary #e44232, bg #fefdfc
├── navigation/
│   ├── router.dart              # GoRouter — StatefulShellRoute (5 tabs) + outside-shell routes
│   └── app_shell.dart           # BottomNavigationBar shell
├── providers/
│   └── auth_provider.dart       # ChangeNotifier — login/register/logout/refreshUser + push init
├── services/
│   └── push_service.dart        # Push notification service (web ServiceWorker impl)
└── screens/                     # All screens (see below)
```

### Navigation Architecture
- **StatefulShellRoute.indexedStack** — 5 branches preserve state on tab switch (no reload).
- Tabs: `/home`, `/agenda`, `/shopping`, `/families`, `/profile`
- Outside shell (full-screen): `/login`, `/register`, `/families/:id`, `/invitations`, `/notifications`
- Auth redirect in router: unauthenticated → `/login`, authenticated on auth route → `/home`

### API Client Pattern
- Single `ApiClient()` instance using Dio.
- JWT injected automatically by interceptor (no need to pass token in calls).
- GET caching with TTL (invalidated on mutations). Cache TTLs: `today` 30s, `karma` 2min, `families` 5min, `shopping` 2min, `notifications` 15s.
- Always include `ngrok-skip-browser-warning: true` header (set in ApiClient).
- Image uploads: `FormData.fromMap({'file': await MultipartFile.fromFile(path)})`.

### Design System
- All colors/spacing/radii: class `C` in `lib/theme/app_theme.dart`.
- Theme: Material3. Use `buildAppTheme()` to get the theme.
- Never hardcode colors — always reference `C.*` tokens.

### State Management
- `provider` package (`ChangeNotifier`). Only `AuthProvider` is global.
- Screen-local state via `StatefulWidget` + `setState`.
- API calls are made directly from screens using `ApiClient().dio.*`.

### Localization
- French locale (`fr_FR`) throughout.
- `intl` package for date formatting: `DateFormat('dd/MM/yyyy', 'fr_FR')`.
- `initializeDateFormatting('fr_FR', null)` must be called at app start (done in `main.dart`).
- **Required**: `GlobalMaterialLocalizations.delegate` in `localizationsDelegates` — without it, `TextFormField` breaks on fr_FR locale.

### Web Deployment Notes
- Critical CSS in `web/index.html`: `flt-glass-pane { position: fixed !important; width: 100% !important; height: 100% !important; }` — without this, pointer events break.
- Vercel config: `vercel.json` sets SPA rewrites + cache headers.
- Live URL: https://family-planner-sage.vercel.app

---

## Environment Variables (Backend)
| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string (Railway sets this automatically) |
| `SECRET_KEY` | JWT signing key |
| `VAPID_PRIVATE_KEY` | Web push VAPID private key |
| `VAPID_PUBLIC_KEY` | Web push VAPID public key |

## Key Cross-System Relationships
- `kApiBaseUrl` in `frontend_flutter/lib/core/constants.dart` points to the backend (ngrok URL locally, Railway URL in prod).
- Notifications are created server-side (in task/invitation routes) and fetched by the Flutter app polling `/notifications/` every 30s.
- Karma is purely server-side — frontend reads it via `GET /users/me/karma`.
