-- Demo data for the public demo account behind "Iniciar sesión como usuario normal".
-- NOT a migration and NOT a dev seed: it is run by hand, once, against the database where the demo lives:
--
--   psql "<connection>" -v username=testuser -f seeds/demo/demo_account.sql
--
-- It gives that account 30 cages with 5 guinea pigs each, a week of scale readings, the last day of behavior
-- windows, and a few guinea pigs under observation or alert (with the alert and what the assistant would write).
-- The behavior windows are stored with source 'demo-seed', so the admin's AI log never passes them off as real
-- AI work. It stops without touching anything if the account is missing, is an admin, or already has cages.

\set ON_ERROR_STOP on
BEGIN;

SELECT set_config('demo.username', :'username', true);

DO $$
DECLARE
    v_owner        uuid;
    names        text[] := ARRAY['Canela', 'Copito', 'Pelusa', 'Chocolate', 'Nube', 'Manchas', 'Galleta', 'Trufa',
                                 'Bombón', 'Oreo', 'Miel', 'Coco', 'Pimienta', 'Tofi', 'Luna', 'Rocky', 'Pancho',
                                 'Kiwi', 'Maní', 'Chispa', 'Lucas', 'Frida', 'Tango', 'Nieve', 'Paco'];
    marks        text[] := ARRAY['RED', 'BLUE', 'GREEN', 'YELLOW', 'ORANGE', 'PURPLE', 'BLACK', 'WHITE'];
    breeds       text[] := ARRAY['AMERICAN', 'PERUVIAN', 'ABYSSINIAN', 'TEDDY', 'SILKIE', 'CRESTED'];
    coats        text[] := ARRAY['WHITE', 'BLACK', 'BROWN', 'CREAM', 'GRAY', 'CINNAMON', 'BICOLOR', 'TRICOLOR'];
    v_cage      bigint;
    v_pig       bigint;
    v_status       text;
    v_since        timestamptz;
    v_sick         boolean;
    v_reason       text := 'estuvo quieto mucho más de lo normal y no fue al comedero';
    hour         int;
BEGIN
    SELECT id INTO v_owner FROM app_user
     WHERE username = current_setting('demo.username') AND status = 'ACTIVE' AND role = 'BREEDER';
    IF v_owner IS NULL THEN
        RAISE EXCEPTION 'no active breeder called %', current_setting('demo.username');
    END IF;
    IF EXISTS (SELECT 1 FROM cage WHERE owner_id = v_owner) THEN
        RAISE EXCEPTION 'the account already has cages: nothing done';
    END IF;

    FOR c IN 1..30 LOOP
        INSERT INTO cage (code, name, location, owner_id, created_at)
        VALUES ('cage-' || substr(md5('demo-cage-' || c || v_owner::text), 1, 8),
                'Galpón ' || chr(64 + (c - 1) / 10 + 1) || ' · Jaula ' || lpad(c::text, 2, '0'),
                'Galpón ' || chr(64 + (c - 1) / 10 + 1) || ', fila ' || ((c - 1) % 10) / 5 + 1,
                v_owner, now() - interval '21 days')
        RETURNING id INTO v_cage;

        -- the scale: a reading every 30 min for a week; it slowly drops in the cages with someone not eating
        INSERT INTO weight_reading (cage_id, grams, stable, measured_at)
        SELECT v_cage,
               round((4300 + 40 * sin(n / 48.0 * 2 * pi()) + (random() - 0.5) * 30
                      - CASE WHEN c % 5 = 0 THEN n * 0.4 ELSE 0 END)::numeric, 1),
               random() > 0.15,
               now() - (336 - n) * interval '30 minutes'
          FROM generate_series(0, 335) AS n;

        FOR p IN 1..5 LOOP
            -- every 5th cage has a guinea pig in alert, every 3rd one under observation, cage 7 a critical one
            v_status := 'NORMAL';
            IF p = 1 AND c = 7 THEN v_status := 'CRITICAL';
            ELSIF p = 1 AND c % 5 = 0 THEN v_status := 'ALERT';
            ELSIF p = 2 AND c % 3 = 0 THEN v_status := 'OBSERVED';
            END IF;
            v_sick := v_status <> 'NORMAL';
            v_since := CASE v_status WHEN 'NORMAL' THEN now() - interval '20 days'
                                 WHEN 'OBSERVED' THEN now() - interval '25 minutes'
                                 ELSE now() - interval '2 hours' END;

            INSERT INTO guinea_pig (cage_id, name, mark_color, current_status, status_since, breed, coat_color,
                                    initial_weight_grams, created_at)
            VALUES (v_cage, names[1 + (c * 5 + p) % array_length(names, 1)], marks[1 + (c + p) % 8], v_status,
                    v_since, breeds[1 + (c + p * 2) % 6], coats[1 + (c * 3 + p) % 8], 650 + ((c * 37 + p * 53) % 450),
                    now() - interval '20 days')
            RETURNING id INTO v_pig;

            -- the last 24 hours of behavior windows, one per hour; a sick one stays still and skips the feeder
            FOR hour IN 0..23 LOOP
                INSERT INTO event (id, type, cage_id, guinea_pig_id, source, occurred_at, received_at, payload)
                VALUES (gen_random_uuid(), 'BEHAVIOR', v_cage, v_pig, 'demo-seed',
                        now() - (24 - hour) * interval '1 hour', now() - (24 - hour) * interval '1 hour',
                        jsonb_build_object(
                            'color', marks[1 + (c + p) % 8], 'windowSeconds', 60,
                            'stillSeconds', CASE WHEN v_sick AND hour >= 20 THEN 50 + random() * 9
                                                 ELSE 10 + random() * 20 END,
                            'feederVisits', CASE WHEN v_sick AND hour >= 20 THEN 0 ELSE 1 + (random() * 2)::int END,
                            'watererVisits', CASE WHEN v_sick AND hour >= 20 THEN 0 ELSE (random() * 2)::int END,
                            'avgGroupDistance', CASE WHEN v_sick AND hour >= 20 THEN 0.7 + random() * 0.2
                                                     ELSE 0.2 + random() * 0.2 END,
                            'probAnomaly', CASE WHEN v_sick AND hour >= 20 THEN 0.6 + random() * 0.3
                                                ELSE random() * 0.15 END,
                            'detectionConfidence', 0.85 + random() * 0.1));
            END LOOP;

            IF v_sick THEN
                INSERT INTO state_transition (guinea_pig_id, from_status, to_status, reason, occurred_at)
                VALUES (v_pig, 'NORMAL', 'OBSERVED', v_reason, now() - interval '3 hours');
            END IF;
            IF v_status IN ('ALERT', 'CRITICAL') THEN
                INSERT INTO state_transition (guinea_pig_id, from_status, to_status, reason, occurred_at)
                VALUES (v_pig, 'OBSERVED', 'ALERT', v_reason, now() - interval '2 hours' - interval '30 minutes');
                INSERT INTO alert (cage_id, guinea_pig_id, level, type, message, created_at, ai_note, ai_note_at)
                VALUES (v_cage, v_pig, 'ALERT', 'BEHAVIOR', 'Comportamiento fuera de lo normal de forma sostenida',
                        now() - interval '2 hours' - interval '30 minutes',
                        'Lleva más de media hora casi sin moverse y no ha ido al comedero. Revisa si respira bien y '
                        || 'come; sepáralo del grupo si lo ves decaído y, si sigue igual, llama al veterinario.',
                        now() - interval '2 hours' - interval '29 minutes');
            END IF;
            IF v_status = 'CRITICAL' THEN
                INSERT INTO state_transition (guinea_pig_id, from_status, to_status, reason, occurred_at)
                VALUES (v_pig, 'ALERT', 'CRITICAL', v_reason, now() - interval '1 hour');
                INSERT INTO alert (cage_id, guinea_pig_id, level, type, message, created_at, ai_note, ai_note_at)
                VALUES (v_cage, v_pig, 'CRITICAL', 'BEHAVIOR', 'El comportamiento fuera de lo normal empeoró y sigue',
                        now() - interval '1 hour',
                        'Ya va más de una hora así y empeora: llama al veterinario ahora y, mientras tanto, déjalo '
                        || 'aparte, abrigado y con agua a su alcance.',
                        now() - interval '59 minutes');
            END IF;
        END LOOP;
    END LOOP;

    RAISE NOTICE 'demo data ready for %: % cages, % guinea pigs', current_setting('demo.username'),
        (SELECT count(*) FROM cage WHERE owner_id = v_owner),
        (SELECT count(*) FROM guinea_pig g JOIN cage x ON x.id = g.cage_id WHERE x.owner_id = v_owner);
END $$;

COMMIT;
