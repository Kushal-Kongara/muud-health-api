# MUUD Health — Community Wellness App (Monorepo)

This repo contains a minimal **Community Wellness** app with two core modules:

- **Journal** (write entries with mood 1–5, view history)
- **Contacts** (store & list supportive contacts)

It’s split into:
- **backend/** — Node.js + Express + PostgreSQL (JWT auth + tests)
- **frontend/** — Flutter Web app (login/register, journal, contacts)

---

## Repo Structure

muud-health-api/
backend/
src/ # Express app, routes, middleware
tests/ # Jest + Supertest
.env.example # copy to .env for local dev
README.md # backend details & schema
frontend/
lib/main.dart # Flutter UI (web)
README.md # frontend quick start
.gitignore
README.md # (this file)

## Tech Stack

**Backend**
- Node.js, Express
- PostgreSQL (pg)
- JWT auth (jsonwebtoken) + bcryptjs
- Validation middleware (custom)
- Tests: Jest + Supertest
- Dev: nodemon, dotenv, CORS

**Frontend**
- Flutter (Web target)
- HTTP client (`http`)
- Local storage (`shared_preferences`)
- Material 3, brand color **#9B5DE0**

---

## Prerequisites

- **PostgreSQL 16** running locally
- **Node 18+** (tested with Node 22)
- **Flutter SDK** (for web): `flutter --version`

---

## Setup & Run

### 1 Backend

```bash
cd backend
cp .env.example .env   # then open .env and set your values
npm install
npm run dev            # http://localhost:4000

Health check:

curl http://localhost:4000/health


Database schema & SQL are in backend/README.md.
(Contains journal_entries, contacts, and users tables + indexes.)

Tests

npm test   # all tests should pass

2) Frontend (Flutter Web)
cd frontend
flutter pub get
flutter run -d chrome


The app will open in Chrome:

Register or Login

Add a Journal entry (with mood)

Add a Contact

Lists will populate from the backend

The app calls http://localhost:4000.
If you later run on Android emulator, switch to http://10.0.2.2:4000.

API Quick Reference
Auth

POST /auth/register — { email, password, name? } → { success, token, user }

POST /auth/login — { email, password } → { success, token, user }

GET /me (protected) — Authorization: Bearer <token>

Example

curl -s -X POST http://localhost:4000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@example.com","password":"secret123","name":"Demo"}'

Journal

POST /journal/entry (protected)
Body: { user_id(UUID), entry_text, mood_rating(1-5), timestamp? }
→ { success, id }

GET /journal/user/:id (protected)
→ { success, entries: [...] }

Contacts

POST /contacts/add (protected)
Body: { user_id(UUID), contact_name, contact_email }
→ { success, id }

GET /contacts/user/:id (protected)
→ { success, contacts: [...] }

With auth enabled, the user_id in body and :id in URL must match the JWT’s user.

Environment

Create backend/.env from the example:

PGHOST=localhost
PGPORT=5432
PGDATABASE=muud_health
PGUSER=muud_user
PGPASSWORD=muud_password

PORT=4000
NODE_ENV=development

# Use a long random string locally
JWT_SECRET=your_random_secret


.env is ignored by Git; .env.example is committed for reference.

Troubleshooting

psql/pg not found: ensure PostgreSQL bin is on your PATH (Homebrew installs under /opt/homebrew/opt/postgresql@16/bin on Apple Silicon).

Cannot connect to DB: verify .env values; run psql -d muud_health -U muud_user.

401 Unauthorized: ensure you’re sending Authorization: Bearer <token> and user_id matches the token’s user.

Flutter web can’t reach API: make sure backend is on http://localhost:4000 and CORS is enabled (it is).