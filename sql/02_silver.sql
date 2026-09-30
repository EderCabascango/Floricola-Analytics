-- ============================================================
-- 🌹 FLORICOLA ANALYTICS
-- Capa Silver (Clean / Conforme / Calidad de Datos)
-- PostgreSQL 16
--
-- Objetivo:
-- Transformar los datos crudos de Bronze aplicando reglas de calidad:
-- 1. Normalizacion y deduplicacion de clientes (cliente_mapping / dim_cliente).
-- 2. Imputacion de precios NULL por variedad en ventas (fct_venta).
-- 3. Deduplicacion determinista con ROW_NUMBER en inventarios (fct_inventario_movimiento).
-- 4. Dimensiones y tablas de hechos estandarizadas y listas para analitica.
-- ============================================================

-- 1. Limpieza de vistas previas en silver
DROP VIEW IF EXISTS silver.fct_despacho CASCADE;
DROP VIEW IF EXISTS silver.fct_inventario_movimiento CASCADE;
DROP VIEW IF EXISTS silver.fct_venta CASCADE;
DROP VIEW IF EXISTS silver.fct_cosecha CASCADE;
DROP VIEW IF EXISTS silver.dim_bloque CASCADE;
DROP VIEW IF EXISTS silver.dim_cuarto_frio CASCADE;
DROP VIEW IF EXISTS silver.dim_aerolinea CASCADE;
DROP VIEW IF EXISTS silver.dim_agencia_carga CASCADE;
DROP VIEW IF EXISTS silver.dim_variedad CASCADE;
DROP VIEW IF EXISTS silver.dim_cliente CASCADE;
DROP VIEW IF EXISTS silver.cliente_mapping CASCADE;

-- ============================================================
-- 2. MAPEO Y DEDUPLICACION DE CLIENTES
-- ============================================================

CREATE OR REPLACE VIEW silver.cliente_mapping AS
WITH canonicos AS (
    SELECT
        INITCAP(TRIM(nombre)) AS nombre_limpio,
        MIN(cliente_id) AS cliente_id_canonico
    FROM bronze.cliente
    GROUP BY INITCAP(TRIM(nombre))
)
SELECT
    c.cliente_id,
    INITCAP(TRIM(c.nombre)) AS nombre_limpio,
    ca.cliente_id_canonico
FROM bronze.cliente AS c
INNER JOIN canonicos AS ca
    ON INITCAP(TRIM(c.nombre)) = ca.nombre_limpio;

-- Dimension de clientes limpia y deduplicada (28 clientes canonicos)
CREATE OR REPLACE VIEW silver.dim_cliente AS
SELECT
    c.cliente_id,
    INITCAP(TRIM(c.nombre)) AS nombre,
    TRIM(UPPER(c.pais_destino)) AS pais_destino,
    TRIM(c.tipo) AS tipo
FROM bronze.cliente AS c
INNER JOIN silver.cliente_mapping AS m
    ON c.cliente_id = m.cliente_id
WHERE c.cliente_id = m.cliente_id_canonico;

-- ============================================================
-- 3. OTRAS DIMENSIONES LIMPIAS
-- ============================================================

-- Dimension variedad
CREATE OR REPLACE VIEW silver.dim_variedad AS
SELECT
    variedad_id,
    TRIM(nombre) AS nombre,
    TRIM(tipo) AS tipo,
    TRIM(color) AS color
FROM bronze.variedad;

-- Dimension bloque (enriquecida con informacion de la variedad)
CREATE OR REPLACE VIEW silver.dim_bloque AS
SELECT
    b.bloque_id,
    TRIM(b.codigo) AS codigo_bloque,
    b.hectareas,
    b.variedad_id,
    v.nombre AS variedad_nombre,
    v.tipo AS variedad_tipo,
    v.color AS variedad_color
FROM bronze.bloque b
JOIN silver.dim_variedad v ON b.variedad_id = v.variedad_id;

-- Dimension cuarto frio
CREATE OR REPLACE VIEW silver.dim_cuarto_frio AS
SELECT
    cuarto_frio_id,
    TRIM(codigo) AS codigo,
    temperatura_objetivo,
    capacidad_cajas
FROM bronze.cuarto_frio;

-- Dimension aerolinea
CREATE OR REPLACE VIEW silver.dim_aerolinea AS
SELECT
    aerolinea_id,
    TRIM(nombre) AS nombre,
    TRIM(codigo_iata) AS codigo_iata
FROM bronze.aerolinea;

-- Dimension agencia de carga
CREATE OR REPLACE VIEW silver.dim_agencia_carga AS
SELECT
    agencia_carga_id,
    TRIM(nombre) AS nombre,
    TRIM(pais) AS pais
FROM bronze.agencia_carga;

-- ============================================================
-- 4. TABLAS DE HECHOS LIMPIAS Y CONFORMES
-- ============================================================

-- Hecho Cosecha
CREATE OR REPLACE VIEW silver.fct_cosecha AS
SELECT
    cosecha_id,
    fecha,
    bloque_id,
    tallos,
    grado_calidad,
    largo_cm
FROM bronze.cosecha;

-- Hecho Inventario Movimiento (Deduplicado con ROW_NUMBER)
CREATE OR REPLACE VIEW silver.fct_inventario_movimiento AS
WITH movimientos_numerados AS (
    SELECT
        movimiento_id,
        fecha,
        cuarto_frio_id,
        cosecha_id,
        tipo_movimiento,
        cantidad,
        ROW_NUMBER() OVER (
            PARTITION BY
                fecha,
                cuarto_frio_id,
                cosecha_id,
                tipo_movimiento,
                cantidad
            ORDER BY
                movimiento_id
        ) AS numero_fila
    FROM bronze.inventario_movimiento
)
SELECT
    movimiento_id,
    fecha,
    cuarto_frio_id,
    cosecha_id,
    tipo_movimiento,
    cantidad
FROM movimientos_numerados
WHERE numero_fila = 1;

-- Hecho Venta (Imputado de precios NULL y remapeo de clientes canonicos)
CREATE OR REPLACE VIEW silver.fct_venta AS
WITH promedios AS (
    SELECT
        variedad_id,
        AVG(precio_tallo) AS precio_promedio
    FROM bronze.venta
    WHERE precio_tallo IS NOT NULL
    GROUP BY variedad_id
)
SELECT
    v.venta_id,
    v.fecha,
    m.cliente_id_canonico AS cliente_id,
    v.variedad_id,
    v.empaque,
    v.tallos,
    ROUND(
        COALESCE(v.precio_tallo, p.precio_promedio),
        2
    ) AS precio_tallo,
    ROUND(
        (v.tallos::numeric * COALESCE(v.precio_tallo, p.precio_promedio)),
        2
    ) AS valor_total
FROM bronze.venta AS v
LEFT JOIN silver.cliente_mapping AS m
    ON v.cliente_id = m.cliente_id
LEFT JOIN promedios AS p
    ON v.variedad_id = p.variedad_id;

-- Hecho Despacho
CREATE OR REPLACE VIEW silver.fct_despacho AS
SELECT
    despacho_id,
    fecha,
    venta_id,
    aerolinea_id,
    agencia_carga_id,
    awb,
    peso_kg
FROM bronze.despacho;
