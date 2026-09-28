-- ============================================================
-- PREGUNTA DE NEGOCIO 1
-- ¿Qué variedades tienen mayor volumen de ventas?
-- ============================================================

SELECT
    va.nombre,
    SUM(ve.tallos) AS total_variedad
FROM venta AS ve
JOIN variedad AS va
    ON va.variedad_id = ve.variedad_id
GROUP BY va.nombre
ORDER BY total_variedad DESC;

-- Respuesta:
Top 3 variedades con mayor volumen de ventas:
1. Variedad: Orange Crush, Total de tallos vendidos: 27.998.272
2. Variedad: Sunset Glory, Total de tallos vendidos: 26.959.516
3. Variedad: Goldfinch, Total de tallos vendidos: 24.402.408

Top 3 variedades con menor volumen de ventas:
1. Variedad: Purple Moon, Total de tallos vendidos: 4.135.309
2. Variedad: Freedom, Total de tallos vendidos: 4.045.854
3. Variedad: Candlelight, Total de tallos vendidos: 3.076.682

	
-- ============================================================
-- PREGUNTA DE NEGOCIO 2
-- ¿Qué variedades tienen mayor valor de ventas?
-- ============================================================

SELECT
    va.nombre,
    SUM(ve.tallos) AS total_tallos,
    ROUND(
        SUM(ve.tallos * ve.precio_tallo) / SUM(ve.tallos),
        2
    ) AS precio_promedio_ponderado,
    SUM(ve.tallos * ve.precio_tallo) AS total_venta
FROM venta AS ve
JOIN variedad AS va
    ON va.variedad_id = ve.variedad_id
GROUP BY va.nombre
ORDER BY total_venta DESC;

-- Respuesta:
Orange Crush	27998272	0.31	8792989.637
Sunset Glory	26959516	0.31	8379401.101
Goldfinch	24402408	0.32	7734789.269
	
Freedom	4045854	0.31	1272139.706
Million Star	8497369	0.14	1168443.042
Candlelight	3076682	0.32	969180.232

-- ============================================================
-- PREGUNTA DE NEGOCIO 3
-- ¿Qué bloques producen más tallos?
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
ORDER BY total_tallos DESC
LIMIT 3;
-- Mayores productores de tallos:
36	Circus	16565618
18	Orange Crush	15978246
46	Coffee Break	15310139
-- Menores productores de tallos:
23	Hot Sauce	3405916
53	Candlelight	3412163
66	Hot Sauce	3955750

-- ============================================================
-- PREGUNTA DE NEGOCIO 4
-- ¿Qué bloques producen más tallos por hectárea?
-- ============================================================

SELECT
    b.bloque_id,
    b.hectareas, 
    SUM(co.tallos) AS total_tallos,
    ROUND (SUM(co.tallos) / b.hectareas, 0) as tallos_por_hectareas
FROM cosecha AS co
JOIN bloque AS b
    ON b.bloque_id = co.bloque_id
JOIN variedad AS va
    ON va.variedad_id = b.variedad_id
GROUP BY
    b.bloque_id,
    va.nombre,
    b.hectareas
ORDER BY tallos_por_hectareas desc
LIMIT 3;

--Respuesta:
70	6.13	14168919	2311406
12	5.85	13470079	2302578
53	1.50	3412163	2274775

-- ============================================================
-- PREGUNTA DE NEGOCIO 5
-- ¿Qué variedades tienen mayor porcentaje de merma?
-- ============================================================


WITH produccion AS (
    SELECT
        va.variedad_id,
        va.nombre AS variedad,
        SUM(co.tallos) AS total_tallos
    FROM cosecha AS co
    JOIN bloque AS b
        ON b.bloque_id = co.bloque_id
    JOIN variedad AS va
        ON va.variedad_id = b.variedad_id
    GROUP BY
        va.variedad_id,
        va.nombre
),

merma AS (
    SELECT
        va.variedad_id,
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
    GROUP BY
        va.variedad_id,
        va.nombre
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
    ON p.variedad_id = m.variedad_id
ORDER BY porcentaje_merma DESC;

Purple Moon	4540107	32200	0.71
Goldfinch	27022356	182696	0.68
Cherry Brandy	11685000	79482	0.68

Lemonade	23609061	112834	0.48
Blush	13927158	64740	0.46
Miss White	13470079	60045	0.45