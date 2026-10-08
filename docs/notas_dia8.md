# 🌹 Floricola Analytics — Bitácora Día 8 (EN PROGRESO / INCOMPLETO)

> [!WARNING]
> **Estado del Día 8:** 🟡 **EN PROGRESO (PARCIALMENTE COMPLETADO)**.
> Se ha completado la **Fase 1: Análisis Exploratorio de Series de Tiempo (EDA)** en el Jupyter Notebook [`forecasting/01_eda_forecasting.ipynb`](../forecasting/01_eda_forecasting.ipynb).
> Las fases de *Feature Engineering*, modelado comparativo (*Prophet vs. XGBoost*) y evaluación financiera de errores están **pendientes por desarrollar**.

---

## 1. 🎯 Contexto y Formulación del Desafío de Machine Learning

En la industria florícola ecuatoriana de exportación, la planificación agrícola (*el pinzado / poda*) debe ejecutarse con **10 a 14 semanas de anticipación** a la cosecha, mientras que la flor cortada en cuarto frío ($0.5^\circ\text{C}$ a $2^\circ\text{C}$) tiene una vida útil de **máximo 14 a 21 días**.

El objetivo de la fase de Machine Learning es construir un sistema predictivo de demanda semanal de tallos por variedad para mitigar los dos riesgos financieros críticos:
1. **Subestimación (*Underforecasting*):** Quiebre de stock en temporadas pico (San Valentín y Día de la Madre), perdiendo ventas al precio unitario más alto del año.
2. **Sobrestimación (*Overforecasting*):** Saturación de cuartos fríos y costo directo de merma (desecho de flor marchita).

---

## 2. 📊 Fase 1 Completada: Análisis Exploratorio de Datos (EDA)

Se desarrolló y ejecutó el notebook [`forecasting/01_eda_forecasting.ipynb`](../forecasting/01_eda_forecasting.ipynb) conectado directamente a la capa analítica [`gold.feat_demanda_forecasting`](../sql/03_gold.sql) de PostgreSQL (`floricola_db`).

### Hallazgos Principales del EDA:

1. **Integridad del Dataset:**
   * 17,070 registros diarios entre el 01/06/2023 y el 30/06/2026 para 41 variedades.
   * 0 valores nulos y cobertura temporal continua.

2. **Prueba Formal de Estacionariedad (Augmented Dickey-Fuller - ADF):**
   * Estadístico ADF: **-4.128** ($p\text{-valor} = 0.0008 \le 0.05$).
   * **Conclusión:** Se rechaza la hipótesis nula ($H_0$). La serie temporal es **estacionaria en media** con ciclos estacionales repetibles, confirmando la hipótesis de operación a capacidad instalada fija (70 bloques constantes sin expansión territorial).
   * **Implicación para ML:** Los algoritmos basados en árboles (**XGBoost / LightGBM**) pueden modelar la demanda directamente sin sufrir problemas de extrapolación fuera de rango (*out-of-domain*).

3. **Descomposición Estacional ($m=52$ semanas):**
   * **Pico San Valentín (Semanas 3 a 7):** La demanda se multiplica por cuatro ($+300\%$), superando los 320,000 tallos/semana y los precios promedio suben de $\$0.32$ a $\$0.85 - \$1.10$/tallo.
   * **Pico Día de la Madre (Semanas 16 a 19):** Segundo pico importante (~220,000 tallos/semana).
   * **Valles de Verano (Julio - Septiembre):** Demanda base de 80,000 a 110,000 tallos/semana.

4. **Heterogeneidad por Variedad:**
   * Las rosas rojas (*Freedom, Explorer, Red Paris*) concentran más del 40% de su venta anual en la ventana de San Valentín.
   * Las rosas blancas (*Vendela, Mondial*) tienen demanda distribuida hacia mitad de año (temporada de eventos y bodas).
   * La *Gypsophila* (*Million Star*) presenta una serie temporal más suave y estable a lo largo de todo el año.

5. **Estructura de Autocorrelación (ACF / PACF):**
   * **ACF:** Pico masivo y significativo en el rezago 52 ($r > 0.85$), demostrando que la misma semana del año anterior es el predictor más fuerte.
   * **PACF:** Rezagos significativos en las semanas 1 a 4, reflejando la inercia de corto plazo.

---

## 3. ⏳ Fases Pendientes del Día 8 (Por Ejecutar)

- [x] **Paso 1: Extracción & EDA en Jupyter Notebook** (`forecasting/01_eda_forecasting.ipynb`).
- [ ] **Paso 2: Pipeline de Feature Engineering** (Generación de lags $t-1 \dots t-4$, $t-52$, rolling windows con `.shift(1)` para evitar *leakage*, transformaciones cíclicas $\sin/\cos$ y flags de festividades).
- [ ] **Paso 3: Validación Temporal Estricta** (*Walk-Forward / TimeSeriesSplit*).
- [ ] **Paso 4: Modelado Comparativo** (Baseline **Prophet** vs. **XGBoost / LightGBM**).
- [ ] **Paso 5: Evaluación de Impacto de Negocio** (Cálculo de métricas WAPE, MAE, RMSE y matriz financiera de costos de error en $\$$).
