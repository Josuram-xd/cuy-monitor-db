-- One physical kit shared by the demonstration accounts. NULL means available.
CREATE TABLE hardware_station (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    cage_id bigint REFERENCES cage(id),
    since timestamptz,
    CHECK ((cage_id IS NULL) = (since IS NULL))
);
INSERT INTO hardware_station(singleton) VALUES (true);
