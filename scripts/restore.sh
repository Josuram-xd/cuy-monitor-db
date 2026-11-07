#!/usr/bin/env bash
# Restores a backup made by scripts/backup.sh. It REPLACES the tables of the target database.
#
#   scripts/restore.sh backups/cuymonitor-20261105-120000.dump                 # into the local database
#   TARGET_DB=cuymonitor_copy scripts/restore.sh backups/...dump               # into another local database (created if missing)
#   DATABASE_URL=postgresql://... scripts/restore.sh backups/...dump --yes     # any other; --yes is required
#
# It asks before touching anything unless --yes is given. Restoring production from a dump is a last resort:
# on RDS, prefer a snapshot or a point-in-time restore (docs/BACKUP.md).
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dump="${1:-}"
confirmed="${2:-}"
[ -f "$dump" ] || { echo "Usage: scripts/restore.sh <file.dump> [--yes]"; exit 1; }
dump="$(cd "$(dirname "$dump")" && pwd)/$(basename "$dump")"
target_db="${TARGET_DB:-cuymonitor}"
target="${DATABASE_URL:-local database $target_db}"

if [ -n "${DATABASE_URL:-}" ] && [ "$confirmed" != "--yes" ]; then
  echo "Restoring into $DATABASE_URL needs --yes"; exit 1
fi
if [ "$confirmed" != "--yes" ]; then
  read -r -p "This replaces every table of the $target with $(basename "$dump"). Continue? [y/N] " answer
  [ "$answer" = "y" ] || [ "$answer" = "Y" ] || { echo "Nothing was changed"; exit 1; }
fi

if [ -n "${DATABASE_URL:-}" ]; then
  docker run --rm --network host -v "$(dirname "$dump"):/backups:ro,Z" postgres:18 \
    pg_restore --clean --if-exists --no-owner --no-privileges --single-transaction \
    --dbname="$DATABASE_URL" "/backups/$(basename "$dump")"
else
  compose=(docker compose -f "$repo_dir/docker-compose.yml" exec -T postgres)
  "${compose[@]}" psql -U cuymonitor -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$target_db'" \
    | grep -q 1 || "${compose[@]}" createdb -U cuymonitor "$target_db"
  "${compose[@]}" pg_restore --clean --if-exists --no-owner --no-privileges --single-transaction \
    -U cuymonitor -d "$target_db" < "$dump"
fi
echo "Restored $(basename "$dump") into the $target"
