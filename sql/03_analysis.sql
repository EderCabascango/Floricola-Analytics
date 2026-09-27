-- ============================================================
-- 00_deteccion_suciedad.sql
-- Consultas para detectar los defectos intencionales del dataset
-- ============================================================

-- Defecto 1a: nombres con espacios sobrantes al inicio/final
SELECT cliente_id, nombre, LENGTH(nombre) AS largo_original
FROM cliente
WHERE nombre != TRIM(nombre);

-- Defecto 1b: nombres completamente en MAYUSCULAS
SELECT cliente_id, nombre
FROM cliente
WHERE nombre = UPPER(nombre);

-- Defecto 1c: nombres completamente en minusculas
SELECT cliente_id, nombre
FROM cliente
WHERE nombre = LOWER(nombre);

-- Defecto 2: pais_destino con variantes de "USA" (mayusculas, espacios, puntos)
SELECT DISTINCT pais_destino
FROM cliente
WHERE TRIM(UPPER(pais_destino)) IN ('USA', 'U.S.A.', 'ESTADOS UNIDOS');

-- Defecto 3: tipo con espacios sobrantes (rompe el CHECK constraint original)
SELECT cliente_id, tipo, LENGTH(tipo) AS largo_original
FROM cliente
WHERE tipo != TRIM(tipo);

-- Defecto 4: precio_tallo nulo en venta (~2% de las filas)
SELECT venta_id, cliente_id, variedad_id, tallos, precio_tallo
FROM venta
WHERE precio_tallo IS NULL;

-- Defecto 5: clientes duplicados (mismo nombre, distinto cliente_id)
SELECT nombre, COUNT(*) AS repeticiones
FROM cliente
GROUP BY nombre
HAVING COUNT(*) > 1;

