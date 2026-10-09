-- JWTs the backend must reject before they expire (logout). jti is the token id claim.
-- Rows are only useful until expires_at, so the backend can delete them after that.

CREATE TABLE revoked_token (
    jti        UUID        NOT NULL,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT pk_revoked_token PRIMARY KEY (jti),
    CONSTRAINT ck_revoked_token_expires CHECK (expires_at > revoked_at)
);

-- cleanup of tokens that already expired
CREATE INDEX ix_revoked_token_expires_at ON revoked_token (expires_at);
