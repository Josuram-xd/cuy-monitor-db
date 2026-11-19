-- What an admin changed from the panel: health rules, alert messages and the assistant's question limit.
-- Only the changed values are stored; a key that is not here keeps the backend's default (application.yml),
-- so "back to the defaults" is deleting the rows and a new default reaches every database that never changed it.
CREATE TABLE app_setting (
    key        VARCHAR(60)  NOT NULL,
    value      VARCHAR(500) NOT NULL,
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- who changed it last; NULL if that account is gone
    updated_by UUID,

    CONSTRAINT pk_app_setting PRIMARY KEY (key),
    CONSTRAINT fk_app_setting_updated_by FOREIGN KEY (updated_by) REFERENCES app_user (id) ON DELETE SET NULL,
    CONSTRAINT ck_app_setting_key CHECK (key ~ '^[a-z]+(\.[a-zA-Z]+)+$')
);
