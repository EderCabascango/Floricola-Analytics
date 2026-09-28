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

Se practicó:

- `JOIN`
- `SUM`
- `GROUP BY`
- `ORDER BY DESC`

---

## 2. Variedades con mayor valor de ventas

### Pregunta de negocio

> ¿Qué variedades tienen mayor valor de ventas?

Aquí ya no basta con contar tallos. Para calcular el valor monetario de una venta:

```text
valor_venta = tallos × precio_tallo
```

Además se calculó el **precio promedio ponderado por tallos**:

```text
SUM(tallos × precio_tallo) / SUM(tallos)
```

Esto es diferente de un promedio simple de precios porque cada precio tiene asociado un volumen de tallos.

### Resultado observado

| Variedad | Tallos | Precio ponderado | Valor de ventas |
|---|---:|---:|---:|
| Orange Crush | 27,998,272 | 0.31 | 8,792,989.637 |
| Sunset Glory | 26,959,516 | 0.31 | 8,379,401.101 |
| Goldfinch | 24,402,408 | 0.32 | 7,734,789.269 |
| Freedom | 4,045,854 | 0.31 | 1,272,139.706 |
| Million Star | 8,497,369 | 0.14 | 1,168,443.042 |
| Candlelight | 3,076,682 | 0.32 | 969,180.232 |

### Aprendizaje importante

Una métrica de negocio puede requerir una fórmula y no simplemente un `SUM`.

En este caso:

```sql
SUM(tallos * precio_tallo)
```

representa el valor monetario total de las ventas.

---

## 3. Bloques con mayor producción

### Pregunta de negocio

> ¿Qué bloques tienen mayor producción?

Se utilizó la relación:

```text
cosecha → bloque → variedad
```

La métrica fue:

```sql
SUM(co.tallos)
```

Esto permite conocer qué bloques concentran mayor volumen producido.

---

## 4. Productividad por hectárea

### Pregunta de negocio

> ¿Qué bloques producen más tallos en relación con su superficie?

Aquí se agregó una dimensión que cambia la interpretación del resultado:

```text
tallos por hectárea =
producción total / hectáreas
```

La consulta relacionó:

```text
cosecha
   ↓
bloque
   ↓
variedad
```

y calculó:

```sql
ROUND(SUM(co.tallos) / b.hectareas, 0)
```

### Aprendizaje

Esto permitió distinguir entre:

- un bloque que produce mucho porque es grande
- un bloque que tiene una productividad alta en relación con su superficie

Por tanto, **volumen absoluto y productividad no son la misma métrica**.

---

## 5. Merma por variedad

### Pregunta de negocio

> ¿Qué variedades presentan mayor cantidad de tallos registrados como merma?

Se utilizó:

```text
inventario_movimiento_limpio
        ↓
cosecha
        ↓
bloque
        ↓
variedad
```

Filtrando:

```sql
WHERE im.tipo_movimiento = 'merma'
```

y calculando:

```sql
SUM(im.cantidad)
```

Esto permitió obtener los tallos registrados como merma por variedad.

---

## 6. Porcentaje de producción que termina como merma

Esta fue una de las consultas más importantes del día porque obligó a pensar en el **nivel de granularidad de los datos**.

La pregunta fue:

> ¿Qué porcentaje de la producción termina como merma?

Se construyeron dos agregaciones independientes:

### Producción

```text
variedad → producción total
```

### Merma

```text
variedad → tallos en merma
```

Después se relacionaron ambos resultados mediante un CTE.

La fórmula fue:

```text
porcentaje_merma =
(tallos_merma / total_tallos) × 100
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

No se debe hacer ingenuamente:

```text
cosecha
JOIN inventario_movimiento
```

y después sumar producción y merma en la misma consulta sin considerar la multiplicidad de las relaciones.

Una misma cosecha puede tener varios movimientos de inventario.

La estrategia utilizada fue:

```text
CTE producción
       +
CTE merma
       ↓
JOIN por variedad
```

Primero se calcula cada métrica en su propio nivel y después se relacionan los resultados.

---

## 7. Clientes que compraron en 2025 pero no en 2026

### Pregunta de negocio

> ¿Qué clientes compraron en 2025 pero no realizaron ninguna compra en 2026?

Esta pregunta permitió practicar:

- CTE
- `DISTINCT`
- `LEFT JOIN`
- `IS NULL`

La lógica conceptual fue:

```text
clientes 2025
      ↓
LEFT JOIN
      ↓
clientes 2026
      ↓
IS NULL
      ↓
clientes presentes en 2025 pero ausentes en 2026
```

### Validación de los datos

Se encontró:

```text
2025 → 28 clientes
2026 → 28 clientes
```

También se ejecutó una comparación con `EXCEPT`.

Resultado:

```text
0 clientes
```

Por lo tanto, en el dataset actual:

> Los 28 clientes que registraron compras durante 2025 también registraron compras durante 2026.

Esto es un **resultado válido del análisis**, no un error de SQL.

### Aprendizaje importante

Una consulta que devuelve cero filas no necesariamente está mal.

Primero hay que verificar si existen registros que satisfagan la condición buscada.

---

# Conceptos SQL aprendidos durante el Día 5

Durante esta sesión se practicaron:

- `JOIN`
- `LEFT JOIN`
- `GROUP BY`
- `ORDER BY`
- `LIMIT`
- `SUM`
- `ROUND`
- multiplicación dentro de agregaciones
- promedio ponderado
- CTEs mediante `WITH`
- `DISTINCT`
- `WHERE`
- `IS NULL`
- `EXCEPT`
- agregaciones separadas antes de realizar un `JOIN`

## Aprendizaje conceptual

Una de las principales lecciones del día fue que **SQL no consiste solamente en recordar sintaxis**.

Antes de escribir una consulta hay que identificar:

1. ¿Cuál es la pregunta de negocio?
2. ¿Cuál es la tabla que contiene el evento?
3. ¿Cuál es el nivel de granularidad?
4. ¿Qué dimensiones necesito para describir el resultado?
5. ¿Qué métrica debo calcular?
6. ¿Necesito agrupar?
7. ¿Puedo unir las tablas directamente o primero debo agregar cada una?

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
### Pendiente


- [ ] Otras preguntas comerciales
- [ ] Análisis temporal
- [ ] Análisis de temporadas altas
- [ ] Integración de las preguntas de negocio en un análisis final

---

## Estado del proyecto

El Día 5 queda **deliberadamente incompleto**.

No se continúa todavía con Power BI ni forecasting.

El siguiente paso será terminar el análisis de negocio en SQL y posteriormente utilizar estos resultados como base para la siguiente capa analítica del proyecto.

> **Nota:** Los resultados corresponden exclusivamente al dataset sintético generado para este proyecto y no representan datos reales de una florícola.
