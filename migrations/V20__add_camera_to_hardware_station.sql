-- The camera of the shared kit, set by the breeder from the dashboard and read by the edge agent.
-- The password is encrypted by the backend (AES-GCM); it is never stored in plain text.
ALTER TABLE hardware_station
    ADD COLUMN camera_type varchar(10)
        CONSTRAINT ck_hardware_station_camera_type CHECK (camera_type IN ('PHONE', 'RTSP')),
    ADD COLUMN camera_host varchar(15),
    ADD COLUMN camera_port integer
        CONSTRAINT ck_hardware_station_camera_port CHECK (camera_port BETWEEN 1 AND 65535),
    ADD COLUMN camera_username varchar(64),
    ADD COLUMN camera_password_enc text,
    ADD COLUMN camera_stream varchar(10)
        CONSTRAINT ck_hardware_station_camera_stream CHECK (camera_stream IN ('stream1', 'stream2')),
    -- bumped on every save; the agent echoes it so a late report never overwrites a newer config
    ADD COLUMN camera_version integer NOT NULL DEFAULT 0,
    ADD COLUMN camera_status varchar(20)
        CONSTRAINT ck_hardware_station_camera_status
            CHECK (camera_status IN ('CONNECTED', 'AUTH_FAILED', 'UNREACHABLE', 'FFMPEG_MISSING')),
    ADD COLUMN camera_status_at timestamptz,
    ADD CONSTRAINT ck_hardware_station_camera_complete
        CHECK ((camera_type IS NULL) = (camera_host IS NULL) AND (camera_type IS NULL) = (camera_port IS NULL)),
    ADD CONSTRAINT ck_hardware_station_camera_status_at
        CHECK ((camera_status IS NULL) = (camera_status_at IS NULL));
