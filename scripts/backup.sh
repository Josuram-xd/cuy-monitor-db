#!/usr/bin/env bash
# Backup of a Cuy Monitor database with pg_dump (custom format: compressed, restorable table by table).
#
#   scripts/backup.sh                              # the local database of docker-compose.yml
#   DATABASE_URL=postgresql://user:pass@host:5432/cuymonitor scripts/backup.sh   # any other (e.g. RDS from the EC2)
#
# The file goes to backups/ (ignored by git: it holds real data). pg_dump runs in the postgres:18 image, so the
# client always matches the server and nothing has to be installed.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="${BACKUP_DIR:-$repo_dir/backups}"
mkdir -p "$out_dir"
file="cuymonitor-$(date -u +%Y%m%d-%H%M%S).dump"

if [ -n "${DATABASE_URL:-}" ]; then
  docker run --rm --network host -v "$out_dir:/backups:Z" postgres:18 \
    pg_dump --format=custom --no-owner --no-privileges --file="/backups/$file" "$DATABASE_URL"
else
  docker compose -f "$repo_dir/docker-compose.yml" exec -T postgres \
    pg_dump --format=custom --no-owner --no-privileges -U cuymonitor -d cuymonitor > "$out_dir/$file"
fi

size="$(du -h "$out_dir/$file" | cut -f1)"
echo "Backup written: $out_dir/$file ($size)"
