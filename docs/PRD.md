# PRD — Base de datos (cuy-monitor-db)

> PRD del componente. El PRD general del producto está en `cuy-monitor-backend/docs/PRD.md`.
> Última revisión: 3 de octubre de 2026

## 1. Qué es

El repo que define **cómo es la base de datos** del Monitor de Salud de Cuyes: todas las tablas, columnas, restricciones e índices, escritas como migraciones Flyway en SQL. Antes vivía dentro del backend (`src/main/resources/db/migration`); se separó para que la base sea un entregable propio, con su historial, su documentación y su forma de levantarse en local (ADR-008).

También trae lo necesario para:
- **Desarrollar en local:** un Postgres 18 en Docker con las migraciones y datos de prueba ya aplicados.
- **Desplegar en AWS:** una imagen Docker (`migrate`) que aplica las migraciones en **Amazon RDS for PostgreSQL** antes de que arranque el backend.

## 2. Usuarios

No tiene usuario final. Sus "clientes" son:
- El **backend** (`cuy-monitor-backend`): es el único que se conecta a la base. Valida al arrancar que el esquema coincida con sus entidades JPA.
- El **equipo técnico**: crea migraciones, levanta la base local, revisa qué se aplicó en producción.

## 3. Qué guarda

| Área | Tablas | Para qué |
|---|---|---|
| Jaula y cuyes | `cage`, `guinea_pig` | Jaula piloto y cuyes registrados con su marca de color |
| Salud | `event`, `state_transition`, `alert`, `baseline_profile` | Eventos recibidos, cambios de estado, alertas, perfil normal de cada cuy |
| Peso | `weight_reading` | Lecturas estables del Arduino |
| Usuarios | `app_user`, `otp_challenge` | Cuentas de quienes miran el dashboard (un solo tipo de usuario) y códigos OTP de login |
| Flyway | `flyway_schema_history` | Qué migraciones se aplicaron (la crea Flyway) |

## 4. Requisitos funcionales

| ID | Requisito | Entrega |
|---|---|---|
| DB-01 | Migraciones Flyway versionadas en `migrations/`, aplicables desde cero sobre una base vacía | Octubre |
| DB-02 | Traer tal cual las migraciones `V1` (jaula) y `V2` (usuarios y OTP) que ya existían en el backend, sin cambiar su contenido | Octubre |
| DB-03 | Tablas de salud y peso (`guinea_pig`, `event`, `state_transition`, `alert`, `weight_reading`, `baseline_profile`) | Octubre |
| DB-04 | La jaula se identifica hacia afuera por un código (`cage-1`), igual que el `cageId` de los contratos | Octubre |
| DB-05 | `docker compose up` levanta Postgres 18 local con migraciones y datos de prueba | Octubre |
| DB-06 | Imagen `migrate` que aplica las migraciones en la base que indiquen las variables `DB_*` y termina | Octubre |
| DB-07 | Datos de prueba solo en desarrollo: jaula, cuyes de varios colores, un usuario de prueba, algunas lecturas | Octubre |
| DB-08 | Diccionario de datos actualizado con cada migración | Siempre |
| DB-09 | Guía para respaldar y restaurar (snapshots de RDS y `pg_dump` local) | Noviembre |

## 5. Requisitos no funcionales

| Qué | Meta |
|---|---|
| Motor | PostgreSQL 18 (17 si RDS no ofrece 18 en la región); local y RDS en la misma versión mayor |
| Producción | Amazon RDS `db.t4g.micro`, sin acceso público, solo accesible desde la EC2, TLS obligatorio |
| Respaldos | Automáticos de RDS, 7 días, con restauración a un momento exacto |
| Seguridad | Ninguna contraseña real en el repo; contraseñas y OTP solo como hash BCrypt |
| Integridad | Claves foráneas, `CHECK` para los enums, `UNIQUE (cage_id, mark_color)`, `event.id` único para descartar duplicados |
| Rendimiento | Índices para las consultas del dashboard (historial por cuy y fecha, alertas abiertas, peso por fecha) |
| Reproducibilidad | Una base vacía + `flyway migrate` = el mismo esquema que en producción |

## 6. Fuera de alcance

- Lógica de negocio en la base (triggers que cambian estados, procedimientos almacenados): eso es del backend.
- Que otros servicios (ai-service, dashboard, arduino) se conecten directamente.
- Varias bases o réplicas de lectura.
- Migrar los datos del Postgres que corría en la EC2: eran solo datos de prueba; RDS empieza desde cero.

## 7. Dependencias

| De | Qué necesita |
|---|---|
| `cuy-monitor-backend/docs/contracts/` | Valores de los enums (`MarkColor`, `HealthStatus`, `EventType`, `AlertStatus`, `UserStatus`) |
| `cuy-monitor-backend` (entidades JPA) | Que cada tabla coincida con su entidad (el backend valida al arrancar) |
| `cuy-monitor-backend/infra/docker-compose.yml` | Construye la imagen `migrate` desde `../../cuy-monitor-db` y la corre antes del backend |
| AWS | Instancia RDS creada, security group que solo deja entrar a la EC2 |

## 8. Criterio de listo

- `docker compose down -v && docker compose up -d` deja una base local completa sin errores.
- En la EC2, `docker compose logs migrate` muestra las migraciones aplicadas en RDS y el backend arranca con `ddl-auto: validate`.
- El diccionario de datos coincide con las migraciones.

## 9. Documentos relacionados

- Esquema y despliegue: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Tareas: [`../TASKS.md`](../TASKS.md)
- Reglas para agentes: [`../AGENTS.md`](../AGENTS.md)
- Decisiones ADR-008 (repo separado) y ADR-009 (RDS): `cuy-monitor-backend/docs/ARCHITECTURE.md`
