# Respaldo y restauración

Dos niveles: **dumps** (`pg_dump`) para la base local o para llevarse una copia, y **snapshots de RDS** para
producción. En producción siempre se prefiere un snapshot o la restauración a un punto en el tiempo: son de AWS,
no pasan por la red de nadie y no hay que guardar archivos con datos reales.

## 1. Base local (Task 8.1)

```bash
scripts/backup.sh                                          # backups/cuymonitor-AAAAMMDD-HHMMSS.dump
scripts/restore.sh backups/cuymonitor-....dump             # pregunta antes de reemplazar las tablas
TARGET_DB=cuymonitor_copia scripts/restore.sh backups/cuymonitor-....dump --yes   # en otra base, sin tocar la de siempre
```

- Formato `custom` de `pg_dump`: comprimido y restaurable tabla por tabla.
- `pg_dump` y `pg_restore` corren en la imagen `postgres:18`, así que no hay que instalar nada y el cliente
  siempre coincide con el servidor.
- `backups/` y `*.dump` están en `.gitignore`: un respaldo trae datos reales y **nunca** se sube al repo.
- La restauración es una sola transacción: si algo falla, la base queda como estaba.

## 2. RDS en producción (Task 8.2)

Instancia `cuy-monitor-db` (PostgreSQL 18, `db.t3.micro`, 20 GB) en `us-east-1`. Los comandos usan el perfil
de la AWS CLI `cuy`; desde la consola es lo mismo en **RDS → Databases → cuy-monitor-db**.

### Respaldos automáticos

AWS toma un snapshot por día en la ventana `08:12–08:42 UTC` y guarda los registros de transacciones, lo que
permite volver a **cualquier segundo** dentro del periodo de retención.

> **Hoy la retención es de 1 día.** Con 1 día, un error que se nota al día siguiente ya no tiene vuelta.
> Recomendado: 7 días (el almacenamiento de respaldos es gratis hasta el tamaño de la base, 20 GB):
>
> ```bash
> aws rds modify-db-instance --profile cuy --region us-east-1 \
>   --db-instance-identifier cuy-monitor-db --backup-retention-period 7 --apply-immediately
> ```

Ver la retención y hasta qué momento se puede restaurar:

```bash
aws rds describe-db-instances --profile cuy --region us-east-1 --db-instance-identifier cuy-monitor-db \
  --query 'DBInstances[0].[BackupRetentionPeriod,PreferredBackupWindow,LatestRestorableTime]' --output text
```

### Snapshot manual antes de la prueba en la jaula (Task 8.3)

Un snapshot manual no vence: queda hasta que alguien lo borre. Se toma antes de cualquier cambio grande
(la prueba en la jaula, una migración que toca datos).

```bash
aws rds create-db-snapshot --profile cuy --region us-east-1 \
  --db-instance-identifier cuy-monitor-db --db-snapshot-identifier cuy-monitor-db-antes-prueba-jaula
aws rds wait db-snapshot-available --profile cuy --region us-east-1 \
  --db-snapshot-identifier cuy-monitor-db-antes-prueba-jaula
```

### Restaurar

Restaurar **nunca** pisa la instancia actual: siempre crea una **nueva**. Después se apunta el backend a ella.

```bash
# a) desde un snapshot
aws rds restore-db-instance-from-db-snapshot --profile cuy --region us-east-1 \
  --db-instance-identifier cuy-monitor-db-restaurada \
  --db-snapshot-identifier cuy-monitor-db-antes-prueba-jaula \
  --db-instance-class db.t3.micro --no-publicly-accessible \
  --vpc-security-group-ids <el mismo security group de cuy-monitor-db>

# b) a un punto en el tiempo (dentro de la retención)
aws rds restore-db-instance-to-point-in-time --profile cuy --region us-east-1 \
  --source-db-instance-identifier cuy-monitor-db --target-db-instance-identifier cuy-monitor-db-restaurada \
  --restore-time 2026-11-12T14:00:00Z --db-instance-class db.t3.micro --no-publicly-accessible \
  --vpc-security-group-ids <el mismo security group de cuy-monitor-db>

aws rds wait db-instance-available --profile cuy --region us-east-1 --db-instance-identifier cuy-monitor-db-restaurada
```

Luego, en la EC2:

1. Cambiar `DB_HOST` en `~/cuy-monitor-backend/infra/.env` por el endpoint de `cuy-monitor-db-restaurada`.
2. `~/cuy-monitor-backend/infra/deploy.sh` (el servicio `migrate` no hace nada si el esquema ya está al día).
3. Revisar `/actuator/health` y el dashboard.
4. Cuando todo esté bien, borrar la instancia vieja (y tomarle antes un snapshot final si se quiere guardar).

La contraseña sigue siendo la de la instancia original; si se usa la contraseña administrada por RDS,
`infra/refresh-db-password.sh` la vuelve a leer.

### Costos

- Respaldos automáticos y snapshots: gratis hasta el tamaño de la base (20 GB); de ahí, unos 0,095 USD por GB al mes.
- Una instancia restaurada cobra como cualquier otra mientras exista: hay que borrar la que no se usa.
- Una RDS **detenida** no cobra cómputo pero sí el disco, y AWS la vuelve a encender sola a los 7 días.

### Copia lógica de producción

Si hace falta un archivo (por ejemplo, para revisar datos de la prueba en una laptop), se hace **desde la EC2**,
que es la única que llega a la RDS, y el archivo no se deja en la máquina:

```bash
DATABASE_URL="postgresql://cuymonitor:<contraseña>@<endpoint>:5432/cuymonitor?sslmode=require" scripts/backup.sh
```
