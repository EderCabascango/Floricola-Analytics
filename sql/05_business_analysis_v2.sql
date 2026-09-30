-- ============================================================
-- 🌹 FLORICOLA ANALYTICS
-- Día 5 — Business Analysis (Versión 2 - Arquitectura Medallón)
-- PostgreSQL 16
--
-- Objetivo:
-- Responder preguntas de negocio utilizando las vistas limpias
-- de la capa Silver (silver.fct_venta, silver.dim_cliente,
-- silver.fct_inventario_movimiento, silver.fct_cosecha, etc.).
-- ============================================================


-- ============================================================
-- PREGUNTA DE NEGOCIO 1
-- ¿Qué variedades tienen mayor volumen de ventas?
-- ============================================================

SELECT
    va.nombre,
    SUM(ve.tallos) AS total_tallos
FROM silver.fct_venta AS ve
JOIN silver.dim_variedad AS va
    ON va.variedad_id = ve.variedad_id
GROUP BY va.nombre
ORDER BY total_tallos DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 2
-- ¿Qué variedades tienen mayor valor de ventas?
--
-- Además del valor total, calculamos el precio promedio
-- ponderado por tallos:
--
-- SUM(tallos * precio_tallo) / SUM(tallos)
-- ============================================================

SELECT
    va.nombre,
    SUM(ve.tallos) AS total_tallos,
    ROUND(
        SUM(ve.tallos * ve.precio_tallo) / SUM(ve.tallos),
        2
    ) AS precio_promedio_ponderado,
    SUM(ve.tallos * ve.precio_tallo) AS total_venta
FROM silver.fct_venta AS ve
JOIN silver.dim_variedad AS va
    ON va.variedad_id = ve.variedad_id
GROUP BY va.nombre
ORDER BY total_venta DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 3
-- ¿Qué bloques tienen mayor producción?
-- ============================================================

SELECT
    b.bloque_id,
    b.variedad_nombre AS variedad,
    SUM(co.tallos) AS total_tallos
FROM silver.fct_cosecha AS co
JOIN silver.dim_bloque AS b
    ON b.bloque_id = co.bloque_id
GROUP BY
    b.bloque_id,
    b.variedad_nombre
ORDER BY total_tallos DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 4
-- ¿Qué bloques tienen mayor productividad por hectárea?
--
-- Aquí relacionamos producción con superficie cultivada.
-- ============================================================

SELECT
    b.bloque_id,
    b.variedad_nombre AS variedad,
    b.hectareas,
    SUM(co.tallos) AS total_tallos,
    ROUND(
        SUM(co.tallos) / b.hectareas,
        0
    ) AS tallos_por_hectarea
FROM silver.fct_cosecha AS co
JOIN silver.dim_bloque AS b
    ON b.bloque_id = co.bloque_id
GROUP BY
    b.bloque_id,
    b.variedad_nombre,
    b.hectareas
ORDER BY total_tallos DESC
LIMIT 3;


-- ============================================================
-- PREGUNTA DE NEGOCIO 5
-- ¿Qué variedades presentan mayor cantidad de merma?
-- ============================================================

SELECT
    va.nombre,
    SUM(im.cantidad) AS tallos_merma
FROM silver.fct_inventario_movimiento AS im
JOIN silver.fct_cosecha AS co
    ON co.cosecha_id = im.cosecha_id
JOIN silver.dim_bloque AS b
    ON b.bloque_id = co.bloque_id
JOIN silver.dim_variedad AS va
    ON va.variedad_id = b.variedad_id
WHERE im.tipo_movimiento = 'merma'
GROUP BY va.nombre
ORDER BY tallos_merma DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 6
-- ¿Qué porcentaje de la producción termina como merma?
--
-- IMPORTANTE:
-- Producción y merma son agregaciones de diferentes hechos.
-- Primero agregamos cada conjunto por separado y después
-- relacionamos ambos resultados, para evitar duplicacion por
-- multiplicidad de relaciones (una cosecha puede tener varios
-- movimientos de inventario).
-- ============================================================

WITH produccion AS (
    SELECT
        va.nombre AS variedad,
        SUM(co.tallos) AS total_tallos
    FROM silver.fct_cosecha AS co
    JOIN silver.dim_bloque AS b
        ON b.bloque_id = co.bloque_id
    JOIN silver.dim_variedad AS va
        ON va.variedad_id = b.variedad_id
    GROUP BY va.nombre
),
merma AS (
    SELECT
        va.nombre AS variedad,
        SUM(im.cantidad) AS tallos_merma
    FROM silver.fct_inventario_movimiento AS im
    JOIN silver.fct_cosecha AS co
        ON co.cosecha_id = im.cosecha_id
    JOIN silver.dim_bloque AS b
        ON b.bloque_id = co.bloque_id
    JOIN silver.dim_variedad AS va
        ON va.variedad_id = b.variedad_id
    WHERE im.tipo_movimiento = 'merma'
    GROUP BY va.nombre
)
SELECT
    p.variedad,
    p.total_tallos,
    m.tallos_merma,
    ROUND(
        (m.tallos_merma::numeric / p.total_tallos) * 100,
        2
    ) AS porcentaje_merma
FROM produccion AS p
JOIN merma AS m
    ON p.variedad = m.variedad
ORDER BY porcentaje_merma DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 7
-- ¿Qué clientes compraron en 2025 pero no realizaron compras
-- en 2026?
--
-- Practica: CTE + DISTINCT + LEFT JOIN + IS NULL
-- ============================================================

WITH clientes_2025 AS (
    SELECT DISTINCT cliente_id
    FROM silver.fct_venta
    WHERE fecha >= '2025-01-01'
      AND fecha < '2026-01-01'
),
clientes_2026 AS (
    SELECT DISTINCT cliente_id
    FROM silver.fct_venta
    WHERE fecha >= '2026-01-01'
      AND fecha <= CURRENT_DATE
)
SELECT
    c2025.cliente_id
FROM clientes_2025 AS c2025
LEFT JOIN clientes_2026 AS c2026
    ON c2025.cliente_id = c2026.cliente_id
WHERE c2026.cliente_id IS NULL;


-- ============================================================
-- PREGUNTA DE NEGOCIO 8
-- ¿Qué clientes generaron mayor valor de ventas?
-- ============================================================

SELECT
    cl.cliente_id,
    cl.nombre,
    SUM(
        ve.tallos::numeric * ve.precio_tallo::numeric
    ) AS venta_total
FROM silver.fct_venta AS ve
JOIN silver.dim_cliente AS cl
    ON ve.cliente_id = cl.cliente_id
GROUP BY
    cl.cliente_id,
    cl.nombre
ORDER BY venta_total DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 9
-- ¿El precio promedio pagado por tallo varia segun el tipo
-- de cliente (Importador, Broker, Retailer)?
-- ============================================================

SELECT
    cl.tipo,
    COUNT(*) AS num_ventas,
    SUM(ve.tallos) AS total_tallos,
    ROUND(
        SUM(ve.tallos * ve.precio_tallo) / SUM(ve.tallos),
        2
    ) AS precio_promedio_ponderado
FROM silver.fct_venta AS ve
JOIN silver.dim_cliente AS cl
    ON ve.cliente_id = cl.cliente_id
GROUP BY cl.tipo
ORDER BY precio_promedio_ponderado DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 10
-- ¿Las temporadas altas (San Valentin, Dia de la Madre) venden
-- mas por semana que una semana normal?
-- ============================================================

WITH ventas_con_temporada AS (
    SELECT
        ve.*,
        EXTRACT(YEAR FROM fecha) AS anio,
        CASE
            WHEN EXTRACT(WEEK FROM fecha) BETWEEN 3 AND 6 THEN 'San Valentin'
            WHEN EXTRACT(WEEK FROM fecha) BETWEEN 15 AND 18 THEN 'Dia de la Madre'
            ELSE 'Normal'
        END AS temporada
    FROM silver.fct_venta AS ve
)
SELECT
    temporada,
    anio,
    SUM(tallos) AS total_tallos,
    ROUND(
        SUM(tallos)::numeric /
        CASE
            WHEN temporada = 'Normal' THEN 44
            ELSE 4
        END,
        0
    ) AS promedio_semanal
FROM ventas_con_temporada
WHERE
    (temporada = 'Normal' AND anio IN (2024, 2025))
    OR
    (temporada != 'Normal' AND anio IN (2024, 2025, 2026))
GROUP BY temporada, anio
ORDER BY anio, temporada;


-- ============================================================
-- PREGUNTA DE NEGOCIO 11
-- ¿Cual es la evolucion mensual de ventas a lo largo del periodo?
-- ============================================================

SELECT
    DATE_TRUNC('MONTH', fecha) AS mes,
    SUM(tallos) AS total_tallos,
    SUM(tallos::numeric * precio_tallo) AS valor_total
FROM silver.fct_venta
GROUP BY mes
ORDER BY mes;


-- ============================================================
-- PREGUNTA DE NEGOCIO 12
-- ¿Cual es la evolucion trimestral de ventas?
-- ============================================================

SELECT
    DATE_TRUNC('quarter', fecha) AS trimestre,
    SUM(tallos) AS total_tallos,
    SUM(tallos::numeric * precio_tallo) AS valor_total
FROM silver.fct_venta
GROUP BY trimestre
ORDER BY trimestre;


-- ============================================================
-- PREGUNTA DE NEGOCIO 13
-- ¿Cual es la variacion trimestre-a-trimestre en valor de ventas?
-- ============================================================

WITH ventas_trimestre AS (
    SELECT
        DATE_TRUNC('quarter', fecha) AS trimestre,
        SUM(tallos::numeric * precio_tallo) AS valor_total
    FROM silver.fct_venta
    GROUP BY DATE_TRUNC('quarter', fecha)
),
con_lag AS (
    SELECT
        trimestre,
        valor_total,
        LAG(valor_total) OVER (ORDER BY trimestre) AS valor_anterior
    FROM ventas_trimestre
)
SELECT
    trimestre,
    valor_total,
    valor_anterior,
    valor_total - valor_anterior AS diferencia
FROM con_lag
ORDER BY trimestre;


-- ============================================================
-- PREGUNTA DE NEGOCIO 14
-- Diferencia de promedio semanal entre temporadas altas y
-- Normal, en formato pivote (una fila por año)
-- ============================================================

WITH ventas_con_temporada AS (
    SELECT
        ve.*,
        EXTRACT(YEAR FROM fecha) AS anio,
        CASE
            WHEN EXTRACT(WEEK FROM fecha) BETWEEN 3 AND 6 THEN 'San Valentin'
            WHEN EXTRACT(WEEK FROM fecha) BETWEEN 15 AND 18 THEN 'Dia de la Madre'
            ELSE 'Normal'
        END AS temporada
    FROM silver.fct_venta AS ve
),
promedios AS (
    SELECT
        temporada,
        anio,
        ROUND(
            SUM(tallos)::numeric /
            CASE
                WHEN temporada = 'Normal' THEN 44
                ELSE 4
            END,
            0
        ) AS promedio_semanal
    FROM ventas_con_temporada
    WHERE
        (temporada = 'Normal' AND anio IN (2024, 2025))
        OR
        (temporada != 'Normal' AND anio IN (2024, 2025, 2026))
    GROUP BY temporada, anio
),
pivote AS (
    SELECT
        anio,
        SUM(CASE WHEN temporada = 'San Valentin' THEN promedio_semanal END) AS prom_san_valentin,
        SUM(CASE WHEN temporada = 'Dia de la Madre' THEN promedio_semanal END) AS prom_dia_madre,
        SUM(CASE WHEN temporada = 'Normal' THEN promedio_semanal END) AS prom_normal
    FROM promedios
    GROUP BY anio
)
SELECT
    anio,
    prom_san_valentin,
    prom_dia_madre,
    prom_normal,
    prom_san_valentin - prom_normal AS diff_sanvalentin_vs_normal,
    prom_dia_madre - prom_normal AS diff_diamadre_vs_normal
FROM pivote
ORDER BY anio;
