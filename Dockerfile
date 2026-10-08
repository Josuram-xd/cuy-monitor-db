# One-shot "migrate" image: applies migrations/ to Amazon RDS before the backend starts.
# Same Flyway version as docker-compose.yml; never use :latest.
FROM flyway/flyway:11.20.3-alpine

COPY flyway.conf /flyway/conf/flyway.conf
# production gets versioned migrations only; seeds/dev never goes into this image
COPY migrations /flyway/sql
COPY scripts/migrate-entrypoint.sh /usr/local/bin/migrate-entrypoint.sh
RUN chmod 0755 /usr/local/bin/migrate-entrypoint.sh

ENV FLYWAY_LOCATIONS=filesystem:/flyway/sql

ENTRYPOINT ["/usr/local/bin/migrate-entrypoint.sh"]
CMD ["migrate"]
