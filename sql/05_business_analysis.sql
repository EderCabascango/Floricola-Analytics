-- ============================================================
-- 🌹 FLORICOLA ANALYTICS
-- Día 5 — Business Analysis
-- PostgreSQL
--
-- Objetivo:
-- Responder preguntas de negocio utilizando las vistas limpias
-- construidas durante los Días 3 y 4.
--
-- Estado:
-- PARCIAL — Día 5 queda deliberadamente sin terminar.
-- ============================================================


-- ============================================================
-- PREGUNTA DE NEGOCIO 1
-- ¿Qué variedades tienen mayor volumen de ventas?
-- ============================================================

SELECT
    va.nombre,
    SUM(ve.tallos) AS total_tallos
FROM venta_limpia AS ve
JOIN variedad AS va
    ON va.variedad_id = ve.variedad_id
GROUP BY va.nombre
ORDER BY total_tallos DESC;


-- Resultado observado durante la sesión:
-- Top 3:
-- 1. Orange Crush   → 27,998,272 tallos
-- 2. Sunset Glory   → 26,959,516 tallos
-- 3. Goldfinch      → 24,402,408 tallos
--
-- Menor volumen observado:
-- 1. Purple Moon    → 4,135,309 tallos
-- 2. Freedom        → 4,045,854 tallos
-- 3. Candlelight    → 3,076,682 tallos


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
FROM venta_limpia AS ve
JOIN variedad AS va
    ON va.variedad_id = ve.variedad_id
GROUP BY va.nombre
ORDER BY total_venta DESC;


-- Resultado observado durante la sesión:
-- Orange Crush   → 27,998,272 tallos | $0.31 ponderado | $8,792,989.637
-- Sunset Glory   → 26,959,516 tallos | $0.31 ponderado | $8,379,401.101
-- Goldfinch      → 24,402,408 tallos | $0.32 ponderado | $7,734,789.269
-- Freedom         → 4,045,854 tallos | $0.31 ponderado | $1,272,139.706
-- Million Star    → 8,497,369 tallos | $0.14 ponderado | $1,168,443.042
-- Candlelight     → 3,076,682 tallos | $0.32 ponderado | $969,180.232


-- ============================================================
-- PREGUNTA DE NEGOCIO 3
-- ¿Qué bloques tienen mayor producción?
-- ============================================================

SELECT
    b.bloque_id,
    va.nombre AS variedad,
    SUM(co.tallos) AS total_tallos
FROM cosecha AS co
JOIN bloque AS b
    ON b.bloque_id = co.bloque_id
JOIN variedad AS va
    ON va.variedad_id = b.variedad_id
GROUP BY
    b.bloque_id,
    va.nombre
ORDER BY total_tallos DESC;


-- ============================================================
-- PREGUNTA DE NEGOCIO 4
-- ¿Qué bloques tienen mayor productividad por hectárea?
--
-- Aquí relacionamos producción con superficie cultivada.
-- ============================================================

SELECT
    b.bloque_id,
    va.nombre AS variedad,
    b.hectareas,
    SUM(co.tallos) AS total_tallos,
    ROUND(
        SUM(co.tallos) / b.hectareas,
        0
    ) AS tallos_por_hectarea
FROM cosecha AS co
JOIN bloque AS b
    ON b.bloque_id = co.bloque_id
JOIN variedad AS va
    ON va.variedad_id = b.variedad_id
GROUP BY
    b.bloque_id,
    va.nombre,
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
FROM inventario_movimiento_limpio AS im
JOIN cosecha AS co
    ON co.cosecha_id = im.cosecha_id
JOIN bloque AS b
    ON b.bloque_id = co.bloque_id
JOIN variedad AS va
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
-- relacionamos ambos resultados.
-- ============================================================

WITH produccion AS (
    SELECT
        va.nombre AS variedad,
        SUM(co.tallos) AS total_tallos
    FROM cosecha AS co
    JOIN bloque AS b
        ON b.bloque_id = co.bloque_id
    JOIN variedad AS va
        ON va.variedad_id = b.variedad_id
    GROUP BY va.nombre
),
merma AS (
    SELECT
        va.nombre AS variedad,
        SUM(im.cantidad) AS tallos_merma
    FROM inventario_movimiento_limpio AS im
    JOIN cosecha AS co
        ON co.cosecha_id = im.cosecha_id
    JOIN bloque AS b
        ON b.bloque_id = co.bloque_id
    JOIN variedad AS va
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


-- Resultado observado:
-- Purple Moon       → 0.71%
-- Goldfinch         → 0.68%
-- Cherry Brandy     → 0.68%
-- Jessika           → 0.67%
-- Coffee Break      → 0.67%
-- Million Star      → 0.67%
-- Green Romance     → 0.66%
--
-- Se verificó también que la fórmula necesitaba convertir
-- a numeric antes de la división para evitar división entera.


-- ============================================================
-- PREGUNTA DE NEGOCIO 7 — EN PROGRESO
-- ¿Qué clientes compraron en 2025 pero no realizaron compras
-- en 2026?
--
-- Esta pregunta se utilizó para practicar:
--   CTE + DISTINCT + LEFT JOIN + IS NULL
--
-- El dataset actualmente contiene:
--   2025 → 28 clientes
--   2026 → 28 clientes
--
-- EXCEPT confirmó que no existen clientes presentes en 2025
-- que estén ausentes en 2026.
-- Resultado: 0 clientes.
-- ============================================================

WITH clientes_2025 AS (
    SELECT DISTINCT cliente_id
    FROM venta_limpia
    WHERE fecha >= '2025-01-01'
      AND fecha < '2026-01-01'
),
clientes_2026 AS (
    SELECT DISTINCT cliente_id
    FROM venta_limpia
    WHERE fecha >= '2026-01-01'
      AND fecha <= CURRENT_DATE
)
SELECT
    c2025.cliente_id
FROM clientes_2025 AS c2025
LEFT JOIN clientes_2026 AS c2026
    ON c2025.cliente_id = c2026.cliente_id
WHERE c2026.cliente_id IS NULL;


-- Validación alternativa realizada:
--
-- SELECT DISTINCT cliente_id
-- FROM venta_limpia
-- WHERE fecha >= '2025-01-01'
--   AND fecha < '2026-01-01'
--
-- EXCEPT
--
-- SELECT DISTINCT cliente_id
-- FROM venta_limpia
-- WHERE fecha >= '2026-01-01'
--   AND fecha <= CURRENT_DATE;
--
-- Resultado: 0 filas.


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
FROM venta_limpia AS ve
JOIN cliente_limpio AS cl
    ON ve.cliente_id = cl.cliente_id
GROUP BY
    cl.cliente_id,
    cl.nombre
ORDER BY venta_total DESC;

Respuesta: 
2	Doyle Ltd	7687403.10
16	Galloway-Wyatt	7314806.53
28	Hoffman, Baker And Richards	7304880.89

18	Flowers, Martin And Kelly	6191541.51
1	Rodriguez, Figueroa And Sanchez	6072887.34
13	Arnold Ltd	6045269.07


-- ============================================================
-- NOTAS DE APRENDIZAJE DEL DÍA 5
-- ============================================================
--
-- Conceptos practicados:
--
-- 1. JOIN entre hechos y dimensiones.
-- 2. SUM() para métricas de volumen y valor.
-- 3. GROUP BY para cambiar el nivel de análisis.
-- 4. ORDER BY DESC para priorizar resultados.
-- 5. LIMIT para obtener los primeros registros.
-- 6. Precio promedio ponderado:
--      SUM(tallos * precio_tallo) / SUM(tallos)
-- 7. CTEs (WITH) para separar cálculos intermedios.
-- 8. LEFT JOIN + IS NULL para encontrar registros ausentes.
-- 9. EXCEPT para comparar conjuntos.
-- 10. Separar agregaciones antes de unirlas para evitar
--     duplicación de métricas.
--
-- El Día 5 queda incompleto deliberadamente.
-- ============================================================
