-- Health tables used by the backend core. Enum values must match cuy-monitor-backend/docs/contracts/.

CREATE TABLE guinea_pig (
    id             BIGSERIAL    NOT NULL,
    cage_id        BIGINT       NOT NULL,
    name           VARCHAR(100) NOT NULL,
    mark_color     VARCHAR(20)  NOT NULL,
    current_status VARCHAR(20)  NOT NULL DEFAULT 'NORMAL',
    status_since   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    active         BOOLEAN      NOT NULL DEFAULT true,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT pk_guinea_pig PRIMARY KEY (id),
    CONSTRAINT fk_guinea_pig_cage FOREIGN KEY (cage_id) REFERENCES cage (id),
    -- the camera tells guinea pigs apart only by the mark on their back
    CONSTRAINT uq_guinea_pig_cage_color UNIQUE (cage_id, mark_color),
    CONSTRAINT ck_guinea_pig_mark_color
        CHECK (mark_color IN ('RED', 'BLUE', 'GREEN', 'YELLOW', 'ORANGE', 'PURPLE', 'BLACK', 'WHITE')),
    CONSTRAINT ck_guinea_pig_current_status
        CHECK (current_status IN ('NORMAL', 'OBSERVED', 'ALERT', 'CRITICAL')),
    CONSTRAINT ck_guinea_pig_name CHECK (length(trim(name)) > 0)
);

CREATE TABLE event (
    id            UUID        NOT NULL,
    type          VARCHAR(20) NOT NULL,
    cage_id       BIGINT      NOT NULL,
    guinea_pig_id BIGINT,
    source        VARCHAR(30) NOT NULL,
    occurred_at   TIMESTAMPTZ NOT NULL,
    received_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload       JSONB       NOT NULL,

    -- id is the producer's eventId: a retried event can never be stored twice
    CONSTRAINT pk_event PRIMARY KEY (id),
    CONSTRAINT fk_event_cage FOREIGN KEY (cage_id) REFERENCES cage (id),
    CONSTRAINT fk_event_guinea_pig FOREIGN KEY (guinea_pig_id) REFERENCES guinea_pig (id),
    CONSTRAINT ck_event_type CHECK (type IN ('BEHAVIOR', 'AUDIO', 'WEIGHT')),
    -- BEHAVIOR belongs to one guinea pig; AUDIO and WEIGHT are cage-level
    CONSTRAINT ck_event_guinea_pig_scope CHECK ((type = 'BEHAVIOR') = (guinea_pig_id IS NOT NULL))
);

CREATE INDEX ix_event_guinea_pig_occurred ON event (guinea_pig_id, occurred_at DESC);
CREATE INDEX ix_event_cage_type_occurred ON event (cage_id, type, occurred_at DESC);

CREATE TABLE state_transition (
    id            BIGSERIAL    NOT NULL,
    guinea_pig_id BIGINT       NOT NULL,
    from_status   VARCHAR(20)  NOT NULL,
    to_status     VARCHAR(20)  NOT NULL,
    reason        VARCHAR(300) NOT NULL,
    occurred_at   TIMESTAMPTZ  NOT NULL,

    CONSTRAINT pk_state_transition PRIMARY KEY (id),
    CONSTRAINT fk_state_transition_guinea_pig FOREIGN KEY (guinea_pig_id) REFERENCES guinea_pig (id),
    CONSTRAINT ck_state_transition_from_status
        CHECK (from_status IN ('NORMAL', 'OBSERVED', 'ALERT', 'CRITICAL')),
    CONSTRAINT ck_state_transition_to_status
        CHECK (to_status IN ('NORMAL', 'OBSERVED', 'ALERT', 'CRITICAL')),
    CONSTRAINT ck_state_transition_changes CHECK (from_status <> to_status)
);

CREATE INDEX ix_state_transition_guinea_pig_occurred ON state_transition (guinea_pig_id, occurred_at DESC);

CREATE TABLE alert (
    id            BIGSERIAL    NOT NULL,
    cage_id       BIGINT       NOT NULL,
    guinea_pig_id BIGINT,
    level         VARCHAR(20)  NOT NULL,
    type          VARCHAR(20)  NOT NULL,
    message       VARCHAR(500) NOT NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    reviewed_at   TIMESTAMPTZ,

    CONSTRAINT pk_alert PRIMARY KEY (id),
    CONSTRAINT fk_alert_cage FOREIGN KEY (cage_id) REFERENCES cage (id),
    CONSTRAINT fk_alert_guinea_pig FOREIGN KEY (guinea_pig_id) REFERENCES guinea_pig (id),
    CONSTRAINT ck_alert_level CHECK (level IN ('ALERT', 'CRITICAL')),
    CONSTRAINT ck_alert_type CHECK (type IN ('BEHAVIOR', 'AUDIO', 'WEIGHT')),
    CONSTRAINT ck_alert_status CHECK (status IN ('OPEN', 'REVIEWED')),
    CONSTRAINT ck_alert_guinea_pig_scope CHECK ((type = 'BEHAVIOR') = (guinea_pig_id IS NOT NULL)),
    -- a reviewed alert always says when it was reviewed, an open one never does
    CONSTRAINT ck_alert_reviewed_at CHECK ((status = 'REVIEWED') = (reviewed_at IS NOT NULL))
);

CREATE INDEX ix_alert_status_created ON alert (status, created_at DESC);
CREATE INDEX ix_alert_cage_created ON alert (cage_id, created_at DESC);

CREATE TABLE weight_reading (
    id          BIGSERIAL    NOT NULL,
    cage_id     BIGINT       NOT NULL,
    grams       NUMERIC(7, 1) NOT NULL,
    stable      BOOLEAN      NOT NULL,
    measured_at TIMESTAMPTZ  NOT NULL,

    CONSTRAINT pk_weight_reading PRIMARY KEY (id),
    CONSTRAINT fk_weight_reading_cage FOREIGN KEY (cage_id) REFERENCES cage (id),
    CONSTRAINT ck_weight_reading_grams CHECK (grams >= 0)
);

CREATE INDEX ix_weight_reading_cage_measured ON weight_reading (cage_id, measured_at DESC);

CREATE TABLE baseline_profile (
    guinea_pig_id      BIGINT        NOT NULL,
    avg_still_seconds  NUMERIC(6, 2) NOT NULL,
    avg_feeder_visits  NUMERIC(6, 2) NOT NULL,
    avg_group_distance NUMERIC(5, 4) NOT NULL,
    updated_at         TIMESTAMPTZ   NOT NULL,

    CONSTRAINT pk_baseline_profile PRIMARY KEY (guinea_pig_id),
    CONSTRAINT fk_baseline_profile_guinea_pig FOREIGN KEY (guinea_pig_id) REFERENCES guinea_pig (id),
    CONSTRAINT ck_baseline_profile_still CHECK (avg_still_seconds >= 0),
    CONSTRAINT ck_baseline_profile_feeder CHECK (avg_feeder_visits >= 0),
    CONSTRAINT ck_baseline_profile_distance CHECK (avg_group_distance BETWEEN 0 AND 1)
);
