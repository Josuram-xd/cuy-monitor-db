# cuy-monitor-db

Esquema de PostgreSQL del Monitor de Salud de Cuyes. Las migraciones **Flyway** son la única forma de crear o cambiar tablas; el backend (`cuy-monitor-backend`) no crea nada, solo valida.

## Estructura

| Ruta | Contenido |
|---|---|
| `migrations/` | Migraciones `V{n}__descripcion.sql` (se aplican en todos los entornos) |
| `seeds/dev/` | Datos de prueba, solo desarrollo |
| `scripts/` | Respaldo y restauración locales |
| `docs/` | `PRD.md`, `ARCHITECTURE.md` (diccionario de datos) |

## Uso local

```bash
cp .env.example .env
docker compose up -d                    # Postgres 18 + Flyway (disponible tras la Task 1.4)
docker compose run --rm flyway info
docker compose run --rm flyway validate
docker compose down                     # los datos quedan en el volumen
```

Conexión local: `jdbc:postgresql://localhost:5432/cuymonitor`, usuario y contraseña `cuymonitor`.

## Reglas

- Nunca edites una migración que ya está en `main`; crea `V{n+1}`.
- Cada migración nueva actualiza el diccionario de datos en `docs/ARCHITECTURE.md`.
- Commits en Conventional Commits; `main` solo por Pull Request.

Más detalle en `AGENTS.md`, `docs/PRD.md` y `docs/ARCHITECTURE.md`.
