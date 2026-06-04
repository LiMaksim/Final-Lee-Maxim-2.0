-- ============================================================
--  DATABASE : gamelib_db
--  SCHEMA   : gamelib
--  DOMAIN   : Video Game Library & Player Tracking System
-- ============================================================

SET search_path TO gamelib;

-- ===== PART 2: CREATE =====

-- ------------------------------------------------------------
-- 1. DROP TABLES (reverse FK order)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS gamelib.reviews    CASCADE;
DROP TABLE IF EXISTS gamelib.purchases  CASCADE;
DROP TABLE IF EXISTS gamelib.players    CASCADE;
DROP TABLE IF EXISTS gamelib.games      CASCADE;
DROP TABLE IF EXISTS gamelib.developers CASCADE;
DROP TABLE IF EXISTS gamelib.genres     CASCADE;


-- ------------------------------------------------------------
-- 2. CREATE TABLES
-- ------------------------------------------------------------

-- GENRES
CREATE TABLE gamelib.genres (
    genre_id    SERIAL        PRIMARY KEY,
    name        VARCHAR(60)   NOT NULL UNIQUE,
    description VARCHAR(300)
);

-- DEVELOPERS
CREATE TABLE gamelib.developers (
    developer_id  SERIAL        PRIMARY KEY,
    studio_name   VARCHAR(120)  NOT NULL UNIQUE,
    country       VARCHAR(80)   NOT NULL,
    founded_year  INT,
    website       VARCHAR(200),
    CONSTRAINT chk_founded_year CHECK (founded_year >= 1970)
);

-- GAMES
CREATE TABLE gamelib.games (
    game_id       SERIAL          PRIMARY KEY,
    title         VARCHAR(200)    NOT NULL,
    developer_id  INT             NOT NULL,
    genre_id      INT             NOT NULL,
    release_date  DATE            NOT NULL,
    platform      VARCHAR(60)     NOT NULL,
    base_price    NUMERIC(8,2)    NOT NULL,
    discount_pct  NUMERIC(5,2)    NOT NULL DEFAULT 0,
    final_price   NUMERIC(8,2)    GENERATED ALWAYS AS
                      (ROUND(base_price * (1 - discount_pct / 100), 2)) STORED,
    rating        VARCHAR(10)     NOT NULL DEFAULT 'E',
    is_active     BOOLEAN         NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_games_developer FOREIGN KEY (developer_id)
        REFERENCES gamelib.developers (developer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_games_genre FOREIGN KEY (genre_id)
        REFERENCES gamelib.genres (genre_id) ON DELETE RESTRICT,
    CONSTRAINT chk_release_date   CHECK (release_date > DATE '2026-01-01'),
    CONSTRAINT chk_base_price     CHECK (base_price >= 0),
    CONSTRAINT chk_discount       CHECK (discount_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_rating         CHECK (rating IN ('E','E10+','T','M','AO','RP')),
    CONSTRAINT uq_game_platform   UNIQUE (title, platform)
);

-- PLAYERS
CREATE TABLE gamelib.players (
    player_id    SERIAL        PRIMARY KEY,
    username     VARCHAR(50)   NOT NULL UNIQUE,
    email        VARCHAR(150)  NOT NULL UNIQUE,
    display_name VARCHAR(100)  NOT NULL,
    country      VARCHAR(80),
    gender       VARCHAR(20),
    joined_date  DATE          NOT NULL DEFAULT CURRENT_DATE,
    is_banned    BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_gender CHECK (gender IN ('M','F','Other','Prefer not to say'))
);

-- PURCHASES
CREATE TABLE gamelib.purchases (
    purchase_id    SERIAL         PRIMARY KEY,
    player_id      INT            NOT NULL,
    game_id        INT            NOT NULL,
    purchased_at   TIMESTAMP      NOT NULL DEFAULT NOW(),
    price_paid     NUMERIC(8,2)   NOT NULL,
    hours_played   NUMERIC(8,2)   NOT NULL DEFAULT 0,

    CONSTRAINT fk_purchases_player FOREIGN KEY (player_id)
        REFERENCES gamelib.players (player_id) ON DELETE CASCADE,
    CONSTRAINT fk_purchases_game FOREIGN KEY (game_id)
        REFERENCES gamelib.games (game_id) ON DELETE RESTRICT,
    CONSTRAINT uq_player_game UNIQUE (player_id, game_id),
    CONSTRAINT chk_hours_played CHECK (hours_played >= 0),
    CONSTRAINT chk_price_paid   CHECK (price_paid   >= 0)
);

-- REVIEWS
CREATE TABLE gamelib.reviews (
    review_id    SERIAL         PRIMARY KEY,
    player_id    INT            NOT NULL,
    game_id      INT            NOT NULL,
    score        INT            NOT NULL,
    body         TEXT,
    reviewed_at  TIMESTAMP      NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_reviews_player FOREIGN KEY (player_id)
        REFERENCES gamelib.players (player_id) ON DELETE CASCADE,
    CONSTRAINT fk_reviews_game FOREIGN KEY (game_id)
        REFERENCES gamelib.games (game_id) ON DELETE CASCADE,
    CONSTRAINT uq_review_once UNIQUE (player_id, game_id),
    CONSTRAINT chk_score CHECK (score BETWEEN 1 AND 10)
);


-- ===== PART 3: ALTER TABLE =====

ALTER TABLE gamelib.developers
    ALTER COLUMN country SET NOT NULL;

ALTER TABLE gamelib.players
    ADD COLUMN phone_number VARCHAR(15);

ALTER TABLE gamelib.players
    ALTER COLUMN phone_number TYPE VARCHAR(25);

ALTER TABLE gamelib.players
    DROP COLUMN phone_number;

ALTER TABLE gamelib.players
    ADD COLUMN bio VARCHAR(500);

ALTER TABLE gamelib.games
    ADD CONSTRAINT chk_title_nonempty CHECK (LENGTH(TRIM(title)) > 0);

ALTER TABLE gamelib.reviews
    RENAME COLUMN body TO review_text;

ALTER TABLE gamelib.reviews
    ALTER COLUMN review_text SET DEFAULT 'No comment provided.';


-- ===== PART 4: INSERT =====

-- GENRES
INSERT INTO gamelib.genres (name, description) VALUES
    ('RPG',     'Role-playing games with character progression and story-driven worlds'),
    ('FPS',     'First-person shooters focused on fast-paced gunplay'),
    ('Indie',   'Independently developed games, often with unique art styles'),
    ('Sandbox', 'Open-world games with minimal constraints on player actions'),
    ('Horror',  'Games designed to create tension, fear, and unsettling atmosphere');

-- DEVELOPERS
INSERT INTO gamelib.developers (studio_name, country, founded_year, website) VALUES
    ('Atlus',            'Japan',         1986, 'https://atlus.com'),
    ('Valve Corporation','United States', 1996, 'https://valvesoftware.com'),
    ('Omocat LLC',       'United States', 2015, 'https://omori-game.com'),
    ('Mojang Studios',   'Sweden',        2009, 'https://minecraft.net'),
    ('toby fox',         'United States', 2015, 'https://undertale.com');

-- GAMES
INSERT INTO gamelib.games (title, developer_id, genre_id, release_date, platform, base_price, discount_pct, rating) VALUES
    (
        'Persona 3 Reload',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Atlus'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'RPG'),
        DATE '2026-02-02', 'PC', 59.99, 10.00, 'M'
    ),
    (
        'Counter-Strike 2',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Valve Corporation'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'FPS'),
        DATE '2026-03-15', 'PC', 0.00, 0.00, 'M'
    ),
    (
        'OMORI',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Omocat LLC'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'Indie'),
        DATE '2026-02-20', 'PC', 19.99, 0.00, 'T'
    ),
    (
        'Team Fortress 2',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Valve Corporation'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'FPS'),
        DATE '2026-04-01', 'PC', 0.00, 0.00, 'T'
    ),
    (
        'Undertale',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'toby fox'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'Indie'),
        DATE '2026-02-10', 'PC', 9.99, 0.00, 'E10+'
    ),
    (
        'Minecraft',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Mojang Studios'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'Sandbox'),
        DATE '2026-03-05', 'PC', 26.95, 5.00, 'E10+'
    ),
    (
        'Minecraft',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Mojang Studios'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'Sandbox'),
        DATE '2026-03-05', 'Console', 29.99, 0.00, 'E10+'
    ),
    (
        'Minecraft',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Mojang Studios'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'Sandbox'),
        DATE '2026-03-05', 'Mobile', 7.99, 0.00, 'E10+'
    ),
    (
        'OMORI',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Omocat LLC'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'Horror'),
        DATE '2026-02-20', 'Switch', 19.99, 0.00, 'T'
    ),
    (
        'Persona 3 Reload',
        (SELECT developer_id FROM gamelib.developers WHERE studio_name = 'Atlus'),
        (SELECT genre_id     FROM gamelib.genres     WHERE name = 'RPG'),
        DATE '2026-02-02', 'PlayStation 5', 59.99, 0.00, 'M'
    );

-- PLAYERS
INSERT INTO gamelib.players (username, email, display_name, country, gender, bio) VALUES
    ('aigis_fan',     'aigis@example.kz',        'Aigis Fan',        'Kazakhstan',   'F',                'SEES member and Persona fan.'),
    ('yukari_archer', 'yukari@example.kz',        'Yukari Takeba',    'Japan',        'F',                'I love archery and drama!'),
    ('cs2_pro',       'cs2pro@example.kz',        'CS2 Pro Gamer',    'Russia',       'M',                'Global Elite since 2016.'),
    ('sunny_omori',   'sunny@example.kz',         'Sunny',            'Japan',        'M',                'Just a quiet kid with a violin.'),
    ('creeper_away',  'creeper@example.kz',       'CreeperSlayer99',  'Sweden',       'Prefer not to say','Minecraft is life.'),
    ('undertale_fan', 'undertale@example.kz',     'Frisk',            'United States','Other',            'Determined to see the pacifist route.'),
    ('tf2_engie',     'engie@example.kz',         'Dell Conagher',    'United States','M',                'Engineer main. Sentry up!'),
    ('persona_enjoyr','persona@example.kz',       'Persona Enjoyer',  'Kazakhstan',   'M',                'JRPG connoisseur.'),
    ('omori_hater',   'omorihater@example.kz',   'Totally Normal',    'Germany',      'F',                'Why is everyone crying?'),
    ('minebuild_kz',  'minebuild@example.kz',     'KZ Builder',       'Kazakhstan',   'M',                'Biggest creative server in KZ.'),
    ('valve_hater',   'valvehater@example.kz',   'Still Waiting',     'Canada',       'M',                'Still waiting for HL3.'),
    ('flowey_fan',    'flowey@example.kz',        'Flowey',           'Flower Bed',   'Other',            'Howdy! I am FLOWEY. FLOWEY the FLOWER!');

-- PURCHASES (free games for all players)
INSERT INTO gamelib.purchases (player_id, game_id, price_paid, hours_played)
SELECT
    p.player_id,
    g.game_id,
    g.final_price,
    ROUND((RANDOM() * 200)::NUMERIC, 2)
FROM gamelib.players p
CROSS JOIN gamelib.games g
WHERE g.base_price = 0.00
ON CONFLICT (player_id, game_id) DO NOTHING;

-- PURCHASES (paid games)
INSERT INTO gamelib.purchases (player_id, game_id, price_paid, hours_played) VALUES
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'aigis_fan'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Persona 3 Reload' AND platform = 'PC'),
        53.99, 120.50
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'yukari_archer'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Persona 3 Reload' AND platform = 'PC'),
        53.99, 98.00  -- Исправлено на правильную final_price с учетом скидки
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'sunny_omori'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'OMORI' AND platform = 'PC'),
        19.99, 45.00
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'omori_hater'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'OMORI' AND platform = 'PC'),
        19.99, 3.00
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'creeper_away'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Minecraft' AND platform = 'PC'),
        25.60, 5000.00
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'minebuild_kz'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Minecraft' AND platform = 'PC'),
        25.60, 3200.00
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'undertale_fan'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Undertale' AND platform = 'PC'),
        9.99, 30.00
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'flowey_fan'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Undertale' AND platform = 'PC'),
        9.99, 999.00
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'persona_enjoyr'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Persona 3 Reload' AND platform = 'PC'),
        53.99, 200.00
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'persona_enjoyr'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Persona 3 Reload' AND platform = 'PlayStation 5'),
        59.99, 60.00
    )
ON CONFLICT (player_id, game_id) DO NOTHING;

-- REVIEWS
INSERT INTO gamelib.reviews (player_id, game_id, score, review_text) VALUES
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'aigis_fan'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Persona 3 Reload' AND platform = 'PC'),
        10, 'Absolutely stunning remake. The new voice cast and added content make this the definitive version.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'yukari_archer'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Persona 3 Reload' AND platform = 'PC'),
        9, 'Gorgeous visuals and emotional story. Only wish Episode Aigis was included at launch.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'cs2_pro'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Counter-Strike 2' AND platform = 'PC'),
        8, 'Major upgrade from CSGO. The smoke rework alone is worth the switch.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'sunny_omori'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'OMORI' AND platform = 'PC'),
        10, 'A masterpiece that deals with grief in ways no other game has managed.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'omori_hater'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'OMORI' AND platform = 'PC'),
        5, 'Too slow for my taste but I can see why people love it.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'creeper_away'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Minecraft' AND platform = 'PC'),
        10, 'Been playing since Alpha. Still the best sandbox ever made.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'undertale_fan'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Undertale' AND platform = 'PC'),
        10, 'Toby fox made this alone. The music, story, and characters are all unforgettable.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'flowey_fan'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Undertale' AND platform = 'PC'),
        10, 'In this world, it is kill or be killed. 10/10.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'tf2_engie'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Team Fortress 2' AND platform = 'PC'),
        9, 'Timeless class-based shooter. Bots are a problem but the community keeps it alive.'
    ),
    (
        (SELECT player_id FROM gamelib.players WHERE username = 'valve_hater'),
        (SELECT game_id   FROM gamelib.games   WHERE title = 'Counter-Strike 2' AND platform = 'PC'),
        6, 'Good game, still waiting for the promised features. Classic Valve.'
    );


-- ===== PART 5: UPDATE + DELETE =====

UPDATE gamelib.games
SET    discount_pct = 10
WHERE  genre_id = (SELECT genre_id FROM gamelib.genres WHERE name = 'RPG')
  AND  discount_pct = 0;

UPDATE gamelib.purchases
SET    hours_played = ROUND(hours_played * 1.10, 2)
FROM   gamelib.games g
WHERE  gamelib.purchases.game_id = g.game_id
  AND  g.base_price = 0.00;

UPDATE gamelib.players
SET    is_banned = FALSE
WHERE  username = 'valve_hater';

BEGIN;

DELETE FROM gamelib.players
WHERE player_id NOT IN (
    SELECT DISTINCT player_id FROM gamelib.purchases
)
RETURNING player_id, username, email;

ROLLBACK;


-- ===== PART 6: GRANT + REVOKE =====

-- ===== PART 6: GRANT + REVOKE =====

-- 1. Сначала отзываем все права и удаляем зависимости ролей в текущей базе данных
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'gamelib_readonly') THEN
        EXECUTE 'DROP OWNED BY gamelib_readonly;';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'gamelib_writer') THEN
        EXECUTE 'DROP OWNED BY gamelib_writer;';
    END IF;
END $$;

-- 2. Теперь спокойно удаляем их без ошибок о зависимостях
DROP ROLE IF EXISTS gamelib_readonly;
DROP ROLE IF EXISTS gamelib_writer;

-- 3. Создаем заново
CREATE ROLE gamelib_readonly;
CREATE ROLE gamelib_writer;

-- 4. Раздаем права
GRANT SELECT ON ALL TABLES IN SCHEMA gamelib TO gamelib_readonly;

GRANT INSERT, UPDATE ON gamelib.purchases TO gamelib_writer;
GRANT INSERT, UPDATE ON gamelib.reviews   TO gamelib_writer;
GRANT INSERT         ON gamelib.players   TO gamelib_writer;

REVOKE UPDATE ON gamelib.players FROM gamelib_writer;