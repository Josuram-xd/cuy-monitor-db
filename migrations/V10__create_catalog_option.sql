-- The mark colors, breeds and coat colors used to live as a hardcoded list in three places: the enums of
-- the backend, these CHECK constraints and the arrays of the dashboard. Adding or renaming one meant
-- changing code in two repos. From here on they are rows: this table is the only source of truth and the
-- backend serves it to the dashboard, so a new color is an INSERT and nothing else.

CREATE TABLE catalog_option (
    kind       VARCHAR(20) NOT NULL,
    code       VARCHAR(20) NOT NULL,
    label      VARCHAR(60) NOT NULL,
    hex        CHAR(7),
    sort_order SMALLINT    NOT NULL,
    active     BOOLEAN     NOT NULL DEFAULT true,

    CONSTRAINT pk_catalog_option PRIMARY KEY (kind, code),
    CONSTRAINT ck_catalog_option_kind CHECK (kind IN ('MARK_COLOR', 'COAT_COLOR', 'BREED')),
    CONSTRAINT ck_catalog_option_code CHECK (code = upper(code) AND code ~ '^[A-Z0-9_]+$'),
    CONSTRAINT ck_catalog_option_label CHECK (length(trim(label)) > 0),
    -- the dashboard paints the dot with this value, so only a plain hex color is allowed in
    CONSTRAINT ck_catalog_option_hex CHECK (hex IS NULL OR hex ~ '^#[0-9a-f]{6}$')
);

CREATE INDEX ix_catalog_option_kind_sort ON catalog_option (kind, sort_order);

-- The eight mark colors are the ones the camera can tell apart on a cuy's back.
INSERT INTO catalog_option (kind, code, label, hex, sort_order) VALUES
    ('MARK_COLOR', 'RED',    'Rojo',     '#d62828', 1),
    ('MARK_COLOR', 'BLUE',   'Azul',     '#1e63d6', 2),
    ('MARK_COLOR', 'GREEN',  'Verde',    '#2e9e44', 3),
    ('MARK_COLOR', 'YELLOW', 'Amarillo', '#f5c518', 4),
    ('MARK_COLOR', 'ORANGE', 'Naranja',  '#f77f00', 5),
    ('MARK_COLOR', 'PURPLE', 'Morado',   '#7b3fb5', 6),
    ('MARK_COLOR', 'BLACK',  'Negro',    '#1a1a1a', 7),
    ('MARK_COLOR', 'WHITE',  'Blanco',   '#ffffff', 8);

-- Coat color is the real color of the fur. BICOLOR and TRICOLOR keep the dominant color as their sample.
INSERT INTO catalog_option (kind, code, label, hex, sort_order) VALUES
    ('COAT_COLOR', 'WHITE',    'Blanco',   '#ffffff', 1),
    ('COAT_COLOR', 'BLACK',    'Negro',    '#2a2623', 2),
    ('COAT_COLOR', 'BROWN',    'Café',     '#8b5a3c', 3),
    ('COAT_COLOR', 'CREAM',    'Crema',    '#f3e2bd', 4),
    ('COAT_COLOR', 'GRAY',     'Gris',     '#a6a6a6', 5),
    ('COAT_COLOR', 'CINNAMON', 'Canela',   '#c9763d', 6),
    ('COAT_COLOR', 'BICOLOR',  'Bicolor',  '#8b5a3c', 7),
    ('COAT_COLOR', 'TRICOLOR', 'Tricolor', '#c9763d', 8);

-- A breed has no color sample, so hex stays NULL.
INSERT INTO catalog_option (kind, code, label, hex, sort_order) VALUES
    ('BREED', 'AMERICAN',   'Americano',         NULL, 1),
    ('BREED', 'PERUVIAN',   'Peruano',           NULL, 2),
    ('BREED', 'ABYSSINIAN', 'Abisinio',          NULL, 3),
    ('BREED', 'TEDDY',      'Teddy',             NULL, 4),
    ('BREED', 'SILKIE',     'Sedoso (Silkie)',   NULL, 5),
    ('BREED', 'SKINNY',     'Skinny (sin pelo)', NULL, 6),
    ('BREED', 'CRESTED',    'Crestado',          NULL, 7),
    ('BREED', 'OTHER',      'Otra o mestizo',    NULL, 8);

-- These three CHECKs were the same list written again: with the table above they would have to be edited
-- by hand on every change, which is what we are removing. The backend now rejects a code that is not an
-- active row of catalog_option. No foreign key: it would need a constant column per reference just to
-- match the composite primary key.
ALTER TABLE guinea_pig DROP CONSTRAINT ck_guinea_pig_mark_color;
ALTER TABLE guinea_pig DROP CONSTRAINT ck_guinea_pig_breed;
ALTER TABLE guinea_pig DROP CONSTRAINT ck_guinea_pig_coat_color;
