-- Long-lived session tokens. The cookie holds a random value; only its SHA-256 hash is stored here.
-- Every use rotates the token inside the same family; reusing a rotated one revokes the whole family.

CREATE TABLE refresh_token (
    id         UUID        NOT NULL,
    user_id    UUID        NOT NULL,
    family_id  UUID        NOT NULL,
    token_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,

    CONSTRAINT pk_refresh_token PRIMARY KEY (id),
    CONSTRAINT fk_refresh_token_user FOREIGN KEY (user_id) REFERENCES app_user (id),
    CONSTRAINT uq_refresh_token_token_hash UNIQUE (token_hash),
    CONSTRAINT ck_refresh_token_expires CHECK (expires_at > created_at)
);

CREATE INDEX ix_refresh_token_user_id ON refresh_token (user_id);
-- revoke a whole family when a rotated token is reused
CREATE INDEX ix_refresh_token_family_id ON refresh_token (family_id);
-- cleanup of tokens that already expired
CREATE INDEX ix_refresh_token_expires_at ON refresh_token (expires_at);
