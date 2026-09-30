-- ============================================================
-- 🌹 FLORICOLA ANALYTICS
-- Día 6 — SQL Avanzado: Segmentación RFM
-- ============================================================

-- ============================================================
-- PREGUNTA DE NEGOCIO 15
-- Segmentacion de clientes con RFM (Recency, Frequency, Monetary)
-- usando NTILE(5) para asignar un score de 1 a 5 en cada dimension.
--
-- Recency: dias desde la ultima compra (DESC, menos dias = mejor)
-- Frequency: numero de compras (ASC, mas compras = mejor)
-- Monetary: valor total de compras (ASC, mas valor = mejor)
-- ============================================================

WITH rfm_base AS (
    SELECT
        cliente_id,
        (SELECT MAX(fecha) FROM venta_limpia) - MAX(fecha) AS recency,
        COUNT(*) AS frequency,
        SUM(tallos::numeric * precio_tallo::numeric) AS monetary
    FROM venta_limpia
    GROUP BY cliente_id
),
rfm_scores AS (
    SELECT
        cliente_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS score_r,
        NTILE(5) OVER (ORDER BY frequency) AS score_f,
        NTILE(5) OVER (ORDER BY monetary) AS score_m
    FROM rfm_base
)
SELECT
    cliente_id,
    score_r,
    score_f,
    score_m,
    ROUND((score_r + score_f + score_m) / 3.0, 1) AS score_promedio,
    CASE
        WHEN (score_r + score_f + score_m) / 3.0 >= 4 THEN 'Champion'
        WHEN (score_r + score_f + score_m) / 3.0 >= 3 THEN 'Cliente valioso'
        ELSE 'En riesgo / basico'
    END AS segmento
FROM rfm_scores
ORDER BY score_promedio DESC;

-- Resultado: 6 Champions, 7 Clientes valiosos, 15 En riesgo/basico.
--
-- Nota importante: dado que el simulador asigna clientes a cada
-- venta de forma uniforme y aleatoria (ver Pregunta 7), la
-- dimension Recency tiene poca variacion real entre clientes
-- (0 a 11 dias), por lo que el segmento resultante esta dominado
-- principalmente por Frequency y Monetary. En un dataset real,
-- o en una version futura del simulador con comportamiento de
-- compra diferenciado por cliente, Recency aportaria mas señal.
--
-- Conceptos nuevos: NTILE() para repartir filas ordenadas en N
-- grupos de tamaño similar; direccion del ORDER BY (ASC/DESC)
-- determina que extremo recibe el mejor score.