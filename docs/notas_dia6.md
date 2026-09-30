# 🌹 Floricola Analytics — Bitácora Día 6

## SQL Avanzado: Segmentación RFM

El Día 6 se enfocó en una sola técnica de SQL avanzado: **segmentación de clientes con RFM** (Recency, Frequency, Monetary), usando la función de ventana `NTILE()`.

A diferencia de días anteriores, este día se trabajó con una metodología distinta: en vez de resolver preguntas de negocio nuevas, se practicó la **reconstrucción activa** de una misma consulta varias veces, con cada vez menos ayuda, hasta poder escribirla completa de memoria.

---

## ¿Qué es RFM?

RFM resume a cada cliente en 3 números comparables:

- **Recency**: ¿hace cuánto compró por última vez?
- **Frequency**: ¿cuántas veces ha comprado en total?
- **Monetary**: ¿cuánto ha gastado en total?

La idea de negocio: comparar solo `Monetary` puede ser engañoso (un cliente que gastó mucho hace mucho tiempo se vería igual de "bueno" que uno activo hoy). Combinar las 3 dimensiones da un perfil más completo de cada cliente.

Dos de las tres métricas ya estaban resueltas de forma implícita desde el Día 5: `Monetary` es la misma lógica de la Pregunta 8 (valor por cliente), y `Frequency` reutiliza el `COUNT(*)` de la Pregunta 9. La única pieza genuinamente nueva fue `Recency`.

---

## Construcción de las métricas base

```sql
WITH rfm_base AS (
    SELECT
        cliente_id,
        (SELECT MAX(fecha) FROM venta_limpia) - MAX(fecha) AS recency,
        COUNT(*) AS frequency,
        SUM(tallos::numeric * precio_tallo::numeric) AS monetary
    FROM venta_limpia
    GROUP BY cliente_id
)
```

`recency` se calcula como la diferencia, en días, entre la fecha más reciente de todo el dataset y la última compra de cada cliente. Postgres permite restar dos `DATE` directamente y obtener un número de días.

### Hallazgo importante sobre Recency

Al ejecutar esta métrica, se observó que **Recency varía muy poco entre los 28 clientes** (0 a 11 días). La causa: el simulador (`04_venta.py`) asigna un cliente al azar a cada venta de forma uniforme, sin memoria de compras pasadas. Con miles de transacciones repartidas entre solo 28 clientes, es estadísticamente casi imposible que alguno quede mucho tiempo sin comprar — el mismo fenómeno que ya se había documentado en la Pregunta 7 del Día 5 (0 clientes que compraron en 2025 y no en 2026).

Esto significa que, en este dataset sintético, la segmentación RFM termina dominada principalmente por **Frequency** y **Monetary**, no por Recency. En un dataset real, o en una versión futura del simulador con probabilidad de recompra ponderada por historial, Recency aportaría mucha más señal.

---

## `NTILE()`: la pieza nueva

`NTILE(n)` reparte las filas, ya ordenadas según un `ORDER BY`, en `n` grupos de tamaño lo más parecido posible, y le asigna a cada fila el número del grupo donde cayó.

```sql
NTILE(5) OVER (ORDER BY monetary) AS score_m
```

### Concepto clave: `NTILE` es ciego al significado del dato

`NTILE` no analiza si un valor es "bueno" o "malo" — solo reparte por **posición relativa** dentro del orden que se le dio. El sentido de negocio lo aporta quien escribe la consulta, al decidir la dirección del `ORDER BY`:

- **Monetary y Frequency**: orden ascendente (default) es suficiente, porque el cliente con el valor más alto queda naturalmente al final de la fila, en el grupo 5 (el mejor score).
- **Recency**: requiere `ORDER BY recency DESC`, porque se quiere que el cliente con **menos** días desde su última compra (el mejor) reciba el score más alto. Sin el `DESC`, el orden ascendente pondría a los mejores clientes en el grupo 1 (el peor score), invirtiendo la lógica de negocio.

También se confirmó que `NTILE` no considera la magnitud real de la diferencia entre valores — solo cuenta filas y las reparte por posición, sin importar si hay saltos grandes o pequeños entre un cliente y el siguiente.

```sql
rfm_scores AS (
    SELECT
        cliente_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS score_r,
        NTILE(5) OVER (ORDER BY frequency) AS score_f,
        NTILE(5) OVER (ORDER BY monetary) AS score_m
    FROM rfm_base
)
```

---

## Consulta final: score combinado y segmento

```sql
SELECT
    cliente_id,
    score_r,
    score_f,
    score_m,
    ROUND((score_r + score_f + score_m) / 3.0, 1) AS score_promedio,
    CASE
        WHEN (score_r + score_f + score_m) / 3.0 >= 4 THEN 'Champion'
        WHEN (score_r + score_f + score_m) / 3.0 >= 3 THEN 'Cliente valioso'
        ELSE 'En riesgo / basico'
    END AS segmento
FROM rfm_scores
ORDER BY score_promedio DESC;
```

### Resultado

De 28 clientes: **6 Champions**, **7 Clientes valiosos**, **15 En riesgo/básico**.

---

## Errores cometidos durante la práctica (y por qué valen la pena documentarlos)

La metodología del día fue reconstruir la consulta varias veces con cada vez menos ayuda, para pasar de "entender leyendo" a "poder escribir de memoria". En el proceso surgieron errores típicos, todos con valor de aprendizaje:

1. **Comas faltantes** entre columnas de un mismo `SELECT` — error mecánico recurrente al escribir de memoria bajo presión.
2. **Sintaxis de subconsulta invertida**: escribir `SELECT(MAX(fecha) FROM tabla)` en vez de `(SELECT MAX(fecha) FROM tabla)` — el paréntesis debe envolver la subconsulta completa, no pegarse a la palabra `SELECT`.
3. **`AVG()`/`SUM()` aplicado donde no correspondía**: al promediar 3 columnas de una misma fila (`score_r`, `score_f`, `score_m`), no se necesita ninguna función de agregación — esas funciones son para resumir múltiples filas, no para combinar columnas dentro de una fila. La operación correcta es aritmética simple: `(score_r + score_f + score_m) / 3.0`.
4. **Orden de operaciones sin paréntesis**: escribir `score_r + score_f + score_m / 3` sin paréntesis alrededor de la suma hace que la división se aplique solo al último término (`score_m / 3`), no a la suma completa — un error silencioso de precedencia matemática, no de sintaxis.
5. **Arrastre de nombre de variable** (el más peligroso, porque no da error): al escribir `(score_r + score_r + score_r) / 3.0` en vez de `(score_r + score_f + score_m) / 3.0`, la consulta corre sin ningún error, pero calcula un resultado incorrecto de forma silenciosa. Este tipo de bug es el más difícil de detectar porque no rompe la ejecución, solo produce un número equivocado.

### Lección general

Un error que **sí** truena (falta una coma, paréntesis mal puesto) es más fácil de corregir que un error que **no** truena pero calcula mal (arrastre de nombre de variable, función de agregación aplicada de forma incorrecta). El segundo tipo exige revisar la lógica de la fórmula con atención, no solo confiar en que "si corrió, está bien".

---

## Conceptos SQL nuevos del Día 6

- `NTILE(n) OVER (ORDER BY columna [ASC|DESC])`: reparte filas ordenadas en `n` grupos de tamaño similar.
- Diferencia entre funciones de agregación (`SUM`, `AVG`, que resumen múltiples filas) y aritmética simple entre columnas de una misma fila.
- Resta directa entre dos valores `DATE` en Postgres, para obtener una diferencia en días.
- La dirección del `ORDER BY` dentro de una función de ventana determina qué extremo de los datos recibe el mejor/peor score — depende de la semántica de negocio de cada métrica, no de una regla fija.

---

## Estado al finalizar el Día 6

- ✅ Segmentación RFM completa, documentada y guardada en `sql/03_analysis/`.
- ✅ Consulta reconstruida desde cero, sin apoyo de esqueleto, en una segunda ronda de práctica.
- ✅ Limitación del dataset sintético (poca variación en Recency) identificada y documentada.
- ⬜ Reestructuración a schemas físicos `bronze`/`silver`/`gold`: pendiente, decisión de alcance a definir.
- ⬜ Power BI: no iniciado todavía.

> **Nota:** Los resultados corresponden exclusivamente al dataset sintético generado para este proyecto y no representan datos reales de una florícola.