# Architecture — cuy-monitor-db

> PostgreSQL 18 · Flyway 11 (Docker image `flyway/flyway`) · Amazon RDS for PostgreSQL in production · Docker Compose locally
> Last reviewed: 2026-10-03 · Decisions: ADR-008 (own repo) and ADR-009 (RDS) in `cuy-monitor-backend/docs/ARCHITECTURE.md`

This repo owns the database schema. The backend never creates or alters tables: it runs with Flyway disabled and `ddl-auto: validate`.

---

## 1. Context

```
                       LOCAL (developer PC)                                   AWS (one region, one VPC)
┌──────────────────────────────────────────────────┐      ┌──────────────────────────────────────────────────────┐
│ cuy-monitor-db/docker-compose.yml                │      │ EC2 — cuy-monitor-backend/infra/docker-compose.yml   │
│  ├─ postgres:18   localhost:5432                 │      │  ├─ migrate (image built from cuy-monitor-db)        │
│  └─ flyway        migrations/ + seeds/dev/       │      │  │    flyway migrate → exits 0                       │
│                                                  │      │  └─ backend  (starts only after migrate succeeded)   │
│ backend from the IDE (profile dev) ──► :5432     │      │          │ JDBC + TLS             │                  │
│ backend tests (Testcontainers) read              │      │          ▼                         ▼                 │
│   ../cuy-monitor-db/migrations                   │      │   RDS PostgreSQL 18 (private, sg-rds ← sg-ec2 only)  │
└──────────────────────────────────────────────────┘      └──────────────────────────────────────────────────────┘
```

Only the backend (and the `migrate` job) connect to the database. The ai-service, dashboard and Arduino bridge never do.

---

## 2. Repository layout

```
cuy-monitor-db/
├── migrations/                         production migrations (applied everywhere)
│   ├── V1__initial_schema.sql          cage + pilot cage            (moved from the backend, unchanged)
│   ├── V2__create_app_user_and_otp_challenge.sql                    (moved from the backend, unchanged)
│   ├── V3__add_code_to_cage.sql        public cage code 'cage-1'
│   └── V4__create_health_tables.sql    guinea_pig, event, state_transition, alert, weight_reading, baseline_profile
├── seeds/dev/
│   └── R__dev_seed.sql                 repeatable, dev only: guinea pigs, test user, sample readings
├── docker-compose.yml                  postgres:18 + flyway (local)
├── Dockerfile                          FROM flyway/flyway + COPY migrations/  → "migrate" image
├── flyway.conf                         shared settings (locations, validateOnMigrate, …)
├── .env.example                        DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
├── scripts/
│   ├── backup-local.sh                 pg_dump of the local database
│   └── restore-local.sh
└── docs/
    ├── PRD.md
    ├── ARCHITECTURE.md                 this file (data dictionary in section 4)
    └── erd.md                          Mermaid ER diagram
```

`V1` and `V2` keep **exactly** the same file name and content they had in the backend, so their Flyway checksums don't change.

---

## 3. How migrations run

| Environment | Who runs Flyway | Locations | Notes |
|---|---|---|---|
| Local | `flyway` service in this repo's `docker-compose.yml` | `migrations/` + `seeds/dev/` | Runs on `docker compose up`; re-run with `docker compose run --rm flyway migrate` |
| Backend tests | Spring's Flyway inside Testcontainers (test profile only) | `filesystem:../cuy-monitor-db/migrations` | Seeds are **not** applied in tests |
| Production (RDS) | `migrate` service in `cuy-monitor-backend/infra/docker-compose.yml`, built from this repo's `Dockerfile` | `migrations/` only | One-shot; the backend has `depends_on: migrate: condition: service_completed_successfully` |

Flyway settings used everywhere: `validateOnMigrate=true`, `outOfOrder=false`, `cleanDisabled=true` (nobody can wipe a database by accident), `baselineOnMigrate=false`.

### 3.1 `Dockerfile` (migrate image)

```dockerfile
FROM flyway/flyway:11-alpine
COPY flyway.conf /flyway/conf/flyway.conf
COPY migrations /flyway/sql
# DB_* come from Compose; sslmode=require for RDS
ENTRYPOINT ["sh", "-c", "flyway -url=jdbc:postgresql://${DB_HOST}:${DB_PORT:-5432}/${DB_NAME}?sslmode=${DB_SSLMODE:-require} -user=${DB_USER} -password=${DB_PASSWORD} migrate"]
```

Pin the exact Flyway tag when the file is written (ADR-006: never `:latest`).

### 3.2 Local `docker-compose.yml`

```yaml
name: cuy-monitor-db
services:
  postgres:
    image: postgres:18
    environment: { POSTGRES_DB: cuymonitor, POSTGRES_USER: cuymonitor, POSTGRES_PASSWORD: cuymonitor }
    ports: ["5432:5432"]
    volumes: [pgdata-dev:/var/lib/postgresql]     # Postgres 18 layout: NOT .../data
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U cuymonitor -d cuymonitor"], interval: 5s, retries: 10 }
  flyway:
    image: flyway/flyway:11-alpine
    depends_on: { postgres: { condition: service_healthy } }
    volumes: ["./migrations:/flyway/sql/migrations:ro", "./seeds/dev:/flyway/sql/seeds:ro", "./flyway.conf:/flyway/conf/flyway.conf:ro"]
    command: -url=jdbc:postgresql://postgres:5432/cuymonitor -user=cuymonitor -password=cuymonitor -locations=filesystem:/flyway/sql/migrations,filesystem:/flyway/sql/seeds migrate
volumes:
  pgdata-dev:
```

---

## 4. Data dictionary

Enum values must match `cuy-monitor-backend/docs/contracts/`. All timestamps are `TIMESTAMPTZ` in UTC.

### `cage` — V1, V3

| Column | Type | Notes |
|---|---|---|
| `id` | `BIGSERIAL` PK | Internal id |
| `code` | `VARCHAR(50)` NOT NULL, UNIQUE | **V3.** Public id used as `cageId` in events and URLs (`cage-1`). Pilot cage gets `cage-1` |
| `name` | `VARCHAR(100)` NOT NULL | "Jaula piloto" |
| `location` | `VARCHAR(200)` | |
| `created_at` | `TIMESTAMPTZ` NOT NULL default `now()` | |

> Why V3: the contracts use `cageId: "cage-1"` but V1 created a numeric id. V1 can't be edited, so V3 adds `code`, fills the pilot cage and makes it `NOT NULL UNIQUE`.

### `app_user` — V2

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | Generated by the backend |
| `username` | `VARCHAR(50)` NOT NULL, `uq_app_user_username` | |
| `full_name` | `VARCHAR(150)` NOT NULL | |
| `email` | `VARCHAR(254)` NOT NULL, `uq_app_user_email` | |
| `password_hash` | `VARCHAR(100)` NOT NULL | BCrypt, never plain text |
| `status` | `VARCHAR(30)` NOT NULL, `ck_app_user_status` | `PENDING_VERIFICATION`, `ACTIVE`, `DISABLED` |
| `created_at`, `updated_at` | `TIMESTAMPTZ` NOT NULL | |

One kind of user only: there is no `role` column on purpose.

### `otp_challenge` — V2

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | The `challengeId` returned to the dashboard |
| `user_id` | `UUID` NOT NULL → `app_user(id)` | `fk_otp_challenge_user` |
| `code_hash` | `VARCHAR(100)` NOT NULL | BCrypt of the 6-digit code |
| `created_at`, `expires_at` | `TIMESTAMPTZ` NOT NULL | 5 min lifetime |
| `max_attempts` | `INT` NOT NULL, `> 0` | 5 |
| `attempts` | `INT` NOT NULL default 0, `>= 0` | |
| `used_at`, `revoked_at` | `TIMESTAMPTZ` NULL | Used once / revoked when a new code is requested |

Index `ix_otp_challenge_user_pending (user_id) WHERE used_at IS NULL AND revoked_at IS NULL`.

### `guinea_pig` — V4

| Column | Type | Notes |
|---|---|---|
| `id` | `BIGSERIAL` PK | |
| `cage_id` | `BIGINT` NOT NULL → `cage(id)` | |
| `name` | `VARCHAR(100)` NOT NULL | |
| `mark_color` | `VARCHAR(20)` NOT NULL, CHECK | `RED, BLUE, GREEN, YELLOW, ORANGE, PURPLE, BLACK, WHITE` |
| `current_status` | `VARCHAR(20)` NOT NULL default `NORMAL`, CHECK | `NORMAL, OBSERVED, ALERT, CRITICAL` |
| `active` | `BOOLEAN` NOT NULL default `true` | Soft delete |
| `created_at` | `TIMESTAMPTZ` NOT NULL default `now()` | |

`uq_guinea_pig_cage_color (cage_id, mark_color)`: one color per guinea pig per cage. (If inactive guinea pigs must free their color, change it to a partial unique index `WHERE active` in a later migration.)

### `event` — V4

| Column | Type | Notes |
|---|---|---|
| `id` | `UUID` PK | The producer's `eventId` → duplicates rejected |
| `type` | `VARCHAR(20)` NOT NULL, CHECK | `BEHAVIOR, AUDIO, WEIGHT` |
| `cage_id` | `BIGINT` NOT NULL → `cage(id)` | |
| `guinea_pig_id` | `BIGINT` NULL → `guinea_pig(id)` | `NULL` for `AUDIO` and `WEIGHT` |
| `source` | `VARCHAR(30)` NOT NULL | `ai-service`, `arduino` |
| `occurred_at` | `TIMESTAMPTZ` NOT NULL | Envelope `timestamp` |
| `received_at` | `TIMESTAMPTZ` NOT NULL default `now()` | |
| `payload` | `JSONB` NOT NULL | Raw payload |

Index `ix_event_guinea_pig_occurred (guinea_pig_id, occurred_at DESC)` for history and the sustained-anomaly check.

### `state_transition` — V4

| Column | Type | Notes |
|---|---|---|
| `id` | `BIGSERIAL` PK | |
| `guinea_pig_id` | `BIGINT` NOT NULL → `guinea_pig(id)` | |
| `from_status`, `to_status` | `VARCHAR(20)` NOT NULL, CHECK | `HealthStatus` values |
| `reason` | `VARCHAR(300)` | |
| `occurred_at` | `TIMESTAMPTZ` NOT NULL | |

Index `ix_state_transition_guinea_pig_occurred (guinea_pig_id, occurred_at DESC)`.

### `alert` — V4

| Column | Type | Notes |
|---|---|---|
| `id` | `BIGSERIAL` PK | |
| `cage_id` | `BIGINT` NOT NULL → `cage(id)` | |
| `guinea_pig_id` | `BIGINT` NULL → `guinea_pig(id)` | `NULL` for cage-level alerts (audio, weight) |
| `level` | `VARCHAR(20)` NOT NULL, CHECK | `ALERT, CRITICAL` (and `OBSERVED` if the team decides to store it) |
| `type` | `VARCHAR(20)` NOT NULL, CHECK | `BEHAVIOR, AUDIO, WEIGHT` |
| `message` | `VARCHAR(500)` NOT NULL | |
| `status` | `VARCHAR(20)` NOT NULL default `OPEN`, CHECK | `OPEN, REVIEWED` |
| `created_at` | `TIMESTAMPTZ` NOT NULL default `now()` | |
| `reviewed_at` | `TIMESTAMPTZ` NULL | |

Index `ix_alert_status_created (status, created_at DESC)` for `GET /api/alerts?status=OPEN`.

### `weight_reading` — V4

| Column | Type | Notes |
|---|---|---|
| `id` | `BIGSERIAL` PK | |
| `cage_id` | `BIGINT` NOT NULL → `cage(id)` | |
| `grams` | `NUMERIC(7,1)` NOT NULL | |
| `stable` | `BOOLEAN` NOT NULL | |
| `measured_at` | `TIMESTAMPTZ` NOT NULL | |

Index `ix_weight_reading_cage_measured (cage_id, measured_at DESC)`.

### `baseline_profile` — V4

| Column | Type | Notes |
|---|---|---|
| `guinea_pig_id` | `BIGINT` PK → `guinea_pig(id)` | One profile per guinea pig |
| `avg_still_seconds` | `NUMERIC(6,2)` NOT NULL | |
| `avg_feeder_visits` | `NUMERIC(6,2)` NOT NULL | |
| `avg_group_distance` | `NUMERIC(5,4)` NOT NULL | 0–1 |
| `updated_at` | `TIMESTAMPTZ` NOT NULL | |

The exact columns of V4 are confirmed together with the backend's JPA entities (backend Task 4.5–4.6) before the migration is merged; once merged, changes go in V5+.

---

## 5. ER diagram (summary)

```
cage 1 ──< guinea_pig 1 ──< state_transition
  │             │ 1
  │             ├──< event (guinea_pig_id NULL for cage-level)
  │             ├──< alert (guinea_pig_id NULL for cage-level)
  │             └──1 baseline_profile
  ├──< event
  ├──< alert
  └──< weight_reading

app_user 1 ──< otp_challenge          (not linked to cage: every user sees the pilot cage)
```

---

## 6. Production (Amazon RDS)

| Setting | Value |
|---|---|
| Engine | PostgreSQL 18 (17 if 18 isn't available in the region) |
| Class | `db.t4g.micro`, single-AZ |
| Storage | 20 GB gp3, autoscaling off |
| Network | Same VPC and region as the EC2, private subnets, **Public access: No** |
| Security group | `sg-rds`: inbound 5432 only from `sg-ec2` |
| TLS | Required (`sslmode=require` in JDBC and in the migrate image) |
| Backups | Automated, 7 days retention, point-in-time restore; manual snapshot before risky migrations |
| Credentials | Master user only for creating the app user; the backend and migrate use `cuymonitor` (owner of the schema). Stored only in `infra/.env` on the EC2 |
| Cost control | Can be stopped when not in use (AWS starts it again after 7 days) |

### Running a migration in production

0. For risky changes (new `NOT NULL`, type changes, big data updates): take a manual RDS snapshot first.
1. Merge the migration to `main` of this repo (and the matching backend change, if any).
2. On the EC2: `git -C ~/cuy/cuy-monitor-db pull`.
3. From `cuy-monitor-backend/infra`: `docker compose up -d --build migrate backend`.
4. Check `docker compose logs migrate` and `/actuator/health`.
5. If `migrate` fails, the new backend doesn't start (`service_completed_successfully`). Fix it with a new migration (V{n+1}); restore the snapshot only if data was damaged.

---

## 7. Testing

| Check | How |
|---|---|
| Migrations apply from scratch | `docker compose down -v && docker compose up -d` |
| Checksums unchanged | `docker compose run --rm flyway validate` |
| Schema matches the backend | Backend `./mvnw test` (Testcontainers + `ddl-auto: validate`) |
| Constraints | Manual SQL in `psql`: duplicate `event.id`, repeated color in a cage, invalid enum value → must fail |

---

## 8. Decisions

| Decision | Why |
|---|---|
| Own repo for the schema (ADR-008) | The database is a deliverable of its own; history and docs separated from the Java code |
| Flyway in plain SQL | The team already used it in the backend; SQL is easy to review and to explain |
| One-shot `migrate` container instead of Flyway inside the backend | The backend doesn't need DDL permissions at startup; migrations run once per deploy, in a visible step |
| RDS instead of Supabase or a Postgres container (ADR-009) | Private network in the same VPC, automated backups, paid with credits |
| `VARCHAR + CHECK` instead of Postgres `ENUM` types | Easier to change with a migration; same values as the contracts |
| Repeatable `R__dev_seed.sql` in a separate location | Dev data never reaches production because that location isn't in the migrate image |
