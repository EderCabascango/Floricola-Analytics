# 🌹 Floricola Analytics — Plan Maestro y Cronograma de Trabajo

Documento oficial de planificación y ruta de desarrollo de punta a punta (*End-to-End*) para el proyecto **Floricola Analytics**: desde el diseño de base de datos relacional y arquitectura Medallón, hasta Business Intelligence y un pipeline MLOps profesional.

---

## 🧭 Visión General del Proyecto

- **Empresa Ficticia:** Florícola exportadora ecuatoriana (rosas y gypsophila).
- **Core del Negocio:** Exportación internacional a USA, Europa y Rusia con alta estacionalidad (San Valentín y Día de la Madre) y perecibilidad crítica de producto.
- **Stack Tecnológico:**
  - **Base de Datos & Data Warehouse:** PostgreSQL 16 · Docker · Arquitectura Medallón (Bronze, Silver, Gold).
  - **Ingeniería de Datos & Pipelines:** Python 3 · SQLAlchemy · Pandas · Pytest.
  - **Business Intelligence:** Power BI · DAX · Modelado Dimensional en Estrella.
  - **Machine Learning & MLOps:** XGBoost · Prophet · Scikit-Learn · MLflow · FastAPI · GitHub Actions (CI/CD).

---

## 📅 Cronograma y Bitácora Día a Día

```
[Días 1-2: Fundamentos & Simulación] ➔ [Días 3-4: Profiling & Limpieza] ➔ [Día 5: Business Analysis SQL]
                                                                                   │
[Día 10: MLOps CI/CD & Deploy] 🠔 [Día 9: Tracking & Testing] 🠔 [Día 8: ML Forecasting] 🠔 [Día 7: Power BI] 🠔 [Día 6: SQL Avanzado & Pipelines]
```

---

### ⏪ Fase 1: Fundamentos, Simulación y Data Profiling (Completada)

#### ✅ Día 1 & 2 — Infraestructura, Modelo Relacional y Simulación de Producción
- **Infraestructura:** Despliegue de PostgreSQL 16 en Docker Compose (`floricola_db` en puerto `5433`).
- **Modelo Relacional:** Diseño de 10 tablas (6 dimensiones y 4 hechos) con claves foráneas e integridad referencial.
- **Simulador (Producción):** Generación de 3 años de datos operativos con semillas reproducibles (`Faker`, `NumPy`), curvas estacionales y correlaciones reales (largo de tallo vs. grado de calidad).
- **Entregable:** Catálogos cargados y tabla `cosecha` con 65,319 registros.

#### ✅ Día 3 & 4 — Simulación Comercial, Inyección de Defectos y Data Cleaning
- **Simulación Comercial:** Generación de hechos de `venta`, `inventario_movimiento` y `despacho`.
- **Data Profiling:** Inyección y detección deliberada de anomalías (espacios, mayúsculas/minúsculas, variantes de 'USA', clientes duplicados lógicos, 419 precios `NULL`, 1 duplicado exacto en inventario).
- **Data Cleaning:** Diseño de reglas de limpieza reproducibles mediante vistas SQL (`cliente_mapping`, `cliente_limpio`, `venta_limpia`, `inventario_movimiento_limpio`).
- **Entregable:** Profiling documentado y capa limpia validada con 0 nulos y 0 duplicados.

#### ✅ Día 5 — Business Analysis con SQL
- **Consultas de Negocio:** Resolución de 14 preguntas analíticas de alto impacto (volumen, valor de ventas con precio promedio ponderado, productividad por hectárea, porcentaje de merma por variedad, retención de clientes).
- **SQL Analítico:** Implementación de CTEs anidados, funciones de ventana (`LAG`), agrupaciones temporales (`DATE_TRUNC`) y pivoteo condicional (`CASE WHEN`).
- **Entregable:** Script `sql/05_business_analysis.sql` y bitácora completa en `docs/notas_dia5.md`.

---

### ⏩ Fase 2: Ingeniería de Datos, Automatización y BI (Próximos Días)

---

### 🗓️ Día 6 — SQL Avanzado (RFM), Arquitectura Medallón y Pipelines Automatizados
* **Objetivo:** Formalizar la arquitectura Medallón en PostgreSQL y automatizar el flujo de ingesta y limpieza mediante pipelines en Python.
* **Actividades:**
  1. **SQL Avanzado:** Segmentación de clientes RFM (Recencia, Frecuencia, Valor Monetario) usando `NTILE(5)` y asignación de segmentos estratégicos (`Campeones`, `Leales`, `En Riesgo`, etc.).
  2. **Arquitectura Medallón:** Consolidación de los 3 esquemas en PostgreSQL (`bronze.*`, `silver.*`, `gold.*`).
  3. **Pipelines de Datos Automatizados (`src/pipeline/`):**
     - Módulo de ingesta automática a Bronze (`01_ingest_bronze.py`).
     - Módulo de transformación y validación a Silver (`02_process_silver.py`).
     - Módulo de materialización de Data Marts a Gold (`03_materialize_gold.py`).
     - Orquestador maestro reproducible (`run_pipeline.py`) con control de errores y logs.
* **Entregables:**
  - Scripts SQL formalizados: `sql/01_bronze.sql`, `sql/02_silver.sql`, `sql/03_gold.sql`.
  - Módulos de pipeline en Python ejecutables con un solo comando.
  - Bitácora técnica: `docs/notas_dia6.md`.

---

### 🗓️ Día 7 — Business Intelligence Ejecutivo con Power BI
* **Objetivo:** Construir un dashboard interactivo de nivel gerencial conectado directamente a la capa Gold y dimensiones Silver.
* **Actividades:**
  1. **Conexión & Modelo Dimensional:** Conectar Power BI a PostgreSQL y configurar el esquema en estrella con tabla calendario (`Dim_Date`).
  2. **Métricas DAX Avanzadas:**
     - Métricas comerciales: Ventas totales, Ticket promedio, Precio ponderado, Variación MoM / YoY.
     - Métricas operativas: Tasa de merma %, Productividad por bloque (tallos/ha).
     - Segmentación: Matriz RFM dinámica y análisis Pareto 80/20.
  3. **Diseño Visual & Storytelling:**
     - Vista 1: Resumen Ejecutivo y Comercial (Ventas por país, estacionalidad, metas).
     - Vista 2: Rendimiento Operativo y Agrícola (Cosecha vs. Mermas, cuartos fríos).
     - Vista 3: Análisis de Clientes y Segmentación RFM.
* **Entregables:**
  - Archivo de Power BI (`.pbix`).
  - Capturas de pantalla documentadas en `powerbi/screenshots/`.
  - Bitácora técnica: `docs/notas_dia7.md`.

---

### ⏩ Fase 3: Machine Learning, Forecasting y MLOps Profesional

---

### 🗓️ Día 8 — Feature Engineering & Modelado de Forecasting
* **Objetivo:** Predecir la demanda de tallos de flor para optimizar la producción previa a las temporadas altas (San Valentín y Día de la Madre).
* **Actividades:**
  1. **Feature Engineering:** Extracción desde `gold.feat_demanda_forecasting`. Creación de variables rezagadas (*lags* $t-1, t-2, t-52$), medias móviles (*rolling windows*), variables de calendario y banderas de festividades.
  2. **Estrategia de Validación:** Validación temporal estricta (*TimeSeriesSplit / Walk-Forward Validation*) para evitar fuga de información (*data leakage*).
  3. **Modelado Comparativo:**
     - Modelo estadístico / baseline (Prophet / SARIMAX).
     - Modelo de Machine Learning supervisado (XGBoost / LightGBM Regressor).
  4. **Evaluación de Negocio:** Comparativa de métricas de error: WAPE, MAE, RMSE y cálculo del costo financiero del error de pronóstico (sobreproducción vs. quiebre de stock).
* **Entregables:**
  - Notebooks y scripts en `src/models/` y `forecasting/`.
  - Comparativa documentada de modelos y métricas.
  - Bitácora técnica: `docs/notas_dia8.md`.

---

### 🗓️ Día 9 — MLOps: Experiment Tracking, Model Registry y Data Testing
* **Objetivo:** Incorporar estándares de ingeniería de software y MLOps para tracking, versionado y pruebas automatizadas.
* **Actividades:**
  1. **Experiment Tracking con MLflow:**
     - Registro de ejecuciones, hiperparámetros, métricas y curvas de aprendizaje.
     - Guardado de artefactos del mejor modelo.
  2. **Model Registry:**
     - Versionado formal del modelo en MLflow (`Staging` vs. `Production`).
  3. **Testing Automatizado (Data & Software Quality):**
     - Pruebas unitarias de transformaciones y pipelines con `pytest`.
     - Validación de esquemas y contratos de datos (verificación de nulos, rangos válidos y consistencia temporal).
* **Entregables:**
  - Servidor local de MLflow configurado y rastreo de experimentos.
  - Suite de pruebas automatizadas en `tests/` con ejecución en verde.
  - Bitácora técnica: `docs/notas_dia9.md`.

---

### 🗓️ Día 10 — MLOps: Inferencia (API), CI/CD, Dockerización y Cierre del Portafolio
* **Objetivo:** Poner el modelo en producción mediante un servicio de inferencia, automatizar con CI/CD y pulir la presentación del repositorio para reclutadores.
* **Actividades:**
  1. **Servicio de Inferencia:**
     - Microservicio en **FastAPI** con endpoint `/predict` para recibir solicitudes de pronóstico de demanda.
     - Script de inferencia por lote (*Batch Scoring*) para actualizar proyecciones en la base de datos.
  2. **CI/CD con GitHub Actions:**
     - Pipeline de integración continua: Linting automático (Flake8 / Black), ejecución de pruebas de calidad (`pytest`) y validación de esquemas SQL.
  3. **Dockerización Integral:**
     - `docker-compose.yml` multiconenedor (PostgreSQL + MLflow + FastAPI).
  4. **Documentación Final de Portafolio:**
     - `README.md` profesional de alto impacto con badges, diagramas de arquitectura, capturas de Power BI, métricas de ML y guía de ejecución en un clic (`make run` o `docker compose up`).
* **Entregables:**
  - API de predicción contenerizada y testeada.
  - Pipeline de GitHub Actions funcional.
  - Repositorio de GitHub 100% pulido y listo para destacar en entrevistas técnicas.
  - Bitácora técnica: `docs/notas_dia10.md` y `docs/lecciones.md`.

---

## 📊 Matriz Resumen de Entregables por Día

| Día | Nombre del Módulo | Entregable Clave |
| :---: | :--- | :--- |
| **Día 1-2** | Infraestructura & Simulación | PostgreSQL 16 en Docker + Datos de Cosecha (65k filas) |
| **Día 3-4** | Profiling & Cleaning | Diagnóstico de calidad + Vistas limpias validadas |
| **Día 5** | Business Analysis SQL | 14 preguntas de negocio con CTEs, `LAG()` y pivotes |
| **Día 6** | **SQL Avanzado & Pipelines** | **RFM con `NTILE(5)` + Pipelines automatizados (`src/pipeline/`)** |
| **Día 7** | **Power BI Analytics** | **Dashboard Ejecutivo interactivo (.pbix + capturas)** |
| **Día 8** | **Forecasting de Demanda** | **Modelos XGBoost/Prophet + Feature Engineering** |
| **Día 9** | **MLOps: Tracking & Testing** | **MLflow Experiment Tracking + Suite de tests con Pytest** |
| **Día 10** | **MLOps: CI/CD & Deploy** | **API FastAPI + GitHub Actions + README Final de Portafolio** |
