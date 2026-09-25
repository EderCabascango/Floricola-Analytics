import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)

BASE_DIR = Path(__file__).parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"

# Cargamos bloque.csv, porque cosecha depende de esa FK
df_bloque = pd.read_csv(RAW_DIR / "bloque.csv")

# --- Rango de fechas: 3 años de operación diaria ---
fechas = pd.date_range(start="2023-06-01", end="2026-06-01", freq="D")
print(f"Total de días a simular: {len(fechas)}")
print(f"Desde {fechas.min().date()} hasta {fechas.max().date()}")

# --- Multiplicador de estacionalidad ---
def multiplicador_estacional(fecha):
    semana = fecha.isocalendar().week
    if 3 <= semana <= 6:       # antes de San Valentín (14 feb)
        return 1.8
    elif 15 <= semana <= 18:   # antes del Día de la Madre (Ecuador: 2do domingo de mayo)
        return 1.5
    else:
        return 1.0

df_calendario = pd.DataFrame({"fecha": fechas})
df_calendario["multiplicador"] = df_calendario["fecha"].apply(multiplicador_estacional)

# Vistazo rápido: cuántos días caen en cada tipo de temporada
print(df_calendario["multiplicador"].value_counts())
print(df_calendario[df_calendario["multiplicador"] == 1.8].head(3))

# --- Producción base por bloque, proporcional a sus hectáreas ---
# Asumimos un rendimiento realista de ~1800 a 2200 tallos por hectárea, por día
df_bloque["tallos_base_ha"] = np.random.uniform(1800, 2200, size=len(df_bloque))
df_bloque["produccion_base_diaria"] = (df_bloque["tallos_base_ha"] * df_bloque["hectareas"]).round().astype(int)

print(df_bloque[["bloque_id", "codigo", "hectareas", "produccion_base_diaria"]].head())

# --- Producto cartesiano: cada bloque x cada fecha ---
df_cosecha = df_bloque[["bloque_id", "produccion_base_diaria"]].merge(
    df_calendario, how="cross"
)
print(f"\nFilas antes de filtrar: {len(df_cosecha)}")  # 18 bloques x 1097 dias

# --- Tallos cosechados reales: base x estacionalidad x ruido ---
ruido = np.random.normal(loc=1.0, scale=0.08, size=len(df_cosecha))  # +/- 8% de variacion
df_cosecha["tallos"] = (
    df_cosecha["produccion_base_diaria"] * df_cosecha["multiplicador"] * ruido
).round().astype(int)
df_cosecha["tallos"] = df_cosecha["tallos"].clip(lower=0)  # nunca negativo

# --- Largo del tallo: la mayoria entre 40 y 80 cm ---
df_cosecha["largo_cm"] = np.random.normal(loc=58, scale=12, size=len(df_cosecha)).round().astype(int)
df_cosecha["largo_cm"] = df_cosecha["largo_cm"].clip(lower=30, upper=90)

# --- Grado de calidad correlacionado con el largo: tallos mas largos -> mejor grado ---
def asignar_grado(largo):
    if largo >= 65:
        p = [0.70, 0.25, 0.05]   # mayoria A
    elif largo >= 45:
        p = [0.30, 0.55, 0.15]  # mayoria B
    else:
        p = [0.05, 0.35, 0.60]  # mayoria C
    return np.random.choice(["A", "B", "C"], p=p)

df_cosecha["grado_calidad"] = df_cosecha["largo_cm"].apply(asignar_grado)

# --- Simulamos dias de descanso: ~15% de los dias no hay corte en ese bloque ---
mask_descanso = np.random.random(len(df_cosecha)) < 0.15
df_cosecha = df_cosecha[~mask_descanso].copy()

# --- Armar el DataFrame final, con las columnas que pide el esquema SQL ---
df_cosecha_final = df_cosecha[["fecha", "bloque_id", "tallos", "grado_calidad", "largo_cm"]].copy()
df_cosecha_final.insert(0, "cosecha_id", range(1, len(df_cosecha_final) + 1))
df_cosecha_final = df_cosecha_final.sort_values(["fecha", "bloque_id"]).reset_index(drop=True)
df_cosecha_final["cosecha_id"] = range(1, len(df_cosecha_final) + 1)

df_cosecha_final.to_csv(RAW_DIR / "cosecha.csv", index=False)

print(f"\ncosecha.csv generado: {len(df_cosecha_final)} filas")
print(df_cosecha_final.head(10))
print("\nDistribucion de grado_calidad:")
print(df_cosecha_final["grado_calidad"].value_counts())
print("\nTotal de tallos cosechados en todo el periodo:", df_cosecha_final["tallos"].sum())