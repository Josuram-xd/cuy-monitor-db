-- Until now every account could do exactly the same things. The breeds, mark colors and coat colors
-- live in catalog_option (V10) so they can change without a release, but nothing in the app could
-- edit them: adding a breed still meant running SQL by hand. An admin panel needs someone to be an
-- admin first.

ALTER TABLE app_user ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'BREEDER';

ALTER TABLE app_user ADD CONSTRAINT ck_app_user_role
    CHECK (role IN ('BREEDER', 'ADMIN'));

-- The owner of the pilot cage (V12) becomes the first admin: the system needs one to exist, and
-- promoting the account that is already there avoids inventing a user with a password in a migration.
UPDATE app_user u
SET role = 'ADMIN'
WHERE u.id = (SELECT c.owner_id FROM cage c WHERE c.code = 'cage-1' AND c.owner_id IS NOT NULL);

-- The admin screen lists accounts by role, and there are few rows, so no index is needed yet.
