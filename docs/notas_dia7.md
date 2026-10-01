# 🌹 Floricola Analytics — Bitácora Día 7

## Power BI: Conexión, Modelo de Datos y Medidas de Tiempo

El Día 7 se enfocó en construir la base técnica del dashboard: conexión a la base de datos, modelo de datos en estrella, y las primeras medidas DAX, incluyendo inteligencia de tiempo (YoY, MoM).

---

## Conexión a PostgreSQL

Power BI Desktop se conectó directo a Postgres (`localhost:5433`, base `floricola`) usando el conector nativo **PostgreSQL database**, en modo **Import**. La conexión funcionó sin necesidad de instalar drivers adicionales.

Se importaron únicamente las 5 vistas del schema `gold.*` — no `bronze.*` ni `silver.*`, ya que `gold` es la capa diseñada específicamente para consumo analítico:

- `gold.dm_ventas_mensual`
- `gold.dm_estacionalidad_semanal`
- `gold.dm_rendimiento_campo`
- `gold.dm_cliente_rfm`
- `gold.feat_demanda_forecasting`

---

## Construcción de `Dim_Date`

Se creó una tabla de calendario con DAX, cubriendo todo el rango del dataset (junio 2023 - junio 2026):

```dax
Dim_Date =
VAR FechaInicio = DATE(2023, 6, 1)
VAR FechaFin = DATE(2026, 6, 30)
RETURN
ADDCOLUMNS(
    CALENDAR(FechaInicio, FechaFin),
    "Anio", YEAR([Date]),
    "NumeroMes", MONTH([Date]),
    "NombreMes", FORMAT([Date], "MMMM"),
    "NombreMesCorto", FORMAT([Date], "MMM"),
    "Trimestre", "Q" & FORMAT([Date], "Q"),
    "SemanaISO", WEEKNUM([Date], 2),
    "DiaSemana", FORMAT([Date], "dddd"),
    "AnioMes", FORMAT([Date], "YYYY-MM")
)
```

### Por qué es necesaria

Las funciones de inteligencia de tiempo de DAX (`SAMEPERIODLASTYEAR`, `DATEADD`) requieren una columna de fecha **diaria y continua, sin huecos**. Las tablas de `gold` tienen fechas fragmentadas por mes o por semana (no un calendario diario completo), por lo que no pueden usarse directamente como base de esas funciones.

Se agregó además una columna puente `AnioSemana` (`[Anio] & "-" & FORMAT([SemanaISO], "00")`), necesaria para relacionar la tabla semanal, que no tiene fecha exacta, solo año + número de semana ISO.

---

## Modelo de datos (esquema estrella)

                Dim_Date (centro)
               /    |    \
 dm_ventas_mensual  |  feat_demanda_forecasting
                (por mes) (por fecha diaria)
                     |
          dm_estacionalidad_semanal
                (por AnioSemana)

dm_rendimiento_campo (sin relacion — foto fija por bloque)
dm_cliente_rfm (sin relacion — foto fija por cliente)


### Decisiones de diseño

- **3 relaciones activas**, todas de cardinalidad "uno a varios" desde `Dim_Date`: por fecha diaria exacta (`feat_demanda_forecasting`), por `AnioMes` (`dm_ventas_mensual`), y por la columna puente `AnioSemana` (`dm_estacionalidad_semanal`).
- **2 tablas quedan intencionalmente sin relación** a `Dim_Date`: `dm_rendimiento_campo` y `dm_cliente_rfm` no son series de tiempo, son "fotos fijas" (rendimiento acumulado por bloque, segmentación RFM por cliente), así que forzarlas a una relación de fecha no tendría sentido de negocio.

---

## Medidas DAX creadas

Todas las medidas viven en una tabla dedicada `_Medidas` (tabla vacía creada con `{1}`), para mantenerlas organizadas y separadas de las columnas de datos.

### Medidas base

```dax
Total Ventas = SUM('gold dm_ventas_mensual'[total_valor_ventas])
Total Tallos = SUM('gold dm_ventas_mensual'[total_tallos])
Precio Promedio Ponderado = DIVIDE([Total Ventas], [Total Tallos])
```

**Nota importante**: `Precio Promedio Ponderado` se calcula dividiendo los totales agregados, no promediando la columna `precio_promedio_ponderado` ya calculada por mes (`AVERAGE(...)`). Promediar un promedio ya calculado distorsiona el resultado si los meses tienen volúmenes distintos — es el mismo principio de promedio ponderado aplicado en SQL durante el Día 5.

### Medidas de inteligencia de tiempo

```dax
Ventas Año Anterior = CALCULATE([Total Ventas], SAMEPERIODLASTYEAR('Dim_Date'[Date]))

% Crecimiento YoY = DIVIDE([Total Ventas] - [Ventas Año Anterior], [Ventas Año Anterior])

Ventas Mes Anterior = CALCULATE([Total Ventas], DATEADD('Dim_Date'[Date], -1, MONTH))
```

`CALCULATE` es la función central de DAX: recalcula una medida existente bajo un filtro distinto al que aplicaría el reporte por defecto. `SAMEPERIODLASTYEAR` y `DATEADD` generan ese filtro desplazado en el tiempo (un año atrás, o N meses/días atrás, respectivamente). Ambas dependen de que `Dim_Date` tenga fechas continuas para funcionar correctamente.

---

## Hallazgo: años parciales distorsionan el % YoY

Al construir una tabla con `Año`, `Total Ventas`, `Ventas Año Anterior` y `% Crecimiento YoY`, se obtuvo:

| Año | Total Ventas | Año Anterior | % YoY |
|---|---:|---:|---:|
| 2023 | 32,950,874.59 | — | — |
| 2024 | 62,264,598.84 | 32,950,874.59 | +89% |
| 2025 | 61,479,124.86 | 62,264,598.84 | -1% |
| 2026 | 29,268,277.47 | 33,212,684.63 | -12% |

El +89% de 2024 y el -12% de 2026 **no reflejan crecimiento o caída real del negocio** — son artefactos de comparar años parciales contra años completos: 2023 solo tiene 7 meses de datos (el simulador arranca en junio 2023) y 2026 solo tiene 6 meses (el simulador termina en junio 2026). El dato de 2025 (-1%, prácticamente plano) es el único comparable de forma justa entre dos años completos, y confirma la ausencia de tendencia de crecimiento ya documentada en el Día 5.

Este es el mismo problema de años parciales detectado originalmente con SQL (Pregunta 10 del Día 5), ahora reaparecido en DAX. La solución para el dashboard final será la misma: excluir 2023/2026 de comparaciones YoY, o señalar explícitamente en el visual que son años parciales.

---

## Conceptos DAX nuevos del Día 7

- `CALENDAR()` / `ADDCOLUMNS()`: generación de una tabla de fechas continua con columnas calculadas.
- Relaciones de modelo con cardinalidad "uno a varios", y el concepto de columna puente para relacionar tablas que no comparten una fecha exacta (solo año + semana).
- `CALCULATE()`: la función que permite recalcular una medida bajo un contexto de filtro distinto.
- `SAMEPERIODLASTYEAR()` y `DATEADD()`: funciones de inteligencia de tiempo, ambas dependientes de una tabla de calendario continua.
- `DIVIDE()`: equivalente DAX del cast `::numeric` de SQL para evitar errores de división, con manejo automático de división por cero.

---

## Estado al finalizar el Día 7

- ✅ Conexión a Postgres (`gold.*`) funcionando.
- ✅ `Dim_Date` construida y relacionada con 3 de las 5 tablas de gold.
- ✅ Modelo en estrella completo, con decisiones de relación justificadas.
- ✅ Medidas base (Total Ventas, Total Tallos, Precio Promedio Ponderado).
- ✅ Medidas de tiempo YoY completas (Ventas Año Anterior, % Crecimiento YoY).
- ✅ Medida MoM iniciada (Ventas Mes Anterior); % Crecimiento MoM queda pendiente de completar.
- ⬜ Páginas visuales del dashboard: no iniciadas todavía (Día 8).

> **Nota:** Los resultados corresponden exclusivamente al dataset sintético generado para este proyecto y no representan datos reales de una florícola.