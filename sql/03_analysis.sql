-- ============================================================
-- 03_analysis.sql
-- Detección y análisis de calidad de datos
-- Proyecto: Floricola Analytics
-- ============================================================


-- ============================================================
-- 1. CLIENTE
-- ============================================================

-- ------------------------------------------------------------
-- Defecto 1a: nombres con espacios sobrantes
-- ------------------------------------------------------------
SELECT
    cliente_id,
    nombre,
    LENGTH(nombre) AS largo_original
FROM cliente
WHERE nombre != TRIM(nombre);


-- ------------------------------------------------------------
-- Defecto 1b: nombres completamente en MAYÚSCULAS
-- ------------------------------------------------------------
SELECT
    cliente_id,
    nombre
FROM cliente
WHERE nombre = UPPER(nombre);


-- ------------------------------------------------------------
-- Defecto 1c: nombres completamente en minúsculas
-- ------------------------------------------------------------
SELECT
    cliente_id,
    nombre
FROM cliente
WHERE nombre = LOWER(nombre);


-- ------------------------------------------------------------
-- Defecto 2: variantes de USA en pais_destino
-- ------------------------------------------------------------
SELECT DISTINCT
    pais_destino
FROM cliente
WHERE TRIM(UPPER(pais_destino))
    IN ('USA', 'U.S.A.', 'ESTADOS UNIDOS');


-- ------------------------------------------------------------
-- Defecto 3: espacios sobrantes en tipo
-- ------------------------------------------------------------
SELECT
    cliente_id,
    tipo,
    LENGTH(tipo) AS largo_original
FROM cliente
WHERE tipo != TRIM(tipo);


-- ------------------------------------------------------------
-- Defecto 5: clientes duplicados por nombre
-- ------------------------------------------------------------
SELECT
    nombre,
    COUNT(*) AS repeticiones
FROM cliente
GROUP BY nombre
HAVING COUNT(*) > 1;



-- ============================================================
-- 2. VENTA
-- ============================================================

-- ------------------------------------------------------------
-- Defecto 4: precio_tallo NULL
-- ------------------------------------------------------------
SELECT
    venta_id,
    cliente_id,
    variedad_id,
    tallos,
    precio_tallo
FROM venta
WHERE precio_tallo IS NULL;


-- ------------------------------------------------------------
-- Defecto 4a: calcular precio promedio por variedad
-- usando únicamente precios disponibles
-- ------------------------------------------------------------
WITH promedios AS (
    SELECT
        variedad_id,
        AVG(precio_tallo) AS precio_promedio
    FROM venta
    WHERE precio_tallo IS NOT NULL
    GROUP BY variedad_id
)
SELECT
    variedad_id,
    precio_promedio
FROM promedios
ORDER BY variedad_id;


-- ------------------------------------------------------------
-- Defecto 4b: verificar que los NULL tienen
-- un precio promedio disponible para imputación
-- ------------------------------------------------------------
WITH promedios AS (
    SELECT
        variedad_id,
        AVG(precio_tallo) AS precio_promedio
    FROM venta
    WHERE precio_tallo IS NOT NULL
    GROUP BY variedad_id
)
SELECT
    v.venta_id,
    v.variedad_id,
    v.precio_tallo,
    p.precio_promedio
FROM venta v
LEFT JOIN promedios p
    ON v.variedad_id = p.variedad_id
WHERE v.precio_tallo IS NULL;


-- ------------------------------------------------------------
-- Defecto 4c: comprobar si alguna venta NULL
-- no tiene promedio disponible
-- ------------------------------------------------------------
WITH promedios AS (
    SELECT
        variedad_id,
        AVG(precio_tallo) AS precio_promedio
    FROM venta
    WHERE precio_tallo IS NOT NULL
    GROUP BY variedad_id
)
SELECT
    v.venta_id,
    v.variedad_id,
    p.precio_promedio
FROM venta v
LEFT JOIN promedios p
    ON v.variedad_id = p.variedad_id
WHERE v.precio_tallo IS NULL
  AND p.precio_promedio IS NULL;



-- ============================================================
-- 3. VALIDACIONES DE LA LIMPIEZA
-- ============================================================

-- ------------------------------------------------------------
-- Validación 1: cantidad original de ventas
-- ------------------------------------------------------------
SELECT COUNT(*) AS total_ventas_originales
FROM venta;


-- ------------------------------------------------------------
-- Validación 2: cantidad de ventas en venta_limpia
-- ------------------------------------------------------------
SELECT COUNT(*) AS total_ventas_limpias
FROM venta_limpia;


-- ------------------------------------------------------------
-- Validación 3: precios que siguen siendo NULL
-- ------------------------------------------------------------
SELECT COUNT(*) AS precios_sin_imputar
FROM venta_limpia
WHERE precio_tallo_limpio IS NULL;