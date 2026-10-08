-- Public code of the cage: the "cageId" of the contracts (events, URLs, WebSocket topics).
-- V1 can't be edited, so the column is added nullable, filled, and only then made NOT NULL + UNIQUE.
ALTER TABLE cage ADD COLUMN code VARCHAR(50);

-- the pilot cage (id 1, created in V1) becomes 'cage-1'
UPDATE cage SET code = 'cage-' || id;

ALTER TABLE cage ALTER COLUMN code SET NOT NULL;
ALTER TABLE cage ADD CONSTRAINT uq_cage_code UNIQUE (code);
