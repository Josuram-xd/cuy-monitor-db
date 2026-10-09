-- Sign in with Google: an account can exist without a password. Google proves the email, so
-- those accounts are created ACTIVE and identified by Google's stable user id ("sub"), never by email.

ALTER TABLE app_user ALTER COLUMN password_hash DROP NOT NULL;

ALTER TABLE app_user ADD COLUMN google_subject VARCHAR(255);

ALTER TABLE app_user ADD CONSTRAINT uq_app_user_google_subject UNIQUE (google_subject);

-- every account can sign in some way: with a password, with Google, or both
ALTER TABLE app_user ADD CONSTRAINT ck_app_user_login_method
    CHECK (password_hash IS NOT NULL OR google_subject IS NOT NULL);
