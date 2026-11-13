-- The breeder can now put a face and a short name to their own account, the same way a cuy is
-- registered with its photo (V11). Both are optional: an account that sets neither looks exactly
-- as it did before.

-- A short name the breeder picks and can change. Unlike username it is not an identifier: it is not
-- unique, it is never used to log in, and the screens fall back to full_name when it is empty.
ALTER TABLE app_user ADD COLUMN nickname VARCHAR(30);

ALTER TABLE app_user ADD CONSTRAINT ck_app_user_nickname
    CHECK (nickname IS NULL OR length(btrim(nickname)) BETWEEN 1 AND 30);

-- Same reasoning as V11: the picture is small (the dashboard shrinks it before sending), so storing
-- it here means no bucket, no credentials and no extra cost.
ALTER TABLE app_user ADD COLUMN photo BYTEA;
ALTER TABLE app_user ADD COLUMN photo_content_type VARCHAR(30);

ALTER TABLE app_user ADD CONSTRAINT ck_app_user_photo
    CHECK ((photo IS NULL) = (photo_content_type IS NULL));

-- the bytes are served back to a browser, so only image types that cannot carry a script
ALTER TABLE app_user ADD CONSTRAINT ck_app_user_photo_content_type
    CHECK (photo_content_type IS NULL OR photo_content_type IN ('image/jpeg', 'image/png', 'image/webp'));

-- 300 KB, the same ceiling as a cuy's photo: plenty for the 512 px picture the dashboard sends
ALTER TABLE app_user ADD CONSTRAINT ck_app_user_photo_size
    CHECK (photo IS NULL OR octet_length(photo) BETWEEN 1 AND 307200);
