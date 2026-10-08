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
