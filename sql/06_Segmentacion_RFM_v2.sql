-- ============================================================
-- 🌹 FLORICOLA ANALYTICS
-- Día 6 — SQL Avanzado: Segmentación RFM (Versión 2 - Capa Silver)
-- ============================================================

-- ============================================================
-- PREGUNTA DE NEGOCIO 15
-- Segmentacion de clientes con RFM (Recency, Frequency, Monetary)
-- usando NTILE(5) sobre silver.fct_venta.
-- ============================================================

WITH rfm_base AS (
    SELECT
        cliente_id,
        (SELECT MAX(fecha) FROM silver.fct_venta) - MAX(fecha) AS recency,
        COUNT(*) AS frequency,
        SUM(tallos::numeric * precio_tallo::numeric) AS monetary
    FROM silver.fct_venta
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
