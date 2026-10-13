# Floricola Analytics — Bitacora Dia 8 (En Progreso / En Revision Tecnica)

## Machine Learning: Feature Engineering, Estrategia Multihorizonte y Modelado de Forecasting

El Dia 8 aborda la transicion hacia la analitica predictiva. Se estructuro un sistema de pronostico de demanda semanal de tallos por variedad con estrategia directa multihorizonte ($h = 1 \dots 12$ semanas), disenado especificamente para apoyar la decision de poda (*pinche*) que los agronomos deben ejecutar entre 75 y 90 dias antes de la cosecha.

---

## 1. Contexto de Negocio y Formulacion Matematica

### Restricciones Operativas del Cultivo Floricola en Ecuador
* **Capacidad instalada fija:** 70 bloques y `322.62` hectareas activas bajo produccion continua (`silver.dim_bloque`).
* **Ciclo biologico (Pinche):** El agronomo debe podar entre 75 y 90 dias (aproximadamente 11 a 13 semanas) antes de la cosecha esperada. Por esta razon, el horizonte de decision mas critico para la operacion es **$h = 12$ semanas**.
* **Perecibilidad en cuarto frio:** La flor cortada tiene una vida util maxima de 14 a 21 dias a temperaturas de 0.5°C a 2°C.

### Costo Asimetrico del Error (Problema del Vendedor de Periodicos / Newsvendor)
El costo financiero de equivocarse en la estimacion no es simetrico y varia segun la temporada:
* **Costo por subestimacion ($C_u = \$0.60$/tallo en San Valentin y $\$0.35$/tallo fuera de pico):** Quedarse sin flor en temporada alta significa perder el margen comercial maximo del ano.
* **Costo por sobrestimacion ($C_o = \$0.28$/tallo):** Cosechar flor que no se vende a tiempo genera merma y costo de desecho en cuarto frio.

El cuantil optimo de planificacion segun la teoria de Newsvendor en San Valentin es:
$$\alpha^*_{\text{pico}} = \frac{C_u}{C_u + C_o} = \frac{0.60}{0.60 + 0.28} \approx 0.68$$
Mientras que fuera de la ventana de San Valentin (~80% del ano), el cuantil optimo baja a:
$$\alpha^*_{\text{normal}} = \frac{0.35}{0.35 + 0.28} \approx 0.555$$

Por ello, se adopta **LightGBM Media** como el modelo principal para el horizonte de decision ($h=12$) y se documenta **LightGBM Cuantil 0.68** como un experimento comparativo sobre el efecto de aplicar un cuantil estatico de temporada alta durante todo el ano.

---

## 2. Entregables en Revision en el Dia 8

1. **Jupyter Notebook de Analisis Exploratorio (EDA):**
   * Archivo: `forecasting/01_eda_forecasting.ipynb`
   * Cubre la prueba formal de estacionariedad (ADF Test: estadistico `-3.2772`, $p = 0.015927$, rechazando $H_0$ al 5% pero no al 1%), descomposicion estacional anual ($m=52$) y analisis de autocorrelacion (ACF/PACF).
2. **Jupyter Notebook de Modelado Multihorizonte y Evaluacion:**
   * Archivo: `forecasting/02_modelado_forecasting.ipynb`
   * Conectado directamente a `gold.feat_demanda_forecasting` en PostgreSQL (`17,070` registros diarios consolidados en `6,323` registros semanales y un panel continuo de `6,642` filas). Implementa el pipeline de features en fecha de origen $T$, entrenamiento de baselines y modelos LightGBM (Media y Cuantil), evaluacion de metricas tecnicas y calculo de costos financieros.

---

## 3. Ingenieria de Caracteristicas en la Fecha de Origen $T$ (Prevencion de Fuga de Datos)

Para predecir el horizonte $T+h$, todas las variables se calculan estrictamente con informacion disponible hasta la fecha de decision $T$:

| Familia de Caracteristicas | Definicion | Proposito Operativo |
| :--- | :--- | :--- |
| **Nivel Reciente en $T$** | $y_{i,T}, y_{i,T-1}, y_{i,T-2}, y_{i,T-3}$ | Inercia de ventas recientes en la fecha de decision. |
| **Medias Moviles en $T$** | $\text{MA}_4, \text{MA}_{12}$ | Tendencia de corto y mediano plazo previa al origen $T$. |
| **Volatilidad en $T$** | $\text{STD}_8$ | Dispersion reciente de demanda por variedad. |
| **Rezago Estacional del Objetivo** | $y_{i, T+h-52}$ | Demanda de la misma semana del ano anterior al objetivo (conocida en $T$). |
| **Factor de Crecimiento** | $\frac{\sum_{k=0}^{7} y_{i,T-k}}{\sum_{k=0}^{7} y_{i,T-k-52}}$ | Ajuste de nivel respecto al ano precedente. |
| **Calendario del Objetivo** | $\sin(2\pi \cdot \text{sem}/52), \cos(2\pi \cdot \text{sem}/52)$ | Continuidad circular de la semana ISO objetivo. |
| **Festividades Reales** | Distancia en semanas a San Valentin (14 de febrero) y Dia de la Madre (2° domingo de mayo). | Ventanas buffer de aceleracion de despachos comerciales. |
| **Horizonte** | `horizonte_h` $\in \{1 \dots 12\}$ | Permite al modelo ajustar su nivel de incertidumbre segun la distancia temporal. |
| **Producto** | `variedad_id` (categorica nativa de LightGBM) | Aprendizaje de curvas diferenciadas por tipo de flor. |

Total del dataset multihorizonte estructurado: **48,216 tuplas $(i, T, h)$**.

---

## 4. Estrategia de Particion y Validacion Temporal

* **Entrenamiento (Train):** Objetivos hasta `2024-12-31` (12,054 ejemplos).
* **Validacion (Val):** Objetivos del `2025-01-01` al `2025-06-30` (12,792 ejemplos, evalua San Valentin y Dia de la Madre 2025).
* **Tramo Intermedio (2025-H2):** Objetivos del `2025-07-01` al `2025-12-31` (12,792 ejemplos).
* **Reentrenamiento Completo:** Se reentrenan los modelos con `Train + Val + 2025-H2` (37,638 ejemplos) antes de evaluar el conjunto de prueba.
* **Prueba Ciega (Test):** Objetivos del `2026-01-01` al `2026-06-30` (10,578 ejemplos, incluye San Valentin 2026).

---

## 5. Resultados del Benchmark y Evaluacion Financiera

### A. Rendimiento Global en el Test Set 2026 (Horizontes $h = 1 \dots 12$)

| Modelo | WAPE (%) | MAE (tallos) | RMSE (tallos) | Sesgo Bias (%) | Costo Financiero Total ($) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **M3: LightGBM Cuantil 0.68** | 65.03% | 65,376.8 | **87,156.5** | +15.95% | **$230,433,200** |
| **M3: LightGBM Media** | **64.32%** | **64,660.7** | 90,986.1 | **+0.61%** | $238,239,800 |
| **M0: Seasonal Naive (t-52)** | 82.97% | 83,405.9 | 120,282.2 | +2.44% | $305,551,700 |
| **M0b: Naive + Crecimiento** | 85.88% | 86,335.9 | 125,089.1 | +4.38% | $315,360,800 |

### B. Rendimiento en el Horizonte Critico de Poda ($h = 12$ semanas)

| Modelo | WAPE (%) | MAE (tallos) | RMSE (tallos) | Sesgo Bias (%) | Costo Financiero Total ($) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **M3: LightGBM Media (Recomendado)** | **76.82%** | **66,257.8** | **89,804.1** | **+13.79%** | **$24,560,377.01** |
| **M3: LightGBM Cuantil 0.68** | 81.05% | 69,905.8 | 90,103.4 | +32.81% | $24,824,270.40 |
| **M0: Seasonal Naive (t-52)** | 95.29% | 82,192.1 | 116,767.2 | +15.25% | $30,530,062.70 |
| **M0b: Naive + Crecimiento** | 97.85% | 84,403.4 | 119,586.7 | +17.13% | $31,255,174.22 |

* **Modelo ganador en $h = 12$ (`M3: LightGBM Media`):** Logra el menor costo total (`$24,560,377.01`), ahorrando **`$5,969,685.69` (`19.6%` de reduccion de perdidas)** frente al baseline `M0: Seasonal Naive`, y superando por **`$263,893.39`** a `LightGBM Cuantil 0.68`.
* **Leccion aprendida sobre el cuantil asimetrico ($\alpha = 0.68$):** Entrenar un modelo con $\alpha = 0.68$ fijo para todas las semanas del ano genero una sobreestimacion de `+32.81%` en $h=12$ porque fuera de San Valentin (~81% de las semanas) el margen perdido baja a $\$0.35$/tallo y el cuantil optimo desciende a $\alpha^* = 0.555$. El exceso de produccion en semanas normales encarecio el costo por merma ($C_o = \$0.28$/tallo).

---

## 6. Verificacion de Capacidad Fisica Instalada (70 Bloques / 322.62 ha)

* **Capacidad Base Semanal (Temporada Normal):** $322.62\text{ ha} \times 2,000\text{ tallos}/(\text{ha}\cdot\text{dia}) \times 7\text{ dias/semana} \times 0.85 = \mathbf{3,839,178\text{ tallos/semana}}$.
* **Capacidad Maxima Semanal en Pico (Multiplicador $1.80\times$ y factor neto poscosecha $0.90$):** $\mathbf{6,219,468\text{ tallos/semana}}$.
* **Hallazgo:** En el conjunto de prueba 2026 ($h=12$), el pronostico de `LightGBM Media` se mantiene en todo momento dentro del techo fisico maximo en pico (`0` de `27` semanas excedidas) y supera la capacidad base normal en `13` de `27` semanas (correspondientes a los despachos de temporada alta de San Valentin y Dia de la Madre, donde se requiere capacidad operativa de temporada alta).

---

## 7. Estado Actual del Dia 8

- [x] Extraccion y EDA de series temporales desde PostgreSQL (`forecasting/01_eda_forecasting.ipynb`).
- [x] Extraccion desde `gold.feat_demanda_forecasting` e ingenieria de variables multihorizonte en origen $T$ (`forecasting/02_modelado_forecasting.ipynb`).
- [x] Correccion de auditoria sobre capacidad instalada, evaluacion en $h=12$ y analisis del sesgo cuantílico.
- [ ] **En progreso:** Revision final detallada por parte del autor antes de dar por cerrado el Dia 8.

