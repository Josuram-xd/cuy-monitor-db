-- Development data only. This location is never copied into the migrate image, so it can't reach RDS.
-- Repeatable migration: Flyway runs it again whenever this file changes, so every insert must be idempotent.

-- One guinea pig per mark color in the pilot cage. A cuy is identified by its photo, so each one gets a
-- 64x64 PNG of its own mark color: enough for the dashboard to show something real without carrying
-- pictures of animals in the repo.
INSERT INTO guinea_pig (cage_id, mark_color, photo, photo_content_type)
SELECT c.id, g.mark_color, decode(g.photo, 'base64'), 'image/png'
FROM cage c
CROSS JOIN (VALUES
    ('RED',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAT0lEQVR42u3PQQkAAAgEsItz/cOYxwi+hcEKLNO+FgEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQGBK7AL32EPoqXGuwAAAABJRU5ErkJggg=='),
    ('BLUE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsEtiOTubxwi+hcEKLNXzWgQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQErsAC/wBxPM8TsEEAAAAASUVORK5CYII='),
    ('GREEN',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsEtkCnOa1Qi+hcEKLDX9WgQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQErsAC2WoBAJ/efOIAAAAASUVORK5CYII='),
    ('YELLOW',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsIth/y5G8m8E38JgBZbpei0CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICApcFLxUhtByKRpcAAAAASUVORK5CYII='),
    ('ORANGE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAATklEQVR42u3PMQ0AAAgDsDlHNu8kcJM0qYFmJ69FQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQOAKFK3kYVoRAP85AAAAAElFTkSuQmCC'),
    ('PURPLE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsGtmMHPZzwi+hcEKLF3zWgQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQErsAC/mbxSyPAZz4AAAAASUVORK5CYII='),
    ('BLACK',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAATElEQVR42u3PMQ0AAAwDoOqof6GVsHsJOCB9LgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICV2AUzeA9WjNPSAAAAABJRU5ErkJggg=='),
    ('WHITE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAS0lEQVR42u3PMQ0AAAwDoPo33UrYvQQckD4XAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAYErMMpT0sKrUBQAAAAAAElFTkSuQmCC')
) AS g (mark_color, photo)
WHERE c.code = 'cage-1'
ON CONFLICT (cage_id, mark_color) WHERE active DO NOTHING;

-- Gives a photo to the cuyes seeded before the photo existed, so an old local database does not need a wipe
UPDATE guinea_pig g
SET photo = decode(v.photo, 'base64'), photo_content_type = 'image/png'
FROM (VALUES
    ('RED',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAT0lEQVR42u3PQQkAAAgEsItz/cOYxwi+hcEKLNO+FgEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQGBK7AL32EPoqXGuwAAAABJRU5ErkJggg=='),
    ('BLUE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsEtiOTubxwi+hcEKLNXzWgQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQErsAC/wBxPM8TsEEAAAAASUVORK5CYII='),
    ('GREEN',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsEtkCnOa1Qi+hcEKLDX9WgQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQErsAC2WoBAJ/efOIAAAAASUVORK5CYII='),
    ('YELLOW',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsIth/y5G8m8E38JgBZbpei0CAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICApcFLxUhtByKRpcAAAAASUVORK5CYII='),
    ('ORANGE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAATklEQVR42u3PMQ0AAAgDsDlHNu8kcJM0qYFmJ69FQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQOAKFK3kYVoRAP85AAAAAElFTkSuQmCC'),
    ('PURPLE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAUElEQVR42u3PQQkAAAgEsGtmMHPZzwi+hcEKLF3zWgQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQErsAC/mbxSyPAZz4AAAAASUVORK5CYII='),
    ('BLACK',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAATElEQVR42u3PMQ0AAAwDoOqof6GVsHsJOCB9LgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICV2AUzeA9WjNPSAAAAABJRU5ErkJggg=='),
    ('WHITE',
     'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAS0lEQVR42u3PMQ0AAAwDoPo33UrYvQQckD4XAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAYErMMpT0sKrUBQAAAAAAElFTkSuQmCC')
) AS v (mark_color, photo)
WHERE g.photo IS NULL AND g.mark_color = v.mark_color
  AND g.cage_id = (SELECT id FROM cage WHERE code = 'cage-1');

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

-- The dev account owns the pilot cage and a second one, so the dashboard shows the list of cages
UPDATE cage SET owner_id = '00000000-0000-4000-8000-000000000001'
WHERE code = 'cage-1' AND owner_id IS NULL;

INSERT INTO cage (code, name, location, owner_id)
VALUES ('cage-dev-2', 'Jaula del patio', 'Patio trasero', '00000000-0000-4000-8000-000000000001')
ON CONFLICT ON CONSTRAINT uq_cage_code DO NOTHING;

-- two cuyes there, identified by the same sample photo of their mark color as in the pilot cage
INSERT INTO guinea_pig (cage_id, mark_color, photo, photo_content_type)
SELECT c.id, sample.mark_color, sample.photo, sample.photo_content_type
FROM cage c
JOIN guinea_pig sample
  ON sample.cage_id = (SELECT id FROM cage WHERE code = 'cage-1') AND sample.active
 AND sample.mark_color IN ('WHITE', 'PURPLE')
WHERE c.code = 'cage-dev-2'
ON CONFLICT (cage_id, mark_color) WHERE active DO NOTHING;

-- 30 days of reviewed alerts in the pilot cage, so the alert history has pages to show: behavior alerts of
-- four cuyes, distress clips and weight drops, one every 19 hours or so, some of them critical.
-- Only when the cage has no alert older than two days, so running it again adds nothing.
INSERT INTO alert (cage_id, guinea_pig_id, level, type, message, status, created_at, reviewed_at)
SELECT c.id,
       CASE WHEN h.type = 'BEHAVIOR' THEN g.id END,
       h.level, h.type, h.message, 'REVIEWED', h.created_at,
       h.created_at + interval '25 minutes' + (h.n % 4) * interval '20 minutes'
FROM cage c
CROSS JOIN LATERAL (
    SELECT n,
           CASE n % 6 WHEN 0 THEN 'AUDIO' WHEN 3 THEN 'WEIGHT' ELSE 'BEHAVIOR' END AS type,
           CASE WHEN n % 5 = 0 THEN 'CRITICAL' ELSE 'ALERT' END AS level,
           (ARRAY['RED', 'BLUE', 'GREEN', 'YELLOW'])[n % 4 + 1] AS mark_color,
           CASE n % 6
               WHEN 0 THEN 'Se escucharon chillidos de angustia en la jaula'
               WHEN 3 THEN 'El peso de la jaula bajó más de lo esperado'
               WHEN 1 THEN 'Estuvo quieto mucho más de lo normal y no fue al comedero'
               WHEN 2 THEN 'Se alejó del grupo durante mucho tiempo'
               ELSE 'Su comportamiento fue anómalo varios minutos seguidos'
           END AS message,
           now() - n * interval '19 hours' - (n % 7) * interval '13 minutes' AS created_at
    FROM generate_series(3, 37) AS n
) AS h
LEFT JOIN guinea_pig g ON g.cage_id = c.id AND g.active AND g.mark_color = h.mark_color
WHERE c.code = 'cage-1'
  AND (h.type <> 'BEHAVIOR' OR g.id IS NOT NULL)
  AND NOT EXISTS (SELECT 1 FROM alert a WHERE a.cage_id = c.id AND a.created_at < now() - interval '2 days');
