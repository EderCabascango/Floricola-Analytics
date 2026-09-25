## Resumen ejecutivo

Construimos la base de datos de una florícola exportadora ficticia, con 3 años de historia operativa simulada (junio 2023 a junio 2026), incluyendo la estacionalidad real del negocio: picos de producción antes de San Valentín y del Día de la Madre. Por ahora tenemos completo el lado de **producción** (qué se cultiva, dónde, y cuánto se cosecha cada día); lo que falta es el lado de **ventas y logística**, que es el Día 3.

---

## El modelo de datos: 10 tablas, dos tipos

Separamos las tablas en dos categorías, un patrón estándar en analítica de datos:

- **Dimensiones**: catálogos que describen "quién" o "qué", cambian poco. Son el diccionario del negocio.
- **Hechos**: registros de eventos que pasan todos los días, en grandes volúmenes. Son la bitácora del negocio.

## Lo que ya está cargado (7 de 10 tablas)

### Dimensiones (los catálogos)

| Tabla | Qué representa | Filas | Detalle clave |
|---|---|---|---|
| **variedad** | Las flores que se cultivan | 8 | 6 rosas, 1 gypsophila, 1 clavel, cada una con su color |
| **bloque** | Los terrenos de cultivo dentro de la finca | 18 | Cada uno tiene hectáreas (1.6 a 7.8 ha) y está asignado a una variedad |
| **cuarto_frio** | Las cámaras de almacenamiento poscosecha | 4 | Con temperatura objetivo (~1-4°C) y capacidad en cajas |
| **cliente** | Los compradores internacionales | 28 | Importadores, brokers y retailers, concentrados en USA, Rusia, Países Bajos |
| **aerolinea** | Los cargueros aéreos que transportan la flor | 5 | KLM, American, LATAM, Avianca, Aeroflot |
| **agencia_carga** | Los intermediarios logísticos de exportación | 9 | Empresas de freight forwarding |

### Hechos (lo que ya llenamos)

| Tabla | Qué representa | Filas | Detalle clave |
|---|---|---|---|
| **cosecha** | Cada corte diario de flor, por bloque | 16,826 | Tallos cosechados, largo (30-90cm) y grado de calidad (A/B/C) |

## Lo que falta (3 de 10 tablas, para el Día 3)

- **venta**: transacciones comerciales (qué cliente compró qué variedad, cuánto y a qué precio)
- **inventario_movimiento**: entradas, salidas y mermas en los cuartos fríos
- **despacho**: el envío físico de cada venta (aerolínea, agencia, guía aérea, peso)

---

## Cómo se conecta todo (las claves foráneas)

```
variedad ──┬──> bloque ──> cosecha
           └──> venta <── cliente
                  │
                  └──> despacho ──┬──> aerolinea
                                  └──> agencia_carga

cuarto_frio ──> inventario_movimiento <── cosecha
```

La idea central: `cosecha` es lo único que conecta con `bloque` (producción), y `venta` es lo único que conecta con `cliente` (comercial). Todavía no existe un puente directo entre "qué cosecha específica terminó en qué venta específica" — eso quedó fuera a propósito, para no complicar el proyecto con trazabilidad de lotes.

---

## La parte técnica: cómo se generaron los datos

### 1. Reproducibilidad
Todo el simulador usa semillas fijas (`np.random.seed(42)`, `Faker.seed(42)`). Esto significa que si alguien clona tu repo y corre los scripts, obtiene **exactamente los mismos datos** que tú. Es clave para que el proyecto sea auditable y no "mágico".

### 2. Respeto de integridad referencial desde el origen
Cada tabla hija se generó tomando IDs que **ya existían** en su tabla padre (ej. `bloque.variedad_id` se sacó con `np.random.choice()` sobre los `variedad_id` reales de `variedad.csv`). Por eso la carga a Postgres no falló ni una sola FK: los datos nacieron consistentes, no se validaron después.

### 3. El motor de estacionalidad (la pieza más importante de `cosecha`)
1. Se generó un calendario diario de 1,097 días (3 años).
2. A cada fecha se le asignó un **multiplicador** según su semana ISO: 1.8× en semanas 3-6 (pre San Valentín), 1.5× en semanas 15-18 (pre Día de la Madre), 1.0× el resto del año.
3. Cada bloque tiene una **producción base diaria**, proporcional a sus hectáreas (~1,800-2,200 tallos/hectárea).
4. La cosecha real de cada día = producción base × multiplicador estacional × ruido aleatorio (±8%, con forma de campana), para que no sea una curva perfecta.
5. Se generó un producto cartesiano (18 bloques × 1,097 días = 19,746 combinaciones posibles), y se eliminó al azar un 15% para simular días sin corte en ciertos bloques, quedando en 16,826 filas reales.

### 4. Correlaciones con sentido de negocio, no datos puramente al azar
- El **largo del tallo** sigue una distribución normal (la mayoría entre 45-70cm).
- El **grado de calidad** no es aleatorio parejo: se calculó con probabilidades condicionadas al largo (tallos ≥65cm tienen 70% de probabilidad de ser grado A; tallos <45cm tienen 60% de probabilidad de ser grado C). Esto simula una correlación real de floricultura, con algo de "ruido" para que no sea una regla perfecta y matemática.
- Los **países de los clientes** se armaron con una distribución ponderada (más clientes en USA que en España), no un sorteo parejo entre países.
- El **tipo de cliente** también usa probabilidades (`p=[0.5, 0.3, 0.2]`): 50% importadores, 30% brokers, 20% retailers.

### 5. Pipeline de carga
Python generó CSV en `data/raw/` (capa intermedia auditable, puedes abrirlos en Excel antes de tocar la base), y un script separado (`03_cargar_postgres.py`) los cargó a Postgres **en el orden correcto** (dimensiones primero, luego `cosecha`), usando `SQLAlchemy` para la conexión y `pandas.to_sql()` para la inserción masiva.

---

## Por qué esto importa para tu portafolio

Un dataset que se ve "hecho a mano" (números redondos, sin variación, sin correlaciones) se nota falso de inmediato. Lo que construiste tiene: estacionalidad real y verificable con SQL (como viste en la consulta de promedios por semana), correlaciones sutiles entre variables, cierta imperfección intencional (el 15% de días sin cosecha, el ruido del ±8%), y trazabilidad completa de cómo se generó cada número. Eso es lo que un revisor técnico reconoce como un ejercicio serio, no un tutorial copiado.