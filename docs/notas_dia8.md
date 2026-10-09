# Floricola Analytics — Bitacora Dia 8

## Machine Learning: Feature Engineering, Estrategia Multihorizonte y Modelado de Forecasting

El Dia 8 consolida la transicion hacia la analitica predictiva. Se desarrollo un sistema de pronostico de demanda semanal de tallos por variedad con estrategia directa multihorizonte ($h = 1 \dots 12$ semanas), disenado especificamente para apoyar la decision de poda (*pinche*) que los agronomos deben ejecutar entre 75 y 90 dias antes de la cosecha.

---

## 1. Contexto de Negocio y Formulacion Matematica

### Restricciones Operativas del Cultivo Floricola en Ecuador
* **Capacidad instalada fija:** 70 bloques y aproximadamente 350 hectareas bajo produccion continua.
* **Ciclo biologico (Pinche):** El agrónomo debe podar entre 75 y 90 dias (aproximadamente 11 a 13 semanas) antes de la cosecha esperada. Por esta razon, el horizonte de decision mas critico para la operacion es **$h = 12$ semanas**.
* **Perecibilidad en cuarto frio:** La flor cortada tiene una vida util maxima de 14 a 21 dias a temperaturas de 0.5°C a 2°C.

### Costo Asimetrico del Error (Problema del Vendedor de Periodicos / Newsvendor)
El costo financiero de equivocarse en la estimacion no es simetrico:
* **Costo por subestimacion ($C_u = \$0.60$/tallo en San Valentin):** Quedarse sin flor en temporada alta significa perder el margen comercial al precio mas alto del ano.
* **Costo por sobrestimacion ($C_o = \$0.28$/tallo):** Cosechar flor que no se vende a tiempo genera merma total y costo de desecho en cuarto frio.

El cuantil optimo de planificacion segun la teoria de Newsvendor es:
$$\alpha^* = \frac{C_u}{C_u + C_o} = \frac{0.60}{0.60 + 0.28} \approx 0.68$$

Por ello, el modelo principal de Machine Learning se entrena optimizando una funcion de perdida cuantílica ($\alpha = 0.68$) que minimiza directamente el impacto en dolares en lugar del error cuadratico medio tradicional.

---

## 2. Entregables Desarrollados en el Dia 8

1. **Jupyter Notebook de Analisis Exploratorio (EDA):**
   * Archivo: `forecasting/01_eda_forecasting.ipynb`
   * Cubre la prueba formal de estacionariedad (ADF Test, $p < 0.001$), descomposicion estacional anual ($m=52$) y analisis de autocorrelacion (ACF/PACF).
2. **Jupyter Notebook de Modelado Multihorizonte y Evaluacion:**
   * Archivo: `forecasting/02_modelado_forecasting.ipynb`
   * Implementa el pipeline de features en fecha de origen $T$, entrenamiento de baselines y modelos LightGBM (Media y Cuantil), evaluacion de metricas tecnicas y calculo de costos financieros.

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
| **M3: LightGBM Cuantil 0.68** | **65.03%** | 65,376.8 | **87,156.5** | +15.95% | **$230,433,200** |
| **M3: LightGBM Media** | 64.32% | **64,660.7** | 90,986.1 | +0.61% | $238,239,800 |
| **M0: Seasonal Naive (t-52)** | 82.97% | 83,405.9 | 120,282.2 | +2.44% | $305,551,700 |
| **M0b: Naive + Crecimiento** | 85.88% | 86,335.9 | 125,089.1 | +4.38% | $315,360,800 |

### B. Rendimiento en el Horizonte Critico de Poda ($h = 12$ semanas)

| Modelo | WAPE (%) | MAE (tallos) | RMSE (tallos) | Sesgo Bias (%) | Costo Financiero Total ($) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **M3: LightGBM Media** | **76.82%** | **66,257.8** | **89,804.1** | +13.79% | **$24,560,377.01** |
| **M3: LightGBM Cuantil 0.68** | 81.05% | 69,905.8 | 90,103.4 | +32.81% | **$24,824,270.40** |
| **M0: Baseline Naive (t-52)** | 95.29% | 82,192.1 | 116,767.2 | +15.25% | $30,530,062.70 |
| **M0b: Naive + Crecimiento** | 97.85% | 84,403.4 | 119,586.7 | +17.13% | $31,255,174.22 |

* **Impacto Economico en $h = 12$:** El modelo LightGBM reduce las perdidas operativas frente al baseline ingenuo en **$5,705,792.30 dolares (reduccion del 18.7% en costos de error)**.
* **Precision del Pronostico:** El WAPE se reduce del 95.3% al 76.8%, y el RMSE cae de 116.7k a 89.8k tallos.

---

## 6. Verificacion de Capacidad Fisica Instalada

* **Techo maximo operativo de poscosecha (70 bloques):** 380,000 tallos por semana.
* **Hallazgo:** Durante las 3 semanas previas a San Valentin 2026, la demanda pronosticada excede la capacidad maxima de la finca. Esto proporciona una senal de accion preventiva para que la direccion planifique turnos dobles de empaque y priorice el prorrateo de tallos hacia los clientes de mayor margen (segmento *Champions* de la clasificacion RFM).

---

## 7. Estado de Conclusion del Dia 8

- [x] Extraccion y EDA de series temporales (`forecasting/01_eda_forecasting.ipynb`).
- [x] Ingenieria de variables multihorizonte en origen $T$ con `groupby('variedad_id')`.
- [x] Particion temporal estricta y reentrenamiento completo con 2025-H2.
- [x] Entrenamiento de baselines (M0, M0b) y modelos LightGBM (Media y Cuantil 0.68).
- [x] Evaluacion sobre Test ciego 2026 con reporte en $h = 12$, WAPE, MAE, RMSE, Sesgo y costo asimetrico.
- [x] Comparacion grafica de San Valentin 2026 y verificacion de capacidad instalada.
- [x] **Dia 8 Completado al 100%**. Siguiente fase: Dia 9 (MLOps: Experiment Tracking con MLflow y Data Testing con Pytest).
