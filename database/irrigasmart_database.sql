-- ============================================================
-- IRRIGASMART - BANCO DE DADOS
-- ============================================================

-- ============================================================
-- 1. LIMPEZA
-- ============================================================

DROP VIEW IF EXISTS resumo_dashboard;
DROP VIEW IF EXISTS consumo_diario;

DROP TABLE IF EXISTS leituras_sensores CASCADE;
DROP TABLE IF EXISTS sensores CASCADE;
DROP TABLE IF EXISTS eventos_irrigacao CASCADE;
DROP TABLE IF EXISTS dispositivos CASCADE;
DROP TABLE IF EXISTS propriedades CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;


-- ============================================================
-- 2. USUÁRIOS
-- ============================================================

CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,

    name VARCHAR(100) NOT NULL,

    email VARCHAR(150) UNIQUE NOT NULL,

    senha_hash TEXT NOT NULL,

    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 3. PROPRIEDADE
-- ============================================================
--
-- A propriedade é cadastrada depois da criação da conta.
--
-- O mesmo registro é utilizado posteriormente pela tela
-- "Configurações > Minha propriedade".
--
-- ============================================================

CREATE TABLE propriedades (
    id SERIAL PRIMARY KEY,

    usuario_id INTEGER NOT NULL
        REFERENCES usuarios(id)
        ON DELETE CASCADE,

    name VARCHAR(100) NOT NULL,

    localizacao VARCHAR(150),

    area_hectares NUMERIC(10,2)
        CHECK (area_hectares >= 0),

    cultura VARCHAR(100),

    metodo_irrigacao VARCHAR(50) NOT NULL
        DEFAULT 'Bomba d''água',

    limite_umidade NUMERIC(5,2) NOT NULL
        DEFAULT 35.00
        CHECK (
            limite_umidade >= 0
            AND limite_umidade <= 100
        ),

    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 4. ESP32 / DISPOSITIVO
-- ============================================================
--
-- online:
-- TRUE  = ESP32 conectado
-- FALSE = ESP32 desconectado
--
-- irrigacao_ligada:
-- TRUE  = irrigação ligada
-- FALSE = irrigação desligada
--
-- ============================================================

CREATE TABLE dispositivos (
    id SERIAL PRIMARY KEY,

    propriedade_id INTEGER NOT NULL
        REFERENCES propriedades(id)
        ON DELETE CASCADE,

    codigo_dispositivo VARCHAR(50) UNIQUE NOT NULL,

    name VARCHAR(100) NOT NULL,

    online BOOLEAN NOT NULL DEFAULT FALSE,

    irrigacao_ligada BOOLEAN NOT NULL DEFAULT FALSE,

    ultimo_sinal TIMESTAMP,

    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 5. SENSORES
-- ============================================================

CREATE TABLE sensores (
    id SERIAL PRIMARY KEY,

    dispositivo_id INTEGER NOT NULL
        REFERENCES dispositivos(id)
        ON DELETE CASCADE,

    type VARCHAR(30) NOT NULL
        CHECK (
            type IN (
                'umidade_solo',
                'temperature',
                'vazao_agua'
            )
        ),

    name VARCHAR(100) NOT NULL,

    unit VARCHAR(20) NOT NULL,

    UNIQUE(dispositivo_id, type)
);


-- ============================================================
-- 6. LEITURAS DOS SENSORES
-- ============================================================

CREATE TABLE leituras_sensores (
    id SERIAL PRIMARY KEY,

    sensor_id INTEGER NOT NULL
        REFERENCES sensores(id)
        ON DELETE CASCADE,

    value NUMERIC(10,2) NOT NULL,

    hora_leitura TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- 7. HISTÓRICO DAS IRRIGAÇÕES
-- ============================================================
--
-- Cada registro representa um período em que a irrigação
-- ficou ligada.
--
-- Não existe "automático", "manual", "completed", etc.
--
-- O estado atual fica em dispositivos.irrigacao_ligada.
--
-- ============================================================

CREATE TABLE eventos_irrigacao (
    id SERIAL PRIMARY KEY,

    dispositivo_id INTEGER NOT NULL
        REFERENCES dispositivos(id)
        ON DELETE CASCADE,

    iniciado_em TIMESTAMP NOT NULL,

    encerrado_em TIMESTAMP,

    duracao_minutos INTEGER
        CHECK (
            duracao_minutos IS NULL
            OR duracao_minutos >= 0
        ),

    agua_utilizada_litros NUMERIC(10,2) NOT NULL
        DEFAULT 0
        CHECK (agua_utilizada_litros >= 0),

    umidade_antes NUMERIC(5,2)
        CHECK (
            umidade_antes IS NULL
            OR (
                umidade_antes >= 0
                AND umidade_antes <= 100
            )
        ),

    umidade_depois NUMERIC(5,2)
        CHECK (
            umidade_depois IS NULL
            OR (
                umidade_depois >= 0
                AND umidade_depois <= 100
            )
        ),

    CHECK (
        encerrado_em IS NULL
        OR encerrado_em >= iniciado_em
    )
);


-- ============================================================
-- 8. ÍNDICES
-- ============================================================

CREATE INDEX idx_properties_user
ON propriedades(usuario_id);

CREATE INDEX idx_devices_property
ON dispositivos(propriedade_id);

CREATE INDEX idx_sensors_device
ON sensores(dispositivo_id);

CREATE INDEX idx_sensor_readings_sensor_time
ON leituras_sensores(sensor_id, hora_leitura);

CREATE INDEX idx_irrigation_events_device_date
ON eventos_irrigacao(dispositivo_id, iniciado_em);


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
--
-- ============================================================

CREATE VIEW consumo_diario AS

SELECT
    d.propriedade_id,

    DATE(e.iniciado_em) AS data_consumo,

    ROUND(
        SUM(e.agua_utilizada_litros),
        2
    ) AS agua_utilizada_litros

FROM eventos_irrigacao e

JOIN dispositivos d
    ON d.id = e.dispositivo_id

GROUP BY
    d.propriedade_id,
    DATE(e.iniciado_em);


-- ============================================================
-- 10. USUÁRIO DE TESTE
-- ============================================================

INSERT INTO usuarios (
    name,
    email,
    senha_hash
)
VALUES (
    'João Pereira',
    'joao@example.com',
    'senha_teste_hash'
);


-- ============================================================
-- 11. PROPRIEDADE DE TESTE
-- ============================================================

INSERT INTO propriedades (
    usuario_id,
    name,
    localizacao,
    area_hectares,
    cultura,
    metodo_irrigacao,
    limite_umidade
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

INSERT INTO dispositivos (
    propriedade_id,
    codigo_dispositivo,
    name,
    online,
    irrigacao_ligada,
    ultimo_sinal
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

INSERT INTO sensores (
    dispositivo_id,
    type,
    name,
    unit
)
VALUES
(
    1,
    'umidade_solo',
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
    'vazao_agua',
    'Sensor de Vazão',
    'L/min'
);


-- ============================================================
-- 14. HISTÓRICO DE IRRIGAÇÕES TESTE
-- ============================================================

INSERT INTO eventos_irrigacao (
    dispositivo_id,
    iniciado_em,
    encerrado_em,
    duracao_minutos,
    agua_utilizada_litros,
    umidade_antes,
    umidade_depois
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
-- 15. LEITURAS DE UMIDADE DE TESTE
-- ============================================================

INSERT INTO leituras_sensores (
    sensor_id,
    value,
    hora_leitura
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
-- 16. LEITURAS DE TEMPERATURA DE TESTE
-- ============================================================

INSERT INTO leituras_sensores (
    sensor_id,
    value,
    hora_leitura
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
-- 17. LEITURAS DE VAZÃO DE TESTE
-- ============================================================
--
-- A irrigação de hoje ocorre das 09:00 às 10:00.
--
-- Durante a irrigação:
-- aproximadamente 10 L/min
--
-- Fora da irrigação:
-- 0 L/min
--
-- ============================================================

INSERT INTO leituras_sensores (
    sensor_id,
    value,
    hora_leitura
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

CREATE VIEW resumo_dashboard AS

SELECT

    u.id AS usuario_id,
    u.name AS user_name,

    p.id AS propriedade_id,
    p.name AS property_name,
    p.localizacao,
    p.area_hectares,
    p.cultura,
    p.metodo_irrigacao,
    p.limite_umidade,

    d.id AS dispositivo_id,
    d.codigo_dispositivo,
    d.online,
    d.irrigacao_ligada,
    d.ultimo_sinal,

    (
        SELECT sr.value
        FROM leituras_sensores sr

        JOIN sensores s
            ON s.id = sr.sensor_id

        WHERE s.dispositivo_id = d.id
          AND s.type = 'umidade_solo'

        ORDER BY sr.hora_leitura DESC

        LIMIT 1
    ) AS umidade_atual,

    (
        SELECT sr.value
        FROM leituras_sensores sr

        JOIN sensores s
            ON s.id = sr.sensor_id

        WHERE s.dispositivo_id = d.id
          AND s.type = 'temperature'

        ORDER BY sr.hora_leitura DESC

        LIMIT 1
    ) AS temperatura_atual,

    COALESCE(
        (
            SELECT SUM(e.agua_utilizada_litros)

            FROM eventos_irrigacao e

            WHERE e.dispositivo_id = d.id

              AND DATE(e.iniciado_em) = CURRENT_DATE
        ),
        0
    ) AS consumo_agua_hoje

FROM usuarios u

JOIN propriedades p
    ON p.usuario_id = u.id

JOIN dispositivos d
    ON d.propriedade_id = p.id;
