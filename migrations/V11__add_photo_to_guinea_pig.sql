-- A cuy is now registered with its photo instead of a name: the breeder recognizes the animal in the
-- picture, and a made-up name was one more thing to invent and to keep straight.
-- The photo is stored here because it is small (the dashboard shrinks it before sending) and this way there
-- is no bucket, no credentials and no extra cost.

ALTER TABLE guinea_pig ADD COLUMN photo BYTEA;
ALTER TABLE guinea_pig ADD COLUMN photo_content_type VARCHAR(30);

ALTER TABLE guinea_pig ADD CONSTRAINT ck_guinea_pig_photo
    CHECK ((photo IS NULL) = (photo_content_type IS NULL));

-- the bytes are served back to a browser, so only image types that cannot carry a script
ALTER TABLE guinea_pig ADD CONSTRAINT ck_guinea_pig_photo_content_type
    CHECK (photo_content_type IS NULL OR photo_content_type IN ('image/jpeg', 'image/png', 'image/webp'));

-- 300 KB: more than enough for the 512 px picture the dashboard sends, and it keeps a row readable
ALTER TABLE guinea_pig ADD CONSTRAINT ck_guinea_pig_photo_size
    CHECK (photo IS NULL OR octet_length(photo) BETWEEN 1 AND 307200);

-- The name stops being required here, and the backend stops reading and writing it. The column itself is
-- dropped in a later migration, once a backend that no longer maps it is deployed (two-step rule).
ALTER TABLE guinea_pig ALTER COLUMN name DROP NOT NULL;
ALTER TABLE guinea_pig DROP CONSTRAINT ck_guinea_pig_name;
