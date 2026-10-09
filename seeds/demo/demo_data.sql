-- DEMONSTRATION DATA. Run by hand, never part of the migrations or the dev seed:
--   psql ... -f seeds/demo/demo_data.sql
-- It gives the dashboard something to show (cuyes, alerts, history) when no camera or scale is sending events.
-- Safe to run more than once. Remove everything with seeds/demo/remove_demo_data.sql.
--
-- How its rows are told apart from real ones:
--   guinea_pig  notes start with '[demo]'
--   event       source = 'demo-seed'
--   alert       the cage-level ones by their exact message; the cuy ones by their guinea pig
-- Mark colors GREEN, BLUE, WHITE and ORANGE; a color already worn by another cuy is skipped, not overwritten.

-- 1. Four cuyes, with their profile and current status ---------------------------------------------------
INSERT INTO guinea_pig (cage_id, name, mark_color, current_status, status_since, breed, coat_color,
                        initial_weight_grams, notes, created_at)
SELECT c.id, v.name, v.mark_color, v.status, now() - v.since, v.breed, v.coat, v.grams, v.notes,
       now() - interval '3 days'
FROM cage c
CROSS JOIN (VALUES
    ('Canela', 'GREEN',  'OBSERVED', interval '22 minutes', 'TEDDY',      'CINNAMON', 860, '[demo] La más curiosa de la jaula.'),
    ('Pelusa', 'BLUE',   'NORMAL',   interval '10 hours',   'PERUVIAN',   'CREAM',    940, '[demo] Le encanta el pasto fresco.'),
    ('Copito', 'WHITE',  'NORMAL',   interval '24 hours',   'AMERICAN',   'WHITE',    780, '[demo] Tranquilo, duerme mucho.'),
    ('Chispa', 'ORANGE', 'ALERT',    interval '35 minutes', 'ABYSSINIAN', 'BICOLOR',  820, '[demo] Muy activa, suele ser la primera en el comedero.')
) AS v (name, mark_color, status, since, breed, coat, grams, notes)
WHERE c.code = 'cage-1'
ON CONFLICT ON CONSTRAINT uq_guinea_pig_cage_color DO NOTHING;

-- 2. What is normal for each one (the baseline the health rules compare against) ----------------------------
INSERT INTO baseline_profile (guinea_pig_id, avg_still_seconds, avg_feeder_visits, avg_group_distance, updated_at)
SELECT g.id, v.still, v.feeder, v.distance, now() - interval '1 hour'
FROM guinea_pig g
JOIN (VALUES ('Canela', 14.0, 2.1, 0.22), ('Pelusa', 18.0, 1.6, 0.27),
             ('Copito', 26.0, 1.2, 0.31), ('Chispa', 9.0, 2.8, 0.18)) AS v (name, still, feeder, distance)
  ON v.name = g.name
WHERE g.notes LIKE '[demo]%'
ON CONFLICT ON CONSTRAINT pk_baseline_profile DO NOTHING;

-- 3. Behavior windows: one per minute for the last 20 minutes, per cuy --------------------------------------
-- Canela and Chispa drift away from their normal; Pelusa and Copito stay close to it.
INSERT INTO event (id, type, cage_id, guinea_pig_id, source, occurred_at, payload)
SELECT md5('demo-behavior-' || g.id || '-' || i)::uuid, 'BEHAVIOR', g.cage_id, g.id, 'demo-seed',
       now() - make_interval(mins => i),
       jsonb_build_object(
           'color', g.mark_color,
           'windowSeconds', 60,
           'stillSeconds', CASE g.name WHEN 'Chispa' THEN 50 + (i * 3) % 9
                                       WHEN 'Canela' THEN 32 + (i * 5) % 9
                                       WHEN 'Copito' THEN 24 + (i * 7) % 8
                                       ELSE 16 + (i * 4) % 7 END,
           'feederVisits', CASE g.name WHEN 'Chispa' THEN 0
                                       WHEN 'Canela' THEN (i % 3) / 2
                                       ELSE 1 + i % 2 END,
           'watererVisits', i % 2,
           'avgGroupDistance', round((CASE g.name WHEN 'Chispa' THEN 0.55 WHEN 'Canela' THEN 0.40 ELSE 0.25 END
                                      + (i % 4) * 0.01)::numeric, 2),
           'probAnomaly', round((CASE g.name WHEN 'Chispa' THEN 0.86 WHEN 'Canela' THEN 0.58 ELSE 0.07 END
                                 + (i % 5) * 0.01)::numeric, 2),
           'detectionConfidence', round((0.90 + (i % 6) * 0.01)::numeric, 2))
FROM guinea_pig g
CROSS JOIN generate_series(1, 20) AS i
WHERE g.notes LIKE '[demo]%'
ON CONFLICT ON CONSTRAINT pk_event DO NOTHING;

-- 4. A distress clip of the cage ---------------------------------------------------------------------------
INSERT INTO event (id, type, cage_id, guinea_pig_id, source, occurred_at, payload)
SELECT md5('demo-audio-1')::uuid, 'AUDIO', c.id, NULL, 'demo-seed', now() - interval '30 minutes',
       '{"label":"DISTRESS","probability":0.91,"durationMs":960}'::jsonb
FROM cage c WHERE c.code = 'cage-1'
ON CONFLICT ON CONSTRAINT pk_event DO NOTHING;

-- 5. Scale readings of the last two hours, every 10 minutes: the cage lost weight in the last hour ---------
INSERT INTO weight_reading (cage_id, grams, stable, measured_at)
SELECT c.id, r.grams, true, now() - r.ago
FROM cage c
CROSS JOIN (VALUES
    (6852.0, interval '120 minutes'), (6848.5, interval '110 minutes'), (6850.0, interval '100 minutes'),
    (6846.0, interval '90 minutes'),  (6849.5, interval '80 minutes'),  (6847.0, interval '70 minutes'),
    (6845.0, interval '60 minutes'),  (6790.5, interval '50 minutes'),  (6728.0, interval '40 minutes'),
    (6671.5, interval '30 minutes'),  (6615.0, interval '20 minutes'),  (6578.5, interval '10 minutes')
) AS r (grams, ago)
WHERE c.code = 'cage-1'
  AND NOT EXISTS (SELECT 1 FROM weight_reading w WHERE w.cage_id = c.id AND w.measured_at > now() - interval '3 hours');

INSERT INTO event (id, type, cage_id, guinea_pig_id, source, occurred_at, payload)
SELECT md5('demo-weight-' || r.n)::uuid, 'WEIGHT', c.id, NULL, 'demo-seed', now() - r.ago,
       jsonb_build_object('grams', r.grams, 'stable', true)
FROM cage c
CROSS JOIN (VALUES (1, 6671.5, interval '30 minutes'), (2, 6615.0, interval '20 minutes'),
                   (3, 6578.5, interval '10 minutes')) AS r (n, grams, ago)
WHERE c.code = 'cage-1'
ON CONFLICT ON CONSTRAINT pk_event DO NOTHING;

-- 6. How each cuy got to its status ------------------------------------------------------------------------
INSERT INTO state_transition (guinea_pig_id, from_status, to_status, reason, occurred_at)
SELECT g.id, v.from_status, v.to_status, v.reason, now() - v.ago
FROM guinea_pig g
JOIN (VALUES
    ('Canela', 'NORMAL',   'OBSERVED', 'Menos visitas al comedero que su promedio',     interval '22 minutes'),
    ('Chispa', 'NORMAL',   'OBSERVED', 'Pasa más tiempo quieta que su promedio',        interval '70 minutes'),
    ('Chispa', 'OBSERVED', 'ALERT',    'Lleva mucho más tiempo quieta de lo normal',    interval '35 minutes'),
    ('Copito', 'OBSERVED', 'NORMAL',   'Volvió a su comportamiento habitual',           interval '26 hours'),
    ('Pelusa', 'ALERT',    'OBSERVED', 'Mejoró: ya se mueve y come',                    interval '11 hours'),
    ('Pelusa', 'OBSERVED', 'NORMAL',   'Volvió a su comportamiento habitual',           interval '10 hours')
) AS v (name, from_status, to_status, reason, ago) ON v.name = g.name
WHERE g.notes LIKE '[demo]%'
  AND NOT EXISTS (SELECT 1 FROM state_transition t
                  WHERE t.guinea_pig_id = g.id AND t.to_status = v.to_status AND t.reason = v.reason);

-- 7. Alerts: three open, two already reviewed ----------------------------------------------------------------
INSERT INTO alert (cage_id, guinea_pig_id, level, type, message, status, created_at, reviewed_at)
SELECT c.id, g.id, v.level, v.type, v.message, v.status, now() - v.ago,
       CASE v.status WHEN 'REVIEWED' THEN now() - v.ago + interval '40 minutes' END
FROM cage c
JOIN (VALUES
    ('Chispa', 'ALERT', 'BEHAVIOR', 'Chispa lleva mucho más tiempo quieta de lo normal',    'OPEN',     interval '35 minutes'),
    ('Canela', 'ALERT', 'BEHAVIOR', 'Canela casi no ha ido al comedero en la última hora',   'REVIEWED', interval '3 hours'),
    (NULL,     'ALERT', 'AUDIO',    'Se escucharon chillidos de angustia en la jaula',        'OPEN',     interval '30 minutes'),
    (NULL,     'ALERT', 'WEIGHT',   'El peso de la jaula bajó casi 270 g en la última hora',  'OPEN',     interval '12 minutes'),
    (NULL,     'ALERT', 'AUDIO',    'Ruido fuerte y repentino cerca de la jaula',             'REVIEWED', interval '1 day')
) AS v (pig, level, type, message, status, ago) ON true
LEFT JOIN guinea_pig g ON g.cage_id = c.id AND g.name = v.pig AND g.notes LIKE '[demo]%'
WHERE c.code = 'cage-1'
  AND (v.pig IS NULL OR g.id IS NOT NULL)
  AND NOT EXISTS (SELECT 1 FROM alert a WHERE a.cage_id = c.id AND a.message = v.message);
