# 🌹 Floricola Analytics — Bitácora Día 5

## Business Analysis con SQL

El Día 5 marca el paso desde **Data Cleaning** hacia **Business Analysis**.

Durante los Días 3 y 4 el objetivo fue responder:

> ¿Los datos están limpios y son confiables para analizarlos?

En el Día 5 empezamos a responder:

> ¿Qué nos dicen estos datos sobre el negocio?

El análisis se realiza sobre las vistas limpias construidas anteriormente, principalmente:

- `cliente_limpio`
- `venta_limpia`
- `inventario_movimiento_limpio`

---

## 1. Variedades con mayor volumen de ventas

### Pregunta de negocio

> ¿Qué variedades tienen mayor volumen de ventas?

Se relacionó `venta_limpia` con `variedad` y se agrupó por variedad.

La métrica utilizada fue:

```text
SUM(tallos)
```

### Resultado observado

| Posición | Variedad | Tallos vendidos |
|---:|---|---:|
| 1 | Orange Crush | 27,998,272 |
| 2 | Sunset Glory | 26,959,516 |
| 3 | Goldfinch | 24,402,408 |

Entre las de menor volumen observado:

| Variedad | Tallos vendidos |
|---|---:|
| Purple Moon | 4,135,309 |
| Freedom | 4,045,854 |
| Candlelight | 3,076,682 |

### Aprendizaje SQL

Se practicó: `JOIN`, `SUM`, `GROUP BY`, `ORDER BY DESC`.

---

## 2. Variedades con mayor valor de ventas

### Pregunta de negocio

> ¿Qué variedades tienen mayor valor de ventas?

Para calcular el valor monetario de una venta:

```text
valor_venta = tallos × precio_tallo
```

Además se calculó el **precio promedio ponderado por tallos**:

```text
SUM(tallos × precio_tallo) / SUM(tallos)
```

Esto es diferente de un promedio simple de precios porque cada precio tiene asociado un volumen de tallos distinto.

### Resultado observado

| Variedad | Tallos | Precio ponderado | Valor de ventas |
|---|---:|---:|---:|
| Orange Crush | 27,998,272 | 0.31 | 8,792,989.64 |
| Sunset Glory | 26,959,516 | 0.31 | 8,379,401.10 |
| Goldfinch | 24,402,408 | 0.32 | 7,734,789.27 |
| Freedom | 4,045,854 | 0.31 | 1,272,139.71 |
| Million Star | 8,497,369 | 0.14 | 1,168,443.04 |
| Candlelight | 3,076,682 | 0.32 | 969,180.23 |

### Aprendizaje importante

Una métrica de negocio puede requerir una fórmula y no simplemente un `SUM`. `SUM(tallos * precio_tallo)` representa el valor monetario total de las ventas, distinto del volumen físico.

---

## 3. Bloques con mayor producción

### Pregunta de negocio

> ¿Qué bloques tienen mayor producción?

Se utilizó la relación `cosecha → bloque → variedad`, con la métrica `SUM(co.tallos)`. Esto permite conocer qué bloques concentran mayor volumen producido.

---

## 4. Productividad por hectárea

### Pregunta de negocio

> ¿Qué bloques producen más tallos en relación con su superficie?

Se agregó una dimensión que cambia la interpretación del resultado:

```text
tallos_por_hectarea = produccion_total / hectareas
```

### Aprendizaje

Esto permitió distinguir entre un bloque que produce mucho porque es grande, y un bloque con productividad alta en relación a su superficie. **Volumen absoluto y productividad no son la misma métrica.**

---

## 5. Merma por variedad

### Pregunta de negocio

> ¿Qué variedades presentan mayor cantidad de tallos registrados como merma?

Se utilizó la relación `inventario_movimiento_limpio → cosecha → bloque → variedad`, filtrando `WHERE tipo_movimiento = 'merma'` y agregando con `SUM(cantidad)`.

---

## 6. Porcentaje de producción que termina como merma

Una de las consultas más importantes del día, porque obligó a pensar en el **nivel de granularidad de los datos**.

Se construyeron dos agregaciones independientes (producción por variedad, y merma por variedad) y se relacionaron mediante un CTE:

```text
porcentaje_merma = (tallos_merma / total_tallos) × 100
```

### Resultado observado

| Variedad | Producción | Merma | % merma |
|---|---:|---:|---:|
| Purple Moon | 4,540,107 | 32,200 | 0.71% |
| Goldfinch | 27,022,356 | 182,696 | 0.68% |
| Cherry Brandy | 11,685,000 | 79,482 | 0.68% |
| Jessika | 14,918,346 | 99,332 | 0.67% |
| Coffee Break | 15,310,139 | 102,726 | 0.67% |
| Million Star | 9,413,560 | 63,215 | 0.67% |
| Green Romance | 17,920,132 | 117,863 | 0.66% |

### Lección importante: evitar duplicación

No se debe hacer ingenuamente `cosecha JOIN inventario_movimiento` y sumar producción y merma en la misma consulta, sin considerar la multiplicidad de las relaciones — una misma cosecha puede tener varios movimientos de inventario, lo que infla el `SUM` por duplicación de filas. La estrategia correcta: calcular cada métrica en su propio CTE, y relacionar los resultados ya agregados.

### Nota técnica adicional

Esta consulta requirió `::numeric` explícito antes de la división (`m.tallos_merma::numeric / p.total_tallos`), porque ambos operandos son sumas de columnas `integer`; sin el cast, Postgres hace división entera y trunca el resultado a 0.

---

## 7. Clientes que compraron en 2025 pero no en 2026

### Pregunta de negocio

> ¿Qué clientes compraron en 2025 pero no realizaron ninguna compra en 2026?

Practicó: CTE, `DISTINCT`, `LEFT JOIN`, `IS NULL`.

```text
clientes_2025 → LEFT JOIN → clientes_2026 → WHERE IS NULL
→ clientes presentes en 2025 pero ausentes en 2026
```

### Validación de los datos

```text
2025 → 28 clientes
2026 → 28 clientes
```

Se confirmó el resultado con una segunda técnica (`EXCEPT`), obteniendo el mismo resultado: **0 clientes**.

### Aprendizaje importante

Una consulta que devuelve cero filas no necesariamente está mal — primero hay que verificar si existen registros que satisfagan la condición buscada.

En este caso, el resultado de 0 clientes tiene una explicación de fondo: el simulador (`04_venta.py`) asigna clientes a cada venta con `np.random.choice()` de forma uniforme, sin memoria histórica de compras pasadas. Con miles de transacciones por año repartidas entre solo 28 clientes, la probabilidad de que alguno quede completamente fuera de un año es prácticamente nula por pura estadística. Esto no refleja necesariamente un comportamiento de retención realista; en datos reales, o en una versión futura del simulador con probabilidad de recompra ponderada por historial, esta pregunta sí sería reveladora.

---

## 8. Clientes con mayor valor de ventas

### Pregunta de negocio

> ¿Qué clientes generaron mayor valor de ventas?

Se usó `cliente_limpio` (no `cliente` cruda), para asegurar que el análisis parta de datos ya deduplicados y normalizados, con el `cliente_id` remapeado a su versión canónica.

### Resultado observado (top y otros destacados)

| cliente_id | Nombre | Venta total |
|---:|---|---:|
| 2 | Doyle Ltd | 7,687,403.10 |
| 16 | Galloway-Wyatt | 7,314,806.53 |
| 28 | Hoffman, Baker And Richards | 7,304,880.89 |
| 18 | Flowers, Martin And Kelly | 6,191,541.51 |
| 1 | Rodriguez, Figueroa And Sanchez | 6,072,887.34 |
| 13 | Arnold Ltd | 6,045,269.07 |

---

## 9. Precio promedio ponderado por tipo de cliente

### Pregunta de negocio

> ¿El precio promedio pagado por tallo varía según el tipo de cliente (Importador, Broker, Retailer)?

Se usó precio promedio **ponderado** por volumen, no un promedio simple de precios, para que un cliente con pocas compras caras no distorsione el resultado frente a clientes con mucho volumen.

### Resultado observado

| Tipo | Núm. ventas | Total tallos | Precio ponderado |
|---|---:|---:|---:|
| Broker | 6,074 | 174,173,333 | $0.31 |
| Importador | 9,068 | 250,713,196 | $0.31 |
| Retailer | 6,093 | 169,740,445 | $0.31 |

### Hallazgo

El precio ponderado es prácticamente idéntico entre los 3 tipos de cliente. Esto indica que el simulador no introdujo una diferenciación de precio por tipo de cliente — es una característica del diseño del generador de datos (Día 3), no un patrón de negocio a interpretar.

### Corrección durante la sesión

El primer intento de esta consulta usó `JOIN cliente` (la tabla cruda) en vez de `cliente_limpio`. Aunque no producía error (los `cliente_id` de `venta_limpia` ya están remapeados a IDs canónicos, un subconjunto de la tabla cruda), rompía la disciplina de trabajar siempre sobre vistas limpias, y exponía el riesgo de agrupar por un `tipo` con espacios sobrantes sin notarlo.

---

## 10. Estacionalidad: ¿las temporadas altas venden más por semana?

### Pregunta de negocio

> ¿Las temporadas altas (San Valentín, Día de la Madre) venden más por semana que una semana normal?

### Primer intento (y por qué fue insuficiente)

La primera versión comparó **totales acumulados** por temporada, sumando los 3 años juntos. Esto dio un resultado con un sesgo evidente: "Normal" acumula ~44 semanas/año mientras que cada temporada especial solo ~4 semanas/año, así que comparar totales favorece artificialmente a "Normal" solo por tener más semanas sumadas.

### Corrección: comparación año por año

Se identificó que **2023 y 2026 son años parciales** en el dataset (el simulador cubre junio 2023 – junio 2026), lo que distorsiona cualquier promedio de "Normal" calculado sobre esos años. Se decidió:

- **Normal**: calcular solo con 2024 y 2025 (años completos)
- **San Valentín / Día de la Madre**: calcular con 2024, 2025 y 2026, porque esas semanas específicas sí están completas en los 3 años

El divisor usado fue el número real de semanas por temporada en un año individual: **4** para San Valentín o Día de la Madre, **44** para Normal (52 − 4 − 4).

### Resultado

| Temporada | 2024 (tallos/semana) | 2025 (tallos/semana) | 2026 (tallos/semana) |
|---|---:|---:|---:|
| San Valentín | 5,314,318 | 4,854,984 | 4,966,996 |
| Día de la Madre | 4,563,289 | 4,275,705 | 4,722,383 |
| Normal | 3,621,728 | 3,644,820 | — (año parcial, excluido) |

### Conclusión

Las temporadas altas venden entre **25% y 46% más por semana** que una semana normal, confirmando el patrón de estacionalidad diseñado en el simulador (Día 2). Este hallazgo fue validado también en formato pivote (una fila por año, ver punto 14).

### Aprendizaje importante

Este fue el ejercicio más rico en pensamiento crítico del día: la primera versión de la consulta era sintácticamente correcta pero **conceptualmente engañosa**. Detectar que comparar totales acumulados con distinto número de semanas por grupo era injusto, y decidir excluir años parciales, fue un paso de diseño analítico, no de sintaxis SQL.

---

## 11. Evolución mensual de ventas

### Pregunta de negocio

> ¿Cuál es la evolución mensual de ventas a lo largo del periodo?

Se usó `DATE_TRUNC('month', fecha)`, que a diferencia de `EXTRACT(MONTH FROM fecha)` conserva el año, dando una fila real por cada mes-año en vez de mezclar "todos los eneros" en un solo grupo.

### Hallazgo

El patrón mensual es puramente cíclico, **sin tendencia de crecimiento interanual**. Enero es consistentemente el mes más fuerte (~23M tallos, la rampa hacia San Valentín), con un valle estable de ~14-15M/mes entre junio y diciembre. Los valores de enero 2025 (22.97M) y enero 2026 (23.13M) son casi idénticos, confirmando que el simulador no incorpora una tasa de crecimiento base, solo estacionalidad.

Esta es una limitación consciente del diseño del simulador (Día 2): la producción base de cada bloque se calculó una sola vez, sin ningún componente de crecimiento año a año. Es relevante tenerlo presente para las fases de forecasting posteriores.

---

## 12. Evolución trimestral de ventas

### Pregunta de negocio

> ¿Cuál es la evolución trimestral de ventas?

Usando `DATE_TRUNC('quarter', fecha)`, se obtiene una vista más suavizada que la mensual, útil para un dashboard ejecutivo.

### Hallazgo

El patrón trimestral confirma la forma de la curva anual: **Q1** (San Valentín) es el trimestre más fuerte (~55-56M tallos en 2024/2025/2026), seguido de **Q2** (Día de la Madre, ~51-52M), y **Q3/Q4** estables en un valle de ~44-46M. La comparación entre los 3 años completos (Q1 2024: 56.3M, Q1 2025: 55.2M, Q1 2026: 55.7M) confirma nuevamente la ausencia de tendencia de crecimiento, consistente con el hallazgo del punto 11.

---

## 13. Variación trimestre a trimestre con `LAG()`

### Pregunta de negocio

> ¿Cuál es la variación trimestre-a-trimestre en valor de ventas?

Se introdujo `LAG(valor_total) OVER (ORDER BY trimestre)`, una función de ventana que permite comparar cada fila contra la fila inmediatamente anterior según un orden dado, sin necesidad de un self-join manual.

### Error encontrado y su causa

El primer intento intentó calcular la diferencia (`valor_total - valor_anterior`) reutilizando el alias `valor_anterior` **dentro del mismo `SELECT`** donde se definía con `LAG()`. Esto produjo el error `column "valor_anterior" does not exist`, porque en Postgres los alias de un `SELECT` no están disponibles para otras expresiones del mismo nivel. La solución fue envolver el cálculo de `LAG()` en un CTE adicional, y hacer la resta en el `SELECT` externo, donde la columna ya existe como tal.

### Resultado

El patrón de variación trimestre-a-trimestre se repite con alta consistencia año tras año: salto fuerte positivo entrando a Q1 (+2.96M a +3.3M, San Valentín), caída moderada Q1→Q2 (-1.26M a -1.3M), caída fuerte Q2→Q3 (-1.82M a -2.42M, fin de ambas temporadas altas), y estabilidad Q3→Q4 (variación casi nula). La similitud de magnitudes entre años confirma nuevamente la ausencia de tendencia de crecimiento en el dataset.

---

## 14. Diferencia de temporadas en formato pivote

### Pregunta de negocio

> ¿Cómo se ve, en una sola fila por año, la diferencia de promedio semanal entre cada temporada alta y una semana normal?

Se usó la técnica de **pivoteo con `SUM(CASE WHEN ... END)`**: en vez de una fila por año-temporada (formato "largo"), se agrupó solo por año, y cada columna de temporada se calculó sumando condicionalmente solo las filas que correspondían a esa temporada, ignorando las demás (al no cumplir la condición del `CASE`, `SUM` las trata como si no existieran).

### Resultado

| Año | San Valentín | Día Madre | Normal | Diff SV vs Normal |
|---|---:|---:|---:|---:|
| 2024 | 5,314,318 | 4,563,289 | 3,621,728 | +1,692,590 (+46.7%) |
| 2025 | 4,854,984 | 4,275,705 | 3,644,820 | +1,210,164 (+33.2%) |
| 2026 | 4,966,996 | 4,722,383 | — (año parcial) | — |

### Conclusión

Confirma, en un formato mucho más legible (una fila por año), el hallazgo del punto 10: San Valentín genera entre 33% y 47% más ventas por semana que una semana normal.

---

# Conceptos SQL aprendidos durante el Día 5

- `JOIN`, `LEFT JOIN`
- `GROUP BY`, `ORDER BY`, `LIMIT`
- `SUM`, `COUNT`, `ROUND`
- Multiplicación dentro de agregaciones, promedio ponderado
- CTEs mediante `WITH`, incluyendo CTEs encadenados/anidados
- `DISTINCT`, `WHERE`, `IS NULL`, `EXCEPT`
- Agregaciones separadas antes de un `JOIN`, para evitar duplicación por multiplicidad de relaciones
- `CASE WHEN` para clasificar filas en categorías, y para pivotear filas a columnas
- `EXTRACT(WEEK/YEAR FROM fecha)` para análisis estacional recurrente
- `DATE_TRUNC('month'/'quarter', fecha)` para series de tiempo reales que conservan el año
- `LAG() OVER (ORDER BY ...)` para comparar cada fila contra la anterior
- `::numeric` explícito, indispensable en divisiones entre enteros para evitar truncamiento

## Aprendizaje conceptual

Una de las principales lecciones del día fue que **SQL no consiste solamente en recordar sintaxis**. Antes de escribir una consulta hay que identificar:

1. ¿Cuál es la pregunta de negocio?
2. ¿Cuál es la tabla que contiene el evento?
3. ¿Cuál es el nivel de granularidad?
4. ¿Qué dimensiones necesito para describir el resultado?
5. ¿Qué métrica debo calcular?
6. ¿Necesito agrupar?
7. ¿Puedo unir las tablas directamente o primero debo agregar cada una por separado?
8. ¿La comparación que estoy haciendo es justa, o un grupo tiene una ventaja estructural sobre otro (como más semanas acumuladas)?

También se estableció una regla técnica recurrente: **una expresión calculada con `CASE WHEN`, `LAG()` o `ROW_NUMBER()` no puede reutilizarse en el mismo nivel del `SELECT` donde se define** — requiere un CTE adicional para "materializarla" antes de usarla en otro cálculo.

---

# Estado del Día 5

### Completado

- [x] Volumen de ventas por variedad
- [x] Valor de ventas por variedad
- [x] Precio promedio ponderado
- [x] Producción por bloque
- [x] Productividad por hectárea
- [x] Merma por variedad
- [x] Porcentaje de merma por variedad
- [x] Análisis de clientes 2025 vs 2026
- [x] Valor de ventas por cliente
- [x] Precio promedio por tipo de cliente
- [x] Estacionalidad: temporada alta vs normal (con comparación justa por año)
- [x] Evolución mensual de ventas
- [x] Evolución trimestral de ventas
- [x] Variación trimestre a trimestre con `LAG()`
- [x] Pivoteo de temporadas en formato ancho

### Pendiente (Día 6)

- [ ] Segmentación de clientes con RFM (`NTILE()`)

---

## Estado del proyecto

El Día 5 queda **completo**. El Día 6 cubrirá una técnica puntual de SQL avanzado (RFM con `NTILE()`) antes de iniciar la fase de Power BI.

> **Nota:** Los resultados corresponden exclusivamente al dataset sintético generado para este proyecto y no representan datos reales de una florícola.