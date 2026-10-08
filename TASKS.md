# TASKS — cuy-monitor-db

> Lista de trabajo del repo de base de datos. Cada subtarea = **un commit**: usa el mensaje que está entre comillas invertidas.
> ⛔ Los commits, push y PRs los hace una persona del equipo. **Ningún agente de IA hace commit ni push, aunque se lo pidan**, y nunca se agrega `Co-Authored-By` ni firmas de IA (ver `AGENTS.md`).
> Marca `[x]` cuando hagas push. Una rama por Task: `feature/task-3-health-tables`, etc. Cada PR lo revisa el otro integrante.
> Decisiones: ADR-008 (repo separado) y ADR-009 (Amazon RDS) en `cuy-monitor-backend/docs/ARCHITECTURE.md`.

| Símbolo | Significado |
|---|---|
| 🔴 Prioridad 1 | Crítico: sin esto el backend no arranca en RDS |
| 🟠 Prioridad 2 | Importante: lo que pide la entrega final |
| 🟢 Prioridad 3 | Cierre: respaldo, documentación |
| 🔗 Depende de | Antes hay que terminar esas tasks (de este u otro repo) |
| 🔓 Desbloquea | Qué tasks de otros repos pueden empezar cuando esta termine |

---

## 🔴 Prioridad 1 — Separar la base y pasar a RDS (primera mitad de octubre)

### Task 1 — Proyecto base

- [x] **Task 1.1** — `docs: add PRD, ARCHITECTURE, AGENTS and TASKS`
- [x] **Task 1.2** — `chore: add repo structure, README, gitignore and env example`
  Carpetas `migrations/`, `seeds/dev/`, `scripts/`, `docs/`. `.gitignore` con `.env`, `*.dump`, `*.sql.gz`.
- [x] **Task 1.3** — `chore: add flyway.conf with shared settings`
  `validateOnMigrate=true`, `outOfOrder=false`, `cleanDisabled=true`.
- [x] **Task 1.4** — `chore: add local docker compose with Postgres 18 and Flyway`
  Volumen en `/var/lib/postgresql` (formato de Postgres 18), healthcheck, Flyway con `migrations/` + `seeds/dev/`.

### Task 2 — Traer las migraciones del backend

🔗 **Depende de:** Task 1

- [x] **Task 2.1** — `feat(schema): move V1 initial schema from the backend`
  Copiar `cuy-monitor-backend/src/main/resources/db/migration/V1__initial_schema.sql` **sin cambiar ni un byte** (mismo checksum).
- [x] **Task 2.2** — `feat(schema): move V2 app_user and otp_challenge from the backend`
  Igual que la anterior, con `V2__create_app_user_and_otp_challenge.sql`.
- [ ] **Task 2.3** — *(sin commit)* `docker compose up -d` desde cero y `flyway validate` sin errores

🔓 **Desbloquea:** `cuy-monitor-backend` Task 21 (borrar las migraciones de allá y apagar Flyway)

### Task 3 — Código de jaula y tablas de salud

🔗 **Depende de:** Task 2 · `cuy-monitor-backend` Task 3.2 (enums en los contratos) · revisar columnas con `cuy-monitor-backend` Task 4.5

- [x] **Task 3.1** — `feat(schema): add V3 public code to cage`
  `ALTER TABLE cage ADD COLUMN code VARCHAR(50)`, poner `cage-1` a la jaula piloto, después `NOT NULL` + `uq_cage_code`. Así el `cageId` de los contratos existe en la base.
- [x] **Task 3.2** — `feat(schema): add V4 health tables`
  `guinea_pig`, `event`, `state_transition`, `alert`, `weight_reading`, `baseline_profile` con sus FK, `CHECK` de enums, `uq_guinea_pig_cage_color` e índices de la sección 4 de `docs/ARCHITECTURE.md`.
- [x] **Task 3.3** — `docs(schema): update data dictionary and ER diagram`
- [ ] **Task 3.4** — *(sin commit)* probar a mano en `psql`: `event.id` repetido, color repetido en la jaula y valor de enum inválido tienen que fallar

🔓 **Desbloquea:** `cuy-monitor-backend` Task 4.6–4.8 (entidades JPA y adaptadores de salud)

### Task 4 — Imagen `migrate` para producción

🔗 **Depende de:** Task 2

- [x] **Task 4.1** — `build: add Dockerfile with Flyway and production migrations`
  `FROM flyway/flyway:<tag fijo>`, copia solo `migrations/` (nunca `seeds/`), URL armada con `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` y `sslmode=require`.
- [ ] **Task 4.2** — *(sin commit)* probar la imagen contra la base local con `DB_SSLMODE=disable`

🔓 **Desbloquea:** `cuy-monitor-backend` Task 22.4 (servicio `migrate` en Compose)

### Task 5 — Primera aplicación en RDS

🔗 **Depende de:** Task 4 · `cuy-monitor-backend` Task 22.1 (RDS creada) y 22.4

- [ ] **Task 5.1** — *(sin commit)* crear en la RDS el usuario `cuymonitor` dueño de la base `cuymonitor` (con el usuario maestro, desde la EC2)
- [ ] **Task 5.2** — *(sin commit)* clonar el repo al lado del backend en la EC2 y correr el despliegue; revisar `docker compose logs migrate`
- [ ] **Task 5.3** — `docs: add production migration runbook`
  Pasos de la sección 6 de `docs/ARCHITECTURE.md`, con capturas de la consola de RDS (sin datos sensibles).

---

## 🟠 Prioridad 2 — Entrega final (octubre)

### Task 6 — Datos de desarrollo

🔗 **Depende de:** Task 3

- [x] **Task 6.1** — `chore(seeds): add dev guinea pigs with every mark color`
  `seeds/dev/R__dev_seed.sql`, con `ON CONFLICT DO NOTHING` para que se pueda volver a correr.
- [x] **Task 6.2** — `chore(seeds): add dev test user with a known BCrypt password`
  Usuario `dev` / `dev-password`, estado `ACTIVE`. El hash se genera con el `BCryptPasswordHasher` del backend; nunca un usuario real.
- [ ] **Task 6.3** — `chore(seeds): add sample events, alerts and weight readings`
  Para que el dashboard tenga datos al desarrollar sin el fake producer.

### Task 7 — Ajustes que pida el backend

- [ ] **Task 7.1** — `feat(schema): add V5+ migrations requested by backend tasks`
  Solo si las Task 10–13 del backend necesitan columnas nuevas. Una migración por cambio, con su diccionario actualizado.
- [ ] **Task 7.2** — *(sin commit)* revisar con `EXPLAIN` las consultas de historial, alertas abiertas y peso con los datos de prueba

---

## 🟢 Prioridad 3 — Cierre (noviembre)

### Task 8 — Respaldo y restauración

- [ ] **Task 8.1** — `chore(scripts): add local backup and restore scripts`
  `pg_dump` / `pg_restore` de la base local.
- [ ] **Task 8.2** — `docs: add RDS snapshot and point-in-time restore guide`
- [ ] **Task 8.3** — *(sin commit)* tomar un snapshot manual de la RDS antes de la prueba en la jaula real (27 de octubre)

### Task 9 — Entrega

- [ ] **Task 9.1** — `docs(schema): add final ER diagram for the report`
- [ ] **Task 9.2** — `docs: update README with setup, migrations and RDS notes`
