CREATE TABLE app_user (
    id            UUID         PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL,
    full_name     VARCHAR(150) NOT NULL,
    email         VARCHAR(254) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    status        VARCHAR(30)  NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL,
    updated_at    TIMESTAMPTZ  NOT NULL,

    CONSTRAINT uq_app_user_username UNIQUE (username),
    CONSTRAINT uq_app_user_email UNIQUE (email),
    CONSTRAINT ck_app_user_status CHECK (status IN ('PENDING_VERIFICATION', 'ACTIVE', 'DISABLED'))
);

CREATE TABLE otp_challenge (
    id           UUID         PRIMARY KEY,
    user_id      UUID         NOT NULL,
    code_hash    VARCHAR(100) NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL,
    expires_at   TIMESTAMPTZ  NOT NULL,
    max_attempts INT          NOT NULL,
    attempts     INT          NOT NULL DEFAULT 0,
    used_at      TIMESTAMPTZ,
    revoked_at   TIMESTAMPTZ,

    CONSTRAINT fk_otp_challenge_user FOREIGN KEY (user_id) REFERENCES app_user (id),
    CONSTRAINT ck_otp_challenge_max_attempts CHECK (max_attempts > 0),
    CONSTRAINT ck_otp_challenge_attempts CHECK (attempts >= 0)
);

CREATE INDEX ix_otp_challenge_user_pending
    ON otp_challenge (user_id)
    WHERE used_at IS NULL AND revoked_at IS NULL;
