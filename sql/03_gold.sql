-- ============================================================
-- 🌹 FLORICOLA ANALYTICS
-- Capa Gold (Data Marts / Business Analytics / MLOps Ready)
-- PostgreSQL 16
--
-- Objetivo:
-- Tablas y vistas agregadas de alto nivel de negocio para:
-- 1. Dashboards ejecutivos en Power BI.
-- 2. Segmentacion avanzada de clientes (RFM con NTILE).
-- 3. Rendimiento y control operativo (produccion y mermas).
-- 4. Dataset de features para modelos de forecasting / MLOps.
-- ============================================================

-- 1. Limpieza de vistas previas en gold
DROP VIEW IF EXISTS gold.feat_demanda_forecasting CASCADE;
DROP VIEW IF EXISTS gold.dm_estacionalidad_semanal CASCADE;
DROP VIEW IF EXISTS gold.dm_rendimiento_campo CASCADE;
DROP VIEW IF EXISTS gold.dm_cliente_rfm CASCADE;
DROP VIEW IF EXISTS gold.dm_ventas_mensual CASCADE;

-- ============================================================
-- 2. DATA MART: VENTAS MENSUALES (Power BI)
-- ============================================================
CREATE OR REPLACE VIEW gold.dm_ventas_mensual AS
SELECT
    DATE_TRUNC('month', v.fecha)::DATE AS mes,
    EXTRACT(YEAR FROM v.fecha)::INTEGER AS anio,
    EXTRACT(MONTH FROM v.fecha)::INTEGER AS mes_numero,
    v.variedad_id,
    va.nombre AS variedad_nombre,
    va.tipo AS variedad_tipo,
    va.color AS variedad_color,
    cl.pais_destino,
    cl.tipo AS tipo_cliente,
    COUNT(v.venta_id) AS total_transacciones,
    SUM(v.tallos) AS total_tallos,
    SUM(v.valor_total) AS total_valor_ventas,
    ROUND(
        (SUM(v.valor_total) / NULLIF(SUM(v.tallos), 0)),
        3
    ) AS precio_promedio_ponderado
FROM silver.fct_venta v
JOIN silver.dim_variedad va ON v.variedad_id = va.variedad_id
JOIN silver.dim_cliente cl ON v.cliente_id = cl.cliente_id
GROUP BY
    DATE_TRUNC('month', v.fecha)::DATE,
    EXTRACT(YEAR FROM v.fecha),
    EXTRACT(MONTH FROM v.fecha),
    v.variedad_id,
    va.nombre,
    va.tipo,
    va.color,
    cl.pais_destino,
    cl.tipo;

-- ============================================================
-- 3. DATA MART: SEGMENTACION RFM DE CLIENTES (SQL Avanzado)
-- ============================================================
CREATE OR REPLACE VIEW gold.dm_cliente_rfm AS
WITH max_fecha_global AS (
    SELECT MAX(fecha) AS fecha_corte FROM silver.fct_venta
),
rfm_base AS (
    SELECT
        v.cliente_id,
        (SELECT fecha_corte FROM max_fecha_global) - MAX(v.fecha) AS recencia_dias,
        COUNT(v.venta_id) AS frecuencia,
        SUM(v.valor_total) AS valor_monetario
    FROM silver.fct_venta v
    GROUP BY v.cliente_id
),
rfm_scores AS (
    SELECT
        r.cliente_id,
        r.recencia_dias,
        r.frecuencia,
        r.valor_monetario,
        -- Recencia menor es mejor -> orden DESC para asignar 5 al mas reciente
        NTILE(5) OVER (ORDER BY r.recencia_dias DESC) AS r_score,
        NTILE(5) OVER (ORDER BY r.frecuencia ASC) AS f_score,
        NTILE(5) OVER (ORDER BY r.valor_monetario ASC) AS m_score
    FROM rfm_base r
),
rfm_segmentado AS (
    SELECT
        s.*,
        (s.r_score + s.f_score + s.m_score) AS rfm_total_score,
        CASE
            WHEN s.r_score >= 4 AND s.f_score >= 4 AND s.m_score >= 4 THEN 'Campeones (Champions)'
            WHEN s.r_score >= 3 AND s.f_score >= 3 THEN 'Clientes Leales (Loyal)'
            WHEN s.r_score >= 4 AND s.f_score <= 2 THEN 'Prometedores / Recientes'
            WHEN s.r_score <= 2 AND s.f_score >= 3 THEN 'En Riesgo (At Risk)'
            WHEN s.r_score <= 2 AND s.f_score <= 2 THEN 'Hibernando / Perdidos'
            ELSE 'Potenciales / Regulares'
        END AS segmento_cliente
    FROM rfm_scores s
)
SELECT
    c.cliente_id,
    c.nombre AS cliente_nombre,
    c.pais_destino,
    c.tipo AS tipo_cliente,
    seg.recencia_dias,
    seg.frecuencia,
    seg.valor_monetario,
    seg.r_score,
    seg.f_score,
    seg.m_score,
    seg.rfm_total_score,
    seg.segmento_cliente
FROM rfm_segmentado seg
JOIN silver.dim_cliente c ON c.cliente_id = seg.cliente_id;

-- ============================================================
-- 4. DATA MART: RENDIMIENTO DE CAMPO Y MERMAS (Operaciones)
-- ============================================================
CREATE OR REPLACE VIEW gold.dm_rendimiento_campo AS
WITH produccion AS (
    SELECT
        b.bloque_id,
        b.codigo_bloque,
        b.hectareas,
        b.variedad_id,
        b.variedad_nombre,
        SUM(co.tallos) AS tallos_cosechados,
        COUNT(co.cosecha_id) AS total_cortes
    FROM silver.fct_cosecha co
    JOIN silver.dim_bloque b ON co.bloque_id = b.bloque_id
    GROUP BY b.bloque_id, b.codigo_bloque, b.hectareas, b.variedad_id, b.variedad_nombre
),
mermas AS (
    SELECT
        co.bloque_id,
        SUM(im.cantidad) AS tallos_merma
    FROM silver.fct_inventario_movimiento im
    JOIN silver.fct_cosecha co ON co.cosecha_id = im.cosecha_id
    WHERE im.tipo_movimiento = 'merma'
    GROUP BY co.bloque_id
)
SELECT
    p.bloque_id,
    p.codigo_bloque,
    p.hectareas,
    p.variedad_nombre,
    p.tallos_cosechados,
    ROUND((p.tallos_cosechados / p.hectareas), 0) AS tallos_por_hectarea,
    COALESCE(m.tallos_merma, 0) AS tallos_merma,
    ROUND(
        (COALESCE(m.tallos_merma, 0)::numeric / NULLIF(p.tallos_cosechados, 0)) * 100,
        2
    ) AS porcentaje_merma
FROM produccion p
LEFT JOIN mermas m ON p.bloque_id = m.bloque_id;

-- ============================================================
-- 5. DATA MART: ESTACIONALIDAD SEMANAL
-- ============================================================
CREATE OR REPLACE VIEW gold.dm_estacionalidad_semanal AS
SELECT
    EXTRACT(YEAR FROM fecha)::INTEGER AS anio,
    EXTRACT(WEEK FROM fecha)::INTEGER AS semana_iso,
    CASE
        WHEN EXTRACT(WEEK FROM fecha) BETWEEN 3 AND 6 THEN 'San Valentin'
        WHEN EXTRACT(WEEK FROM fecha) BETWEEN 15 AND 18 THEN 'Dia de la Madre'
        ELSE 'Normal'
    END AS temporada,
    COUNT(venta_id) AS total_pedidos,
    SUM(tallos) AS total_tallos,
    SUM(valor_total) AS total_valor_ventas
FROM silver.fct_venta
GROUP BY
    EXTRACT(YEAR FROM fecha),
    EXTRACT(WEEK FROM fecha),
    CASE
        WHEN EXTRACT(WEEK FROM fecha) BETWEEN 3 AND 6 THEN 'San Valentin'
        WHEN EXTRACT(WEEK FROM fecha) BETWEEN 15 AND 18 THEN 'Dia de la Madre'
        ELSE 'Normal'
    END;

-- ============================================================
-- 6. FEATURE VIEW: DEMANDA FORECASTING (MLOps / Modelado)
-- ============================================================
CREATE OR REPLACE VIEW gold.feat_demanda_forecasting AS
SELECT
    v.fecha,
    v.variedad_id,
    va.nombre AS variedad_nombre,
    va.tipo AS variedad_tipo,
    SUM(v.tallos) AS demanda_tallos,
    SUM(v.valor_total) AS ingresos_totales,
    ROUND(AVG(v.precio_tallo), 3) AS precio_promedio,
    EXTRACT(ISODOW FROM v.fecha)::INTEGER AS dia_semana,
    EXTRACT(MONTH FROM v.fecha)::INTEGER AS mes,
    EXTRACT(WEEK FROM v.fecha)::INTEGER AS semana_iso,
    CASE
        WHEN EXTRACT(WEEK FROM v.fecha) BETWEEN 3 AND 6 THEN 1
        ELSE 0
    END AS flag_san_valentin,
    CASE
        WHEN EXTRACT(WEEK FROM v.fecha) BETWEEN 15 AND 18 THEN 1
        ELSE 0
    END AS flag_dia_madre
FROM silver.fct_venta v
JOIN silver.dim_variedad va ON v.variedad_id = va.variedad_id
GROUP BY
    v.fecha,
    v.variedad_id,
    va.nombre,
    va.tipo;
