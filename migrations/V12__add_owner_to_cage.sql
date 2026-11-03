-- A farmer can have several cages and only sees their own. Each cage gets an owner (the account that created it)
-- and a soft delete flag, like guinea_pig: a removed cage keeps its events, alerts and history.

ALTER TABLE cage ADD COLUMN owner_id UUID;
ALTER TABLE cage ADD COLUMN active BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE cage ADD CONSTRAINT fk_cage_owner FOREIGN KEY (owner_id) REFERENCES app_user (id);

-- "my cages": the dashboard lists the active cages of the signed-in account
CREATE INDEX ix_cage_owner ON cage (owner_id) WHERE active;

-- The pilot cage existed before there were owners: it goes to the oldest active account, so the person already
-- using it keeps seeing it. With no accounts yet (a fresh database) it stays without owner and nobody sees it.
UPDATE cage
SET owner_id = (SELECT id FROM app_user WHERE status = 'ACTIVE' ORDER BY created_at LIMIT 1)
WHERE code = 'cage-1' AND owner_id IS NULL;
