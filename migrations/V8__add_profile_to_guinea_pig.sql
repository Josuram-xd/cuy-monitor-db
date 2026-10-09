-- Registration of a guinea pig now also records its breed, coat color, weight on arrival and notes.
-- All optional: the ones registered before this migration keep NULL.

ALTER TABLE guinea_pig ADD COLUMN breed VARCHAR(20);
ALTER TABLE guinea_pig ADD COLUMN coat_color VARCHAR(20);
ALTER TABLE guinea_pig ADD COLUMN initial_weight_grams INTEGER;
ALTER TABLE guinea_pig ADD COLUMN notes VARCHAR(500);

ALTER TABLE guinea_pig ADD CONSTRAINT ck_guinea_pig_breed
    CHECK (breed IS NULL OR breed IN ('AMERICAN', 'PERUVIAN', 'ABYSSINIAN', 'TEDDY', 'SILKIE', 'SKINNY', 'CRESTED', 'OTHER'));

ALTER TABLE guinea_pig ADD CONSTRAINT ck_guinea_pig_coat_color
    CHECK (coat_color IS NULL OR coat_color IN ('WHITE', 'BLACK', 'BROWN', 'CREAM', 'GRAY', 'CINNAMON', 'BICOLOR', 'TRICOLOR'));

-- a healthy adult is about 700 to 1200 g; the limits only reject typing mistakes
ALTER TABLE guinea_pig ADD CONSTRAINT ck_guinea_pig_initial_weight_grams
    CHECK (initial_weight_grams IS NULL OR initial_weight_grams BETWEEN 50 AND 2000);
