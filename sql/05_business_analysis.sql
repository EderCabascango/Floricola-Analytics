-- ============================================================
-- 🌹 FLORICOLA ANALYTICS
-- Día 5 — Business Analysis
-- PostgreSQL
--
-- Objetivo:
-- Responder preguntas de negocio utilizando las vistas limpias
-- construidas durante los Días 3 y 4.
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

-- Resultado observado:
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

-- Resultado observado:
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
-- relacionamos ambos resultados, para evitar duplicacion por
-- multiplicidad de relaciones (una cosecha puede tener varios
-- movimientos de inventario).
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
-- PREGUNTA DE NEGOCIO 7
-- ¿Qué clientes compraron en 2025 pero no realizaron compras
-- en 2026?
--
-- Practica: CTE + DISTINCT + LEFT JOIN + IS NULL
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

-- Validación alternativa realizada (mismo resultado, otra tecnica):
--
-- SELECT DISTINCT cliente_id FROM venta_limpia
-- WHERE fecha >= '2025-01-01' AND fecha < '2026-01-01'
-- EXCEPT
-- SELECT DISTINCT cliente_id FROM venta_limpia
-- WHERE fecha >= '2026-01-01' AND fecha <= CURRENT_DATE;
--
-- Resultado: 0 clientes en ambos casos.
-- 2025 → 28 clientes | 2026 → 28 clientes (los mismos 28).
--
-- Conclusion: una consulta que devuelve cero filas no es un
-- error, es un resultado valido. Aqui refleja que el simulador
-- asigna clientes de forma uniforme y sin memoria historica
-- (np.random.choice parejo entre los 28 clientes en cada venta),
-- por lo que no existe la nocion de "cliente que se va" en este
-- dataset sintetico. En datos reales, o en una version futura
-- del simulador con probabilidad de recompra ponderada, esta
-- pregunta si podria arrojar resultados.


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

-- Resultado (top 3 y otros destacados):
-- 2  | Doyle Ltd                       | 7,687,403.10
-- 16 | Galloway-Wyatt                  | 7,314,806.53
-- 28 | Hoffman, Baker And Richards     | 7,304,880.89
-- 18 | Flowers, Martin And Kelly       | 6,191,541.51
-- 1  | Rodriguez, Figueroa And Sanchez | 6,072,887.34
-- 13 | Arnold Ltd                      | 6,045,269.07


-- ============================================================
-- PREGUNTA DE NEGOCIO 9
-- ¿El precio promedio pagado por tallo varia segun el tipo
-- de cliente (Importador, Broker, Retailer)?
--
-- Se usa precio promedio PONDERADO por volumen (no un promedio
-- simple de precios), para que un cliente con pocas compras
-- caras no distorsione el resultado frente a clientes con
-- mucho volumen.
-- ============================================================

SELECT
    cl.tipo,
    COUNT(*) AS num_ventas,
    SUM(ve.tallos) AS total_tallos,
    ROUND(
        SUM(ve.tallos * ve.precio_tallo) / SUM(ve.tallos),
        2
    ) AS precio_promedio_ponderado
FROM venta_limpia AS ve
JOIN cliente_limpio AS cl
    ON ve.cliente_id = cl.cliente_id
GROUP BY cl.tipo
ORDER BY precio_promedio_ponderado DESC;

-- Resultado:
-- Broker      | 6,074 ventas | 174,173,333 tallos | $0.31 ponderado
-- Importador  | 9,068 ventas | 250,713,196 tallos | $0.31 ponderado
-- Retailer    | 6,093 ventas | 169,740,445 tallos | $0.31 ponderado
--
-- Conclusion: el precio ponderado es practicamente identico
-- entre los 3 tipos de cliente (~$0.31), lo que indica que el
-- simulador no diferencia precio por tipo de cliente — es una
-- caracteristica del diseño del generador de datos, no del
-- negocio en si.


-- ============================================================
-- PREGUNTA DE NEGOCIO 10
-- ¿Las temporadas altas (San Valentin, Dia de la Madre) venden
-- mas por semana que una semana normal?
--
-- Decision de diseño: se excluyen 2023 y 2026 del grupo "Normal"
-- porque son años parciales en el dataset (el simulador cubre
-- junio 2023 - junio 2026), lo que distorsionaria el promedio
-- semanal. San Valentin y Dia de la Madre si se calculan para
-- 2024-2026 porque esas semanas especificas estan completas
-- en los 3 años.
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
    FROM venta_limpia AS ve
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

-- Resultado:
-- San Valentin 2024: 5,314,318/semana | Dia Madre 2024: 4,563,289 | Normal 2024: 3,621,728
-- San Valentin 2025: 4,854,984/semana | Dia Madre 2025: 4,275,705 | Normal 2025: 3,644,820
-- San Valentin 2026: 4,966,996/semana | Dia Madre 2026: 4,722,383 | (Normal 2026 excluido, año parcial)
--
-- Conclusion: las temporadas altas venden entre 25% y 46% mas
-- por semana que una semana normal, confirmando el patron de
-- estacionalidad diseñado en el simulador (Dia 2).


-- ============================================================
-- PREGUNTA DE NEGOCIO 11
-- ¿Cual es la evolucion mensual de ventas a lo largo del periodo?
-- ============================================================

SELECT
    DATE_TRUNC('MONTH', fecha) AS mes,
    SUM(tallos) AS total_tallos,
    SUM(tallos::numeric * precio_tallo) AS valor_total
FROM venta_limpia
GROUP BY mes
ORDER BY mes;

-- Hallazgo:
-- El patron mensual es puramente ciclico, sin tendencia de
-- crecimiento interanual. Enero es consistentemente el mes
-- mas fuerte (~23M tallos, alineado con la rampa hacia San
-- Valentin), con un valle estable de ~14-15M/mes entre junio
-- y diciembre. Los valores de enero 2025 (22.97M) y enero 2026
-- (23.13M) son casi identicos, confirmando que el simulador no
-- incorpora una tasa de crecimiento base, solo estacionalidad.
-- Esto es una limitacion consciente del diseño del simulador
-- (Dia 2), relevante para las fases de forecasting posteriores.


-- ============================================================
-- PREGUNTA DE NEGOCIO 12
-- ¿Cual es la evolucion trimestral de ventas?
-- ============================================================

SELECT
    DATE_TRUNC('quarter', fecha) AS trimestre,
    SUM(tallos) AS total_tallos,
    SUM(tallos::numeric * precio_tallo) AS valor_total
FROM venta_limpia
GROUP BY trimestre
ORDER BY trimestre;

-- Hallazgo:
-- El patron trimestral confirma la forma de la curva anual:
-- Q1 (San Valentin) es el trimestre mas fuerte (~55-56M tallos
-- en 2024/2025/2026), seguido de Q2 (Dia de la Madre, ~51-52M),
-- y Q3/Q4 estables en un valle de ~44-46M. La comparacion entre
-- los 3 años completos confirma la ausencia de tendencia de
-- crecimiento (Q1 2024: 56.3M, Q1 2025: 55.2M, Q1 2026: 55.7M),
-- consistente con el hallazgo de la Pregunta 11.


-- ============================================================
-- PREGUNTA DE NEGOCIO 13
-- ¿Cual es la variacion trimestre-a-trimestre en valor de ventas?
-- Usa LAG() para comparar cada trimestre contra el inmediato
-- anterior.
-- ============================================================

WITH ventas_trimestre AS (
    SELECT
        DATE_TRUNC('quarter', fecha) AS trimestre,
        SUM(tallos::numeric * precio_tallo) AS valor_total
    FROM venta_limpia
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

-- Hallazgo:
-- El patron de variacion trimestre-a-trimestre se repite con
-- alta consistencia año tras año: salto fuerte positivo entrando
-- a Q1 (+2.96M a +3.3M, San Valentin), caida moderada Q1->Q2
-- (-1.26M a -1.3M), caida fuerte Q2->Q3 (-1.82M a -2.42M, fin
-- de ambas temporadas altas), y estabilidad Q3->Q4 (variacion
-- casi nula). La similitud de magnitudes entre años (ej. el
-- salto a Q1 es de ~3M en los 3 años) confirma nuevamente la
-- ausencia de tendencia de crecimiento en el dataset.


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
    FROM venta_limpia AS ve
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

-- Resultado:
-- 2024: San Valentin 5,314,318 | Dia Madre 4,563,289 | Normal 3,621,728 | Diff SV: +1,692,590 (+46.7%)
-- 2025: San Valentin 4,854,984 | Dia Madre 4,275,705 | Normal 3,644,820 | Diff SV: +1,210,164 (+33.2%)
-- 2026: San Valentin 4,966,996 | Dia Madre 4,722,383 | (Normal no calculado, año parcial)
--
-- Conclusion: confirma en formato compacto (una fila por año)
-- el hallazgo de la Pregunta 10: San Valentin genera entre 33%
-- y 47% mas ventas por semana que una semana normal.


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
-- 7. CTEs (WITH) para separar cálculos intermedios y evitar
--    duplicacion por multiplicidad de relaciones.
-- 8. LEFT JOIN + IS NULL para encontrar registros ausentes.
-- 9. EXCEPT para comparar conjuntos.
-- 10. CASE WHEN para clasificar filas en categorias (temporada).
-- 11. EXTRACT(WEEK/YEAR FROM fecha) para analisis estacional.
-- 12. DATE_TRUNC('month'/'quarter', fecha) para series de tiempo
--     reales (a diferencia de EXTRACT, conserva el año).
-- 13. LAG() OVER (ORDER BY ...) para comparar cada fila contra
--     la fila anterior (variacion periodo a periodo).
-- 14. Pivoteo de filas a columnas con SUM(CASE WHEN ... END).
-- 15. ::numeric explicito, indispensable en divisiones entre
--     enteros para evitar truncamiento (division entera).
-- 16. Regla practica: una expresion calculada con CASE WHEN,
--     LAG() o ROW_NUMBER() no puede reutilizarse en el mismo
--     nivel del SELECT donde se define; requiere un CTE adicional.
--
-- El Día 5 queda completo. Pendiente para el Día 6: RFM con
-- NTILE() antes de iniciar la fase de Power BI.
-- ============================================================