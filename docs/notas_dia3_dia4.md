# 🌹 Floricola Analytics — Bitácora: Día 3 y Día 4

Documentación técnica del trabajo de **profiling (Día 3)** y **limpieza de datos (Día 4)** sobre el dataset sintético de la florícola. Sirve como registro del proceso y como evidencia de las decisiones tomadas.

## Contexto del proyecto

**Floricola Analytics** es un proyecto de analítica de datos para una florícola ecuatoriana ficticia dedicada a la exportación de rosas y gypsophila. Los datos son sintéticos, generados con Python usando semillas reproducibles.

**Stack**: PostgreSQL 16 · Docker · DBeaver · Python · Power BI · Prophet/XGBoost (fases posteriores)

**Arquitectura prevista**:

Python Simulator
↓
Bronze / RAW
↓
Silver / Clean + Validate
↓
Gold / Business Analytics
↓
Power BI / Forecasting

En los Días 3 y 4 **todavía no se implementó una arquitectura Medallion física completa**. Se trabajó sobre las tablas RAW y mediante vistas SQL para descubrir, probar y validar las reglas de limpieza.

Al cierre del Día 4, el flujo real implementado es conceptual, no físico en schemas separados:

RAW (tablas originales)
↓
Views de limpieza (cliente_mapping, cliente_limpio, venta_limpia, inventario_movimiento_limpio)
↓
Análisis SQL (Día 5 en adelante)


La migración a schemas `bronze`/`silver`/`gold` queda planeada para una fase posterior.

## Modelo de datos

### Dimensiones

| Tabla | Columnas |
|---|---|
| `variedad` | variedad_id, nombre, tipo, color |
| `bloque` | bloque_id, codigo, hectareas, variedad_id |
| `cuarto_frio` | cuarto_frio_id, codigo |
| `cliente` | cliente_id, nombre, pais_destino, tipo |
| `aerolinea` | aerolinea_id, nombre |
| `agencia_carga` | agencia_carga_id, nombre |

### Hechos

| Tabla | Columnas |
|---|---|
| `cosecha` | cosecha_id, fecha, bloque_id, tallos, grado_calidad, largo_cm |
| `venta` | venta_id, fecha, cliente_id, variedad_id, empaque, tallos, precio_tallo |
| `inventario_movimiento` | movimiento_id, fecha, cuarto_frio_id, cosecha_id, tipo_movimiento, cantidad |
| `despacho` | despacho_id, fecha, venta_id, aerolinea_id, agencia_carga_id, awb, peso_kg |

## Problemas de calidad detectados

Los datos son deliberadamente sintéticos, pero contienen defectos intencionales para simular un escenario real:

1. **`cliente.nombre`**: inconsistencias de espacios y de mayúsculas/minúsculas.
2. **`cliente.pais_destino`**: distintas representaciones de Estados Unidos (`Usa`, `USA`, `U.S.A.`, `usa `).
3. **`cliente.tipo`**: valores con espacios finales.
4. **`venta.precio_tallo`**: 419 valores `NULL`.
5. **Clientes duplicados lógicamente**: 5 casos de clientes que representan el mismo nombre después de normalizar con `INITCAP(TRIM(nombre))`.
6. **`inventario_movimiento`**: 1 duplicado exacto (fecha `2026-06-17`, cuarto_frio_id `1`, cosecha_id `NULL`, tipo_movimiento `salida`, cantidad `488`, con `movimiento_id` `91540` y `91548`). Regla decidida: conservar el registro con el menor `movimiento_id`.

---

## Día 3 — Data Profiling / Detección

Objetivo: aprender a inspeccionar la calidad de los datos antes de modificarlos. Se revisaron cantidad de registros, valores nulos, duplicados, valores distintos, inconsistencias de texto, posibles duplicados lógicos y consistencia entre tablas de hechos.

### Resultados — Dimensiones

| Tabla | Registros | Observaciones |
|---|---|---|
| `variedad` | 41 | 41 IDs distintos, sin nombres duplicados |
| `bloque` | 70 | 70 IDs distintos, sin códigos duplicados |
| `cuarto_frio` | 4 | 4 códigos distintos |
| `aerolinea` | 5 | nombres únicos |
| `agencia_carga` | 9 | nombres únicos |
| `cliente` | 33 | 33 IDs distintos, **5 duplicados lógicos** al normalizar `nombre` |

### Resultados — Hechos

| Tabla | Registros | Observaciones |
|---|---|---|
| `cosecha` | 65,319 | sin duplicados exactos considerando atributos de negocio |
| `venta` | 21,235 | sin duplicados exactos (fecha, cliente_id, variedad_id, tallos, precio_tallo); **419 valores NULL** en `precio_tallo` |
| `inventario_movimiento` | 91,832 | **1 duplicado exacto** detectado; la vista limpia queda en 91,831 registros |
| `despacho` | 21,235 | sin AWB duplicados |

Distribución de `tipo_movimiento` en `inventario_movimiento`:

| Tipo | Cantidad |
|---|---|
| entrada | 65,319 |
| salida | 21,234 |
| merma | 5,278 |

---

## Día 4 — Cleaning / Transformation

Objetivo: transformar los datos sin alterar las tablas RAW originales. Se optó por usar `VIEW` para probar las transformaciones y mantener la separación:

RAW → reglas de limpieza → datos limpios


Una `VIEW` almacena la definición de una consulta y presenta sus resultados al consultarla; no almacena una copia independiente de las filas como una tabla física. Esto permite trabajar con una representación transformada sin tocar ni una fila del RAW.

### 1. `cliente_mapping`

Vista que identifica el cliente canónico entre los duplicados lógicos, usando `INITCAP(TRIM(nombre))` como regla de normalización y el menor `cliente_id` de cada grupo como el registro canónico.

```sql
CREATE OR REPLACE VIEW cliente_mapping AS
WITH canonicos AS (
    SELECT
        INITCAP(TRIM(nombre)) AS nombre_limpio,
        MIN(cliente_id) AS cliente_id_canonico
    FROM cliente
    GROUP BY INITCAP(TRIM(nombre))
)
SELECT
    c.cliente_id,
    INITCAP(TRIM(c.nombre)) AS nombre_limpio,
    ca.cliente_id_canonico
FROM cliente c
JOIN canonicos ca
    ON INITCAP(TRIM(c.nombre)) = ca.nombre_limpio;
```

**Resultado**: 33 IDs originales mapeados a 28 IDs canónicos.

### 2. `cliente_limpio`

Vista que aplica las reglas de limpieza sobre `cliente` y conserva únicamente el registro canónico de cada cliente:

- elimina espacios y normaliza `nombre` con `INITCAP`
- normaliza `pais_destino` con `TRIM(UPPER(...))`
- elimina espacios finales de `tipo`

```sql
CREATE OR REPLACE VIEW cliente_limpio AS
SELECT
    c.cliente_id,
    INITCAP(TRIM(c.nombre)) AS nombre,
    TRIM(UPPER(c.pais_destino)) AS pais_destino,
    TRIM(c.tipo) AS tipo
FROM cliente c
JOIN cliente_mapping m
    ON c.cliente_id = m.cliente_id
WHERE c.cliente_id = m.cliente_id_canonico;
```

**Resultado**: 28 clientes limpios.

### 3. `venta_limpia`

Vista que resuelve los 419 valores `NULL` de `precio_tallo`, imputando con el precio promedio de la variedad correspondiente, y remapea `cliente_id` al ID canónico.

```sql
CREATE VIEW venta_limpia AS
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
    v.fecha,
    m.cliente_id_canonico AS cliente_id,
    v.variedad_id,
    v.empaque,
    v.tallos,
    ROUND(
        COALESCE(v.precio_tallo, p.precio_promedio),
        2
    ) AS precio_tallo
FROM venta v
LEFT JOIN cliente_mapping m
    ON v.cliente_id = m.cliente_id
LEFT JOIN promedios p
    ON v.variedad_id = p.variedad_id;
```

**Validaciones realizadas**: 21,235 registros, 0 precios `NULL`, 0 clientes sin ID canónico.

### 4. `inventario_movimiento_limpio`

Vista que usa `ROW_NUMBER()` para identificar y excluir de la representación limpia el duplicado exacto detectado en el profiling, conservando el registro con el menor `movimiento_id`. El RAW conserva sus 91,832 registros intactos; la vista limpia expone 91,831.

```sql
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
            ORDER BY movimiento_id
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
```

**Resultado**: 91,831 registros, 0 duplicados exactos restantes.

---

## Conceptos SQL practicados

`TRIM` · `UPPER` · `INITCAP` · `COALESCE` · `AVG` · `MIN` · `GROUP BY` · `ROW_NUMBER()` · `PARTITION BY` · `ORDER BY` · `LEFT JOIN` · CTEs (`WITH`) · vistas (`VIEW`) · detección de duplicados · normalización de texto · imputación de valores `NULL` · remapeo de claves · validación posterior a una transformación.

## Lecciones de Data Engineering

1. El RAW debe permanecer intacto: ninguna transformación se hace con `UPDATE` sobre las tablas originales.
2. Primero se detectan los problemas con consultas de diagnóstico, y solo después se definen las reglas de limpieza.
3. Las reglas de limpieza deben ser reproducibles: cualquiera que corra la misma vista obtiene el mismo resultado.
4. Toda limpieza debe poder validarse (conteos antes/después, verificación de que ya no quedan nulos o duplicados).
5. Los duplicados lógicos requieren una regla explícita para decidir qué registro conservar (aquí: el de menor ID).
6. Los valores `NULL` no se eliminan automáticamente: se decide cómo tratarlos según el significado de la variable (aquí: imputación con el promedio de la variedad).
7. Las claves canónicas son necesarias cuando existen duplicados de entidades, para que otras tablas (como `venta`) puedan remapearse correctamente.
8. Las vistas se usaron en esta etapa para probar y validar las transformaciones sin comprometer el dato crudo.

---

## Estado al finalizar el Día 4

- ✅ RAW identificado y conservado sin modificaciones.
- ✅ Profiling completo de las 10 tablas.
- ✅ Problemas de calidad identificados y documentados.
- ✅ Reglas de limpieza reproducibles, definidas y probadas.
- ✅ Vistas limpias construidas: `cliente_mapping`, `cliente_limpio`, `venta_limpia`, `inventario_movimiento_limpio`.
- ✅ Resultados validados (conteos, ausencia de nulos y duplicados).
- ⬜ Capa Gold: no construida todavía.
- ⬜ Power BI: no implementado todavía.
- ⬜ Forecasting: no implementado todavía.

El Día 5 corresponde a análisis de negocio con SQL sobre estas vistas limpias.