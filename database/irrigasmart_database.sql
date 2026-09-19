-- ============================================================
-- IRRIGASMART - BANCO DE DADOS
-- ============================================================

-- ============================================================
-- 1. LIMPEZA
-- ============================================================

DROP VIEW IF EXISTS dashboard_summary;
DROP VIEW IF EXISTS daily_consumption;

DROP TABLE IF EXISTS sensor_readings CASCADE;
DROP TABLE IF EXISTS sensors CASCADE;
DROP TABLE IF EXISTS irrigation_events CASCADE;
DROP TABLE IF EXISTS devices CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS users CASCADE;


-- ============================================================
-- 2. USUÁRIOS
-- ============================================================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,

    name VARCHAR(100) NOT NULL,

    email VARCHAR(150) UNIQUE NOT NULL,

    password_hash TEXT NOT NULL,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 3. PROPRIEDADE
-- ============================================================

CREATE TABLE properties (
    id SERIAL PRIMARY KEY,

    user_id INTEGER NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    name VARCHAR(100) NOT NULL,

    location VARCHAR(150),

    area_hectares NUMERIC(10,2)
        CHECK (area_hectares >= 0),

    crop VARCHAR(100),

    irrigation_method VARCHAR(50) NOT NULL
        DEFAULT 'Bomba d''água',

    moisture_limit NUMERIC(5,2) NOT NULL
        DEFAULT 35.00
        CHECK (
            moisture_limit >= 0
            AND moisture_limit <= 100
        ),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 4. ESP32 / DISPOSITIVO
-- ============================================================
-- online:
-- TRUE  = ESP32 conectado
-- FALSE = ESP32 desconectado
--
-- irrigation_on:
-- TRUE  = irrigação ligada
-- FALSE = irrigação desligada
-- ============================================================

CREATE TABLE devices (
    id SERIAL PRIMARY KEY,

    property_id INTEGER NOT NULL
        REFERENCES properties(id)
        ON DELETE CASCADE,

    device_code VARCHAR(50) UNIQUE NOT NULL,

    name VARCHAR(100) NOT NULL,

    online BOOLEAN NOT NULL DEFAULT FALSE,

    irrigation_on BOOLEAN NOT NULL DEFAULT FALSE,

    last_seen TIMESTAMP,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 5. SENSORES
-- ============================================================

CREATE TABLE sensors (
    id SERIAL PRIMARY KEY,

    device_id INTEGER NOT NULL
        REFERENCES devices(id)
        ON DELETE CASCADE,

    type VARCHAR(30) NOT NULL
        CHECK (
            type IN (
                'soil_moisture',
                'temperature',
                'water_flow'
            )
        ),

    name VARCHAR(100) NOT NULL,

    unit VARCHAR(20) NOT NULL,

    UNIQUE(device_id, type)
);


-- ============================================================
-- 6. LEITURAS DOS SENSORES
-- ============================================================

CREATE TABLE sensor_readings (
    id SERIAL PRIMARY KEY,

    sensor_id INTEGER NOT NULL
        REFERENCES sensors(id)
        ON DELETE CASCADE,

    value NUMERIC(10,2) NOT NULL,

    reading_time TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 7. HISTÓRICO DAS IRRIGAÇÕES
-- ============================================================
--
-- Cada registro representa um período em que a irrigação
-- ficou ligada.
-- ============================================================

CREATE TABLE irrigation_events (
    id SERIAL PRIMARY KEY,

    device_id INTEGER NOT NULL
        REFERENCES devices(id)
        ON DELETE CASCADE,

    started_at TIMESTAMP NOT NULL,

    ended_at TIMESTAMP,

    duration_minutes INTEGER
        CHECK (
            duration_minutes IS NULL
            OR duration_minutes >= 0
        ),

    water_used_liters NUMERIC(10,2) NOT NULL
        DEFAULT 0
        CHECK (water_used_liters >= 0),

    moisture_before NUMERIC(5,2)
        CHECK (
            moisture_before IS NULL
            OR (
                moisture_before >= 0
                AND moisture_before <= 100
            )
        ),

    moisture_after NUMERIC(5,2)
        CHECK (
            moisture_after IS NULL
            OR (
                moisture_after >= 0
                AND moisture_after <= 100
            )
        ),

    CHECK (
        ended_at IS NULL
        OR ended_at >= started_at
    )
);


-- ============================================================
-- 8. ÍNDICES
-- ============================================================

CREATE INDEX idx_properties_user
ON properties(user_id);

CREATE INDEX idx_devices_property
ON devices(property_id);

CREATE INDEX idx_sensors_device
ON sensors(device_id);

CREATE INDEX idx_sensor_readings_sensor_time
ON sensor_readings(sensor_id, reading_time);

CREATE INDEX idx_irrigation_events_device_date
ON irrigation_events(device_id, started_at);


-- ============================================================
-- 9. CONSUMO DIÁRIO
-- ============================================================
--
-- O consumo diário é calculado a partir dos eventos
-- de irrigação.
--
-- Assim não duplicamos o mesmo consumo em duas tabelas.
--
-- A VIEW permite obter:
--
-- - consumo de hoje
-- - últimos 7 dias
-- - mês
-- - total
-- - gráfico diário
-- - maior consumo
-- - menor consumo
-- - média
-- - período personalizado
-- ============================================================

CREATE VIEW daily_consumption AS

SELECT
    d.property_id,

    DATE(e.started_at) AS consumption_date,

    ROUND(
        SUM(e.water_used_liters),
        2
    ) AS water_used_liters

FROM irrigation_events e

JOIN devices d
    ON d.id = e.device_id

GROUP BY
    d.property_id,
    DATE(e.started_at);


-- ============================================================
-- 10. USUÁRIO DE TESTE
-- ============================================================

INSERT INTO users (
    name,
    email,
    password_hash
)
VALUES (
    'João Pereira',
    'joao@example.com',
    'senha_teste_hash'
);


-- ============================================================
-- 11. PROPRIEDADE DE TESTE
-- ============================================================

INSERT INTO properties (
    user_id,
    name,
    location,
    area_hectares,
    crop,
    irrigation_method,
    moisture_limit
)
VALUES (
    1,
    'Sítio Boa Vista',
    'Juazeiro do Norte - CE',
    2.00,
    'Cebola',
    'Bomba d''água',
    35.00
);


-- ============================================================
-- 12. ESP32 DE TESTE
-- ============================================================

INSERT INTO devices (
    property_id,
    device_code,
    name,
    online,
    irrigation_on,
    last_seen
)
VALUES (
    1,
    'ESP32-001',
    'ESP32 IrrigaSmart',
    TRUE,
    FALSE,
    CURRENT_TIMESTAMP
);


-- ============================================================
-- 13. SENSORES DE TESTE
-- ============================================================

INSERT INTO sensors (
    device_id,
    type,
    name,
    unit
)
VALUES
(
    1,
    'soil_moisture',
    'Sensor de Umidade',
    '%'
),
(
    1,
    'temperature',
    'Sensor de Temperatura',
    '°C'
),
(
    1,
    'water_flow',
    'Sensor de Vazão',
    'L/min'
);


-- ============================================================
-- 14. HISTÓRICO DE IRRIGAÇÕES
-- ============================================================

INSERT INTO irrigation_events (
    device_id,
    started_at,
    ended_at,
    duration_minutes,
    water_used_liters,
    moisture_before,
    moisture_after
)
VALUES

-- Hoje
(
    1,
    CURRENT_DATE + INTERVAL '9 hours',
    CURRENT_DATE + INTERVAL '10 hours',
    60,
    600,
    19,
    43
),

-- Ontem
(
    1,
    CURRENT_DATE - INTERVAL '1 day' + INTERVAL '9 hours',
    CURRENT_DATE - INTERVAL '1 day' + INTERVAL '10 hours',
    60,
    600,
    21,
    42
),

-- 2 dias atrás
(
    1,
    CURRENT_DATE - INTERVAL '2 days' + INTERVAL '9 hours',
    CURRENT_DATE - INTERVAL '2 days' + INTERVAL '9 hours 45 minutes',
    45,
    450,
    23,
    40
),

-- 3 dias atrás
(
    1,
    CURRENT_DATE - INTERVAL '3 days' + INTERVAL '9 hours',
    CURRENT_DATE - INTERVAL '3 days' + INTERVAL '9 hours 50 minutes',
    50,
    500,
    20,
    41
),

-- 4 dias atrás
(
    1,
    CURRENT_DATE - INTERVAL '4 days' + INTERVAL '9 hours',
    CURRENT_DATE - INTERVAL '4 days' + INTERVAL '9 hours 40 minutes',
    40,
    400,
    24,
    39
),

-- 5 dias atrás
(
    1,
    CURRENT_DATE - INTERVAL '5 days' + INTERVAL '9 hours',
    CURRENT_DATE - INTERVAL '5 days' + INTERVAL '9 hours 55 minutes',
    55,
    550,
    18,
    42
),

-- 6 dias atrás
(
    1,
    CURRENT_DATE - INTERVAL '6 days' + INTERVAL '9 hours',
    CURRENT_DATE - INTERVAL '6 days' + INTERVAL '9 hours 45 minutes',
    45,
    450,
    22,
    40
);


-- ============================================================
-- 15. LEITURAS DE UMIDADE
-- ============================================================

INSERT INTO sensor_readings (
    sensor_id,
    value,
    reading_time
)

SELECT
    1,

    ROUND(
        (25 + RANDOM() * 20)::NUMERIC,
        2
    ),

    hora

FROM generate_series(
    CURRENT_TIMESTAMP - INTERVAL '23 hours',
    CURRENT_TIMESTAMP,
    INTERVAL '1 hour'
) AS hora;


-- ============================================================
-- 16. LEITURAS DE TEMPERATURA
-- ============================================================

INSERT INTO sensor_readings (
    sensor_id,
    value,
    reading_time
)

SELECT
    2,

    ROUND(
        (24 + RANDOM() * 8)::NUMERIC,
        2
    ),

    hora

FROM generate_series(
    CURRENT_TIMESTAMP - INTERVAL '23 hours',
    CURRENT_TIMESTAMP,
    INTERVAL '1 hour'
) AS hora;


-- ============================================================
-- 17. LEITURAS DE VAZÃO
-- ============================================================

INSERT INTO sensor_readings (
    sensor_id,
    value,
    reading_time
)
VALUES
(
    3,
    0,
    CURRENT_DATE + INTERVAL '8 hours 30 minutes'
),
(
    3,
    10.20,
    CURRENT_DATE + INTERVAL '9 hours 15 minutes'
),
(
    3,
    9.80,
    CURRENT_DATE + INTERVAL '9 hours 45 minutes'
),
(
    3,
    0,
    CURRENT_DATE + INTERVAL '10 hours 15 minutes'
);


-- ============================================================
-- 18. VIEW RESUMIDA DO DASHBOARD
-- ============================================================

CREATE VIEW dashboard_summary AS

SELECT

    u.id AS user_id,
    u.name AS user_name,

    p.id AS property_id,
    p.name AS property_name,
    p.location,
    p.area_hectares,
    p.crop,
    p.irrigation_method,
    p.moisture_limit,

    d.id AS device_id,
    d.device_code,
    d.online,
    d.irrigation_on,
    d.last_seen,

    (
        SELECT sr.value
        FROM sensor_readings sr

        JOIN sensors s
            ON s.id = sr.sensor_id

        WHERE s.device_id = d.id
          AND s.type = 'soil_moisture'

        ORDER BY sr.reading_time DESC

        LIMIT 1
    ) AS current_moisture,

    (
        SELECT sr.value
        FROM sensor_readings sr

        JOIN sensors s
            ON s.id = sr.sensor_id

        WHERE s.device_id = d.id
          AND s.type = 'temperature'

        ORDER BY sr.reading_time DESC

        LIMIT 1
    ) AS current_temperature,

    COALESCE(
        (
            SELECT SUM(e.water_used_liters)

            FROM irrigation_events e

            WHERE e.device_id = d.id

              AND DATE(e.started_at) = CURRENT_DATE
        ),
        0
    ) AS today_water_consumption

FROM users u

JOIN properties p
    ON p.user_id = u.id

JOIN devices d
    ON d.property_id = p.id;
