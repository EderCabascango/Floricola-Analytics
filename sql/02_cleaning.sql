sql
-- ============================================================
-- FLORICOLA ANALYTICS
-- 02_cleaning.sql
--
-- Objetivo:
-- Construir la capa analítica limpia sin modificar las tablas RAW.
--
-- Reglas principales:
-- 1. Normalizar clientes.
-- 2. Identificar cliente canónico para duplicados lógicos.
-- 3. Remapear ventas al cliente canónico.
-- 4. Imputar precios de tallo NULL usando el promedio por variedad.
-- 5. Eliminar duplicados exactos de movimientos de inventario
--    mediante una regla determinista.
--
-- Las tablas RAW permanecen intactas.
-- ============================================================


-- ============================================================
-- 0. LIMPIEZA DE VISTAS PREVIAS
-- ============================================================
--
-- Se eliminan las vistas de la capa limpia para que el script
-- pueda ejecutarse nuevamente de forma reproducible.
--
-- El orden respeta las dependencias entre vistas.
-- ============================================================

DROP VIEW IF EXISTS venta_limpia;
DROP VIEW IF EXISTS cliente_limpio;
DROP VIEW IF EXISTS cliente_mapping;
DROP VIEW IF EXISTS inventario_movimiento_limpio;


-- ============================================================
-- 1. MAPEO DE CLIENTES
-- ============================================================
--
-- Problema:
-- La tabla cliente contiene nombres con diferencias de formato
-- y 5 duplicados lógicos.
--
-- Regla:
-- INITCAP(TRIM(nombre)) representa el nombre normalizado.
--
-- Para cada nombre normalizado se selecciona como cliente
-- canónico el menor cliente_id.
--
-- Ejemplo:
--
-- cliente_id | nombre
-- -----------+----------------
-- 10         | Abbott-Munoz
-- 29         |  Abbott-Munoz
--
-- Ambos quedan asociados al cliente_id 10.
-- ============================================================

CREATE VIEW cliente_mapping AS

WITH canonicos AS (

    SELECT
        INITCAP(TRIM(nombre)) AS nombre_limpio,
        MIN(cliente_id) AS cliente_id_canonico

    FROM cliente

    GROUP BY
        INITCAP(TRIM(nombre))
)

SELECT
    c.cliente_id,
    INITCAP(TRIM(c.nombre)) AS nombre_limpio,
    ca.cliente_id_canonico

FROM cliente AS c

INNER JOIN canonicos AS ca
    ON INITCAP(TRIM(c.nombre)) = ca.nombre_limpio;


-- ============================================================
-- 2. CLIENTE LIMPIO
-- ============================================================
--
-- Se conservan únicamente los registros canónicos.
--
-- Transformaciones:
--   nombre       -> TRIM + INITCAP
--   pais_destino -> TRIM + UPPER
--   tipo         -> TRIM
--
-- Resultado esperado:
--   33 clientes RAW
--   28 clientes canónicos
-- ============================================================

CREATE VIEW cliente_limpio AS

SELECT
    c.cliente_id,

    INITCAP(TRIM(c.nombre)) AS nombre,

    TRIM(UPPER(c.pais_destino)) AS pais_destino,

    TRIM(c.tipo) AS tipo

FROM cliente AS c

INNER JOIN cliente_mapping AS m
    ON c.cliente_id = m.cliente_id

WHERE c.cliente_id = m.cliente_id_canonico;


-- ============================================================
-- 3. VENTA LIMPIA
-- ============================================================
--
-- Problemas:
--
-- A. Algunas ventas apuntan a clientes duplicados.
--
-- B. Existen 419 registros con precio_tallo NULL.
--
-- Regla para precio:
-- Se calcula el promedio de precio_tallo disponible
-- para cada variedad.
--
-- Los NULL se reemplazan utilizando COALESCE().
--
-- Importante:
-- No se eliminan ventas.
-- Se conservan las 21,235 filas originales.
-- ============================================================

CREATE VIEW venta_limpia AS

WITH promedios AS (

    SELECT
        variedad_id,
        AVG(precio_tallo) AS precio_promedio

    FROM venta

    WHERE precio_tallo IS NOT NULL

    GROUP BY
        variedad_id
)

SELECT
    v.venta_id,

    v.fecha,

    m.cliente_id_canonico AS cliente_id,

    v.variedad_id,

    v.tallos,

    ROUND(
        COALESCE(
            v.precio_tallo,
            p.precio_promedio
        ),
        2
    ) AS precio_tallo

FROM venta AS v

LEFT JOIN cliente_mapping AS m
    ON v.cliente_id = m.cliente_id

LEFT JOIN promedios AS p
    ON v.variedad_id = p.variedad_id;


-- ============================================================
-- 4. INVENTARIO MOVIMIENTO LIMPIO
-- ============================================================
--
-- Problema:
-- Se encontró un duplicado exacto en inventario_movimiento.
--
-- Campos utilizados para identificar duplicados:
--
--   fecha
--   cuarto_frio_id
--   cosecha_id
--   tipo_movimiento
--   cantidad
--
-- Regla:
-- ROW_NUMBER() ordenado por movimiento_id.
--
-- Se conserva únicamente numero_fila = 1.
--
-- Esto mantiene el primer registro y elimina únicamente
-- las repeticiones posteriores.
--
-- Resultado:
--   RAW    = 91,832
--   LIMPIO = 91,831
-- ============================================================

CREATE VIEW inventario_movimiento_limpio AS

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

    FROM inventario_movimiento
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


-- ============================================================
-- 5. VALIDACIONES FINALES
-- ============================================================
--
-- Estas consultas no modifican datos.
-- Sirven para comprobar que las vistas limpias cumplen
-- las reglas establecidas.
-- ============================================================


-- ------------------------------------------------------------
-- 5.1 Cantidad de clientes limpios
-- Esperado: 28
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS clientes_limpios
FROM cliente_limpio;


-- ------------------------------------------------------------
-- 5.2 Cantidad de ventas limpias
-- Esperado: 21,235
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ventas_limpias
FROM venta_limpia;


-- ------------------------------------------------------------
-- 5.3 Ventas con precio NULL
-- Esperado: 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ventas_sin_precio
FROM venta_limpia
WHERE precio_tallo IS NULL;


-- ------------------------------------------------------------
-- 5.4 Ventas sin cliente canónico
-- Esperado: 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS ventas_sin_cliente
FROM venta_limpia
WHERE cliente_id IS NULL;


-- ------------------------------------------------------------
-- 5.5 Cantidad de movimientos limpios
-- Esperado: 91,831
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS movimientos_limpios
FROM inventario_movimiento_limpio;


-- ------------------------------------------------------------
-- 5.6 Duplicados restantes en inventario
-- Esperado: 0 filas
-- ------------------------------------------------------------

SELECT
    fecha,
    cuarto_frio_id,
    cosecha_id,
    tipo_movimiento,
    cantidad,
    COUNT(*) AS repeticiones

FROM inventario_movimiento_limpio

GROUP BY
    fecha,
    cuarto_frio_id,
    cosecha_id,
    tipo_movimiento,
    cantidad

HAVING COUNT(*) > 1;


-- ------------------------------------------------------------
-- 5.7 Duplicados lógicos restantes en clientes
-- Esperado: 0 filas
-- ------------------------------------------------------------

SELECT
    INITCAP(TRIM(nombre)) AS nombre_normalizado,
    COUNT(*) AS cantidad

FROM cliente_limpio

GROUP BY
    INITCAP(TRIM(nombre))

HAVING COUNT(*) > 1;

