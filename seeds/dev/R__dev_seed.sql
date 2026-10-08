-- Development data only. This location is never copied into the migrate image, so it can't reach RDS.
-- Repeatable migration: Flyway runs it again whenever this file changes, so every insert must be idempotent.

-- One guinea pig per mark color in the pilot cage
INSERT INTO guinea_pig (cage_id, name, mark_color)
SELECT c.id, g.name, g.mark_color
FROM cage c
CROSS JOIN (VALUES
    ('Canela', 'RED'),
    ('Azulito', 'BLUE'),
    ('Menta', 'GREEN'),
    ('Mostaza', 'YELLOW'),
    ('Naranjo', 'ORANGE'),
    ('Lila', 'PURPLE'),
    ('Carbón', 'BLACK'),
    ('Nieve', 'WHITE')
) AS g (name, mark_color)
WHERE c.code = 'cage-1'
ON CONFLICT ON CONSTRAINT uq_guinea_pig_cage_color DO NOTHING;

-- Test account dev / dev-password, already ACTIVE so it can log in right away (the OTP still goes to the log
-- with the backend's dev profile). The hash was made with the backend's BCryptPasswordHasher. Never a real user.
INSERT INTO app_user (id, username, full_name, email, password_hash, status, created_at, updated_at)
VALUES ('00000000-0000-4000-8000-000000000001', 'dev', 'Usuario de desarrollo', 'dev@cuymonitor.local',
        '$2a$10$qxRC/o1O50HchjqVUfIJW.GwuwiPf0QsZ9RMwT.4RXX.U08WWhEuu', 'ACTIVE', now(), now())
ON CONFLICT ON CONSTRAINT uq_app_user_username DO NOTHING;

-- Sample data so the dashboard has something to show without the fake producer.
-- Fixed ids (events) or NOT EXISTS checks (readings, alerts) keep it idempotent.

-- Three normal behavior windows of Canela, one minute apart
INSERT INTO event (id, type, cage_id, guinea_pig_id, source, occurred_at, payload)
SELECT w.id::uuid, 'BEHAVIOR', g.cage_id, g.id, 'ai-service', now() - w.ago, w.payload::jsonb
FROM guinea_pig g
CROSS JOIN (VALUES
    ('d0000000-0000-4000-8000-000000000001', interval '3 minutes',
     '{"color":"RED","windowSeconds":60,"stillSeconds":12,"feederVisits":2,"watererVisits":1,"avgGroupDistance":0.21,"probAnomaly":0.08,"detectionConfidence":0.94}'),
    ('d0000000-0000-4000-8000-000000000002', interval '2 minutes',
     '{"color":"RED","windowSeconds":60,"stillSeconds":15,"feederVisits":1,"watererVisits":0,"avgGroupDistance":0.25,"probAnomaly":0.11,"detectionConfidence":0.92}'),
    ('d0000000-0000-4000-8000-000000000003', interval '1 minute',
     '{"color":"RED","windowSeconds":60,"stillSeconds":9,"feederVisits":2,"watererVisits":1,"avgGroupDistance":0.19,"probAnomaly":0.05,"detectionConfidence":0.95}')
) AS w (id, ago, payload)
WHERE g.mark_color = 'RED' AND g.cage_id = (SELECT id FROM cage WHERE code = 'cage-1')
ON CONFLICT ON CONSTRAINT pk_event DO NOTHING;

-- A distress clip of the cage and the open alert it produced
INSERT INTO event (id, type, cage_id, guinea_pig_id, source, occurred_at, payload)
SELECT 'd0000000-0000-4000-8000-000000000010', 'AUDIO', id, NULL, 'ai-service', now() - interval '30 minutes',
       '{"label":"DISTRESS","probability":0.91,"durationMs":960}'
FROM cage WHERE code = 'cage-1'
ON CONFLICT ON CONSTRAINT pk_event DO NOTHING;

INSERT INTO alert (cage_id, guinea_pig_id, level, type, message, status, created_at)
SELECT id, NULL, 'ALERT', 'AUDIO', 'Se escucharon chillidos de angustia en la jaula', 'OPEN', now() - interval '30 minutes'
FROM cage c
WHERE c.code = 'cage-1'
  AND NOT EXISTS (SELECT 1 FROM alert a WHERE a.cage_id = c.id AND a.type = 'AUDIO');

-- Stable scale readings of the last hour, every 10 minutes
INSERT INTO weight_reading (cage_id, grams, stable, measured_at)
SELECT c.id, r.grams, true, now() - r.ago
FROM cage c
CROSS JOIN (VALUES
    (6850.0, interval '60 minutes'), (6842.5, interval '50 minutes'), (6838.0, interval '40 minutes'),
    (6845.5, interval '30 minutes'), (6840.0, interval '20 minutes'), (6836.5, interval '10 minutes')
) AS r (grams, ago)
WHERE c.code = 'cage-1'
  AND NOT EXISTS (SELECT 1 FROM weight_reading w WHERE w.cage_id = c.id);
