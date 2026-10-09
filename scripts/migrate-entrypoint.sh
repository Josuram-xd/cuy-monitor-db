#!/bin/sh
# Entry point of the migrate image. DB_* come from Compose on the EC2 (infra/.env).
# The password goes in FLYWAY_PASSWORD, never as a command-line argument (it would show up in `ps`).
set -eu

: "${DB_HOST:?DB_HOST is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"

# RDS only accepts encrypted connections; use DB_SSLMODE=disable only against a local database
export FLYWAY_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT:-5432}/${DB_NAME}?sslmode=${DB_SSLMODE:-require}"
export FLYWAY_USER="$DB_USER"
export FLYWAY_PASSWORD="$DB_PASSWORD"

if [ "$#" -eq 0 ]; then
    set -- migrate
fi
exec flyway "$@"
