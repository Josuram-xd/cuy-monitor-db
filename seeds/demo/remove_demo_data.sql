-- Undoes seeds/demo/demo_data.sql: back to a database with only real data.
--   psql ... -f seeds/demo/remove_demo_data.sql
-- The demo cuyes are the ones whose notes start with '[demo]'. Scale readings have no marker, so the
-- ones of the last day of the pilot cage go too (the cage has no real scale sending data yet).

BEGIN;

DELETE FROM alert WHERE guinea_pig_id IN (SELECT id FROM guinea_pig WHERE notes LIKE '[demo]%');
DELETE FROM alert WHERE message IN (
    'Se escucharon chillidos de angustia en la jaula',
    'El peso de la jaula bajó casi 270 g en la última hora',
    'Ruido fuerte y repentino cerca de la jaula');
DELETE FROM event WHERE source = 'demo-seed';
DELETE FROM state_transition WHERE guinea_pig_id IN (SELECT id FROM guinea_pig WHERE notes LIKE '[demo]%');
DELETE FROM baseline_profile WHERE guinea_pig_id IN (SELECT id FROM guinea_pig WHERE notes LIKE '[demo]%');
DELETE FROM weight_reading
 WHERE cage_id = (SELECT id FROM cage WHERE code = 'cage-1') AND measured_at > now() - interval '1 day';
DELETE FROM guinea_pig WHERE notes LIKE '[demo]%';

COMMIT;
