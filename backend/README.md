# MUUD Health — Community Wellness App (Backend)

Simplified MVP backend for **Journaling** and **Contact Management** with optional **JWT auth**.

## Tech Stack
- **Node.js + Express**
- **PostgreSQL** (pg)
- **Auth (bonus):** JSON Web Tokens (jsonwebtoken) + bcryptjs
- **Validation:** lightweight custom middleware
- **Tests (bonus):** Jest + Supertest
- **Dev:** nodemon, dotenv, CORS

---

## Quick Start

### 1) Prereqs
- PostgreSQL 16 running locally
- Node 18+ (tested with Node 22)

### 2) Create DB + tables
Use psql (already done if you followed the guide):

```sql
-- Create role + database
CREATE ROLE muud_user WITH LOGIN PASSWORD 'muud_password';
CREATE DATABASE muud_health OWNER muud_user;

-- Connect as the app user
-- psql -d muud_health -U muud_user

-- Tables
CREATE TABLE IF NOT EXISTS journal_entries (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID        NOT NULL,
  entry_text    TEXT        NOT NULL,
  mood_rating   INT         NOT NULL CHECK (mood_rating BETWEEN 1 AND 5),
  timestamp     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contacts (
  id             BIGSERIAL PRIMARY KEY,
  user_id        UUID        NOT NULL,
  contact_name   TEXT        NOT NULL,
  contact_email  TEXT        NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_journal_user ON journal_entries (user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_user ON contacts (user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);