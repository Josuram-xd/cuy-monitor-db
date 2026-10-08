-- Pilot cage. The rest of the tables (guinea_pig, event, alert, ...) go in later migrations.
CREATE TABLE cage (
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    location   VARCHAR(200),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO cage (name, location) VALUES ('Jaula piloto', 'Laboratorio');
