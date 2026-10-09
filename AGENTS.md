# AGENTS.md — cuy-monitor-db

Instrucciones para cualquier agente de IA (Claude Code, Copilot, Cursor, Codex…) que trabaje en este repo. Léelas completas antes de tocar algo.
## Qué es este repo

El **esquema de PostgreSQL** del Monitor de Salud de Cuyes, separado del backend (ADR-008 en `cuy-monitor-backend/docs/ARCHITECTURE.md`):

- `migrations/`: migraciones **Flyway** en SQL (`V{n}__descripcion.sql`). Son la única forma de crear o cambiar tablas.
- `seeds/dev/`: datos de prueba **solo para desarrollo** (nunca se aplican en producción).
- `docker-compose.yml`: Postgres 18 local + Flyway, para que el backend se desarrolle contra una base real.
- `Dockerfile`: imagen `migrate` (`flyway/flyway` + `migrations/`). En producción Compose la corre **una vez** contra Amazon RDS antes de arrancar el backend.

El backend (`cuy-monitor-backend`) **no** crea tablas: tiene Flyway apagado y `ddl-auto: validate`. Si una tabla no coincide con sus entidades JPA, el backend no arranca.

Lee antes de trabajar:
- `docs/PRD.md` — qué hace este repo y qué no.
- `docs/ARCHITECTURE.md` — tablas, columnas, restricciones, cómo se despliega.
- `cuy-monitor-backend/docs/contracts/` — enums compartidos (`MarkColor`, `HealthStatus`, `EventType`, `AlertStatus`, `UserStatus`). **Fuente de verdad.**

## Comandos

```bash
docker compose up -d                       # Postgres 18 en localhost:5432 + aplica migrations/ y seeds/dev/
docker compose run --rm flyway info        # ver qué migraciones están aplicadas
docker compose run --rm flyway migrate     # aplicar migraciones nuevas
docker compose run --rm flyway validate    # verificar checksums
docker compose down                        # apagar (los datos quedan en el volumen)
docker build -t cuy-monitor-db-migrate:local .   # imagen que se usa en producción
```

Conexión local: `jdbc:postgresql://localhost:5432/cuymonitor`, usuario y contraseña `cuymonitor`.

## Reglas de migraciones (no las rompas)

1. **Nunca edites, renombres ni borres una migración que ya está en `main`.** Flyway guarda su checksum; si cambia, falla en todas las bases. Para corregir algo, crea `V{n+1}__...sql`.
2. Nombre: `V{n}__verbo_descripcion_en_ingles.sql` (`V3__create_health_tables.sql`, `V4__add_code_to_cage.sql`). Números consecutivos, sin saltos ni duplicados. Antes de crear una, revisa `main` y las ramas abiertas para no repetir el número.
3. Una migración = un cambio con sentido. Que sea **idempotente con respecto al historial** (corre una sola vez), no con `IF NOT EXISTS` para tapar errores.
4. Migraciones de producción: solo DDL y datos que el sistema necesita para funcionar (por ejemplo la jaula piloto). Datos de prueba → `seeds/dev/`.
5. Cambios que pueden romper el backend (renombrar o borrar columnas, cambiar tipos, `NOT NULL` nuevo sin default) se hacen en dos pasos: primero agregar, el backend se adapta, después quitar.
6. Cada migración nueva va con su actualización del diccionario de datos en `docs/ARCHITECTURE.md`.
7. No uses funciones o extensiones que Amazon RDS no permita. Extensiones aprobadas: ninguna por ahora (si hace falta `pgcrypto` u otra, pregunta).

## Convenciones SQL

- Tablas y columnas en **inglés**, `snake_case`, tablas en singular (`guinea_pig`, `app_user`; `user` es palabra reservada).
- Claves primarias: `id`. `BIGSERIAL` para datos internos, `UUID` cuando el id lo genera la aplicación o un productor (`event.id` = `eventId`, `app_user.id`).
- Fechas siempre `TIMESTAMPTZ` en UTC. Nombres: `created_at`, `updated_at`, `occurred_at`, `measured_at`.
- Enums como `VARCHAR` + `CHECK (col IN (...))`, con los mismos valores que los contratos del backend. No uses `CREATE TYPE ... AS ENUM` (cuesta migrarlos).
- Nombres de restricciones explícitos: `pk_`, `fk_<tabla>_<ref>`, `uq_<tabla>_<cols>`, `ck_<tabla>_<col>`, índices `ix_<tabla>_<cols>`.
- Toda clave foránea lleva índice si se va a consultar por ella.
- JSON crudo de eventos en `JSONB`.

## Contratos con otros repos

- Si cambias una tabla que el backend usa, **avisa al usuario**: hay que cambiar la entidad JPA en `cuy-monitor-backend` en un PR después de este.
- Si cambias los valores permitidos de un enum, primero se cambia `cuy-monitor-backend/docs/contracts/`.
- Los otros repos (ai-service, dashboard, arduino) **nunca** se conectan a la base; solo el backend.

## Seguridad

- Nunca escribas contraseñas reales ni el endpoint de la RDS en el repo. Solo valores de desarrollo (`cuymonitor`) y `.env.example`.
- No hagas commit de `.env`, dumps (`*.sql.gz`, `*.dump`) ni datos reales de usuarios.
- Contraseñas y códigos OTP se guardan **hasheados** por el backend (BCrypt). Las columnas se llaman `*_hash`; nunca agregues una columna con la contraseña en texto plano.
- Los seeds de desarrollo pueden traer un usuario de prueba con un hash BCrypt de una contraseña conocida (`dev-password`), nunca uno real.

## Tests y verificación

Antes de decir que terminaste:
1. `docker compose down -v && docker compose up -d` (base local desde cero) aplica todo sin errores.
2. `docker compose run --rm flyway validate` pasa.
3. Si el cambio afecta al backend: `./mvnw test` en `cuy-monitor-backend` sigue pasando (sus tests de integración leen `../cuy-monitor-db/migrations`).

## Git (lo hacen las personas, no el agente)

- Los commits, push y PRs los hace **una persona del equipo** a mano. El agente solo puede proponer el mensaje.
- Sin `Co-Authored-By` ni firmas de IA en ningún commit o PR.
- Conventional Commits en inglés: `feat(schema): add weight_reading table`, `fix(schema): add missing index on alert status`, `chore(seeds): add dev guinea pigs`, `docs(schema): update data dictionary`.
- Ramas `feature/...`, `fix/...`. `main` solo por Pull Request, revisado por el otro integrante.
- **Prohibido** `git push --force` a `main`.

## Lo que el agente NO debe hacer sin permiso explícito

- Conectarse a la RDS o a cualquier base que no sea la local, ni correr migraciones contra ella.
- Editar una migración que ya está en `main`.
- `DROP TABLE`, `DROP COLUMN`, `TRUNCATE` o `DELETE` masivo en una migración.
- Cambiar la versión de Postgres o de la imagen de Flyway.
- Agregar extensiones de Postgres.

`docker compose down -v` **solo** está permitido sobre la base local de este repo (borra los datos de desarrollo, que se regeneran con los seeds).

## Herramientas que puede usar el agente

- Leer y editar archivos del repo.
- `docker compose` de este repo (base local) y `docker build`.
- `psql` contra `localhost:5432`.
- Solo lectura de git: `git status`, `git diff`, `git log`, `git show`. **Nada de commits, push ni PRs** (ver la regla absoluta del inicio).
