# Runbook — migraciones en producción (Amazon RDS)

Cómo llega una migración nueva a la RDS `cuy-monitor-db` (Task 5.3). Es el procedimiento real con el que se
desplegó V13 y V14 el 2026-11-06; las reglas de fondo están en `docs/ARCHITECTURE.md`, sección 6.

## Cómo funciona

- En la EC2 los 4 repos viven uno al lado del otro en `/home/admin`. El `docker-compose.yml` del backend
  (`cuy-monitor-backend/infra/`) construye la imagen `migrate` desde **este** repo (`build: ../../cuy-monitor-db`).
- `migrate` corre **una vez** en cada despliegue: aplica lo que falte de `migrations/` y termina. La imagen solo
  lleva `migrations/`, nunca `seeds/`, así que los datos de prueba no pueden llegar a la RDS.
- El backend arranca solo si `migrate` terminó bien (`depends_on: condition: service_completed_successfully`):
  una migración que falla detiene el despliegue y el backend nuevo no arranca.
- La contraseña de la base no está en el repo: `infra/refresh-db-password.sh` la copia de Secrets Manager a
  `infra/.env` (la RDS la rota cada 7 días) y `deploy.sh` lo llama antes de levantar el stack.

## 1. Antes de desplegar

1. La migración está en `main` de este repo, fusionada por PR, y el backend que la necesita también.
   `./mvnw test` del backend aplica las migraciones en un Postgres desechable (Testcontainers): si pasa, el
   esquema y las entidades JPA coinciden.
2. Nunca se edita una migración que ya está en `main`: un cambio es una `V{n+1}` nueva.
3. **Si la migración es riesgosa** (un `NOT NULL` nuevo, cambio de tipo, actualización grande de datos), toma
   un snapshot manual antes:

   ```bash
   aws rds create-db-snapshot --db-instance-identifier cuy-monitor-db \
       --db-snapshot-identifier cuy-before-v15-$(date +%Y%m%d)
   aws rds wait db-snapshot-available --db-snapshot-identifier cuy-before-v15-$(date +%Y%m%d)
   ```

4. La RDS tiene que estar encendida (`aws rds describe-db-instances --db-instance-identifier cuy-monitor-db
   --query 'DBInstances[0].DBInstanceStatus'` → `available`) y la EC2 también.

## 2. Desplegar

Todo junto con el script del backend, que deja los 4 repos exactamente en `origin/main`:

```bash
# por SSM, sin abrir SSH
aws ssm send-command --instance-ids <id de la EC2> --document-name AWS-RunShellScript \
    --parameters '{"commands":["sudo -iu admin bash -lc \"~/cuy-monitor-backend/infra/deploy.sh\""]}'

# o por SSH
ssh -i cuy-key-pair.pem admin@cuymonitor.duckdns.org '~/cuy-monitor-backend/infra/deploy.sh'
```

Para probar la migración de una rama antes de fusionarla: `DB_REF=feature/x ~/cuy-monitor-backend/infra/deploy.sh`.

## 3. Verificar

En la EC2, desde `~/cuy-monitor-backend/infra`:

```bash
docker compose ps -a migrate        # tiene que decir: Exited (0)
docker compose logs migrate | grep -E "Successfully|Current version"
curl -s https://cuymonitor.duckdns.org/actuator/health   # {"status":"UP"...}
```

Lo que se ve cuando sale bien (despliegue del 2026-11-06):

```
Successfully validated 14 migrations
Current version of schema "public": 12
Successfully applied 2 migrations to schema "public", now at version v14
```

Sin migraciones nuevas dice `Schema "public" is up to date. No migration necessary.` y también termina con 0.

## 4. Si falla

1. `docker compose logs migrate` dice qué migración y qué sentencia fallaron; `deploy.sh` termina con error y el
   backend nuevo no arranca. Revisa con `docker compose ps` si el anterior sigue arriba.
2. Flyway hace cada migración en una transacción: en PostgreSQL una migración que falla no deja cambios a
   medias (salvo `CREATE INDEX CONCURRENTLY`, que no corre en una transacción: evítalo o ponlo en una
   migración sola). Arréglala con una migración nueva (o corrigiendo la que falló, si nunca llegó a
   aplicarse en ningún lado) y vuelve a desplegar.
3. Restaura el snapshot del paso 1.3 **solo si se dañaron datos**: crea una instancia nueva desde el snapshot,
   revisa que esté bien y cambia `DB_HOST` en `infra/.env` (la guía de snapshots y restauración a un punto en el
   tiempo está en `docs/BACKUP.md`).
4. Nunca uses `flyway clean` (borra todo; `cleanDisabled=true` en `flyway.conf` lo bloquea) ni `flyway repair`
   contra la RDS sin entender antes qué cambia en `flyway_schema_history`.
