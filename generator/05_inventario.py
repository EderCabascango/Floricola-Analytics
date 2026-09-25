import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)

BASE_DIR = Path(__file__).parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"

df_cosecha = pd.read_csv(RAW_DIR / "cosecha.csv", parse_dates=["fecha"])
df_venta = pd.read_csv(RAW_DIR / "venta.csv", parse_dates=["fecha"])
df_cuarto_frio = pd.read_csv(RAW_DIR / "cuarto_frio.csv")

cuarto_frio_ids = df_cuarto_frio["cuarto_frio_id"].tolist()

movimientos = []
mov_id = 1

# --- Entradas: una por cada fila de cosecha ---
for _, row in df_cosecha.iterrows():
    movimientos.append({
        "movimiento_id": mov_id,
        "fecha": row["fecha"],
        "cuarto_frio_id": np.random.choice(cuarto_frio_ids),
        "cosecha_id": row["cosecha_id"],
        "tipo_movimiento": "entrada",
        "cantidad": row["tallos"],
    })
    mov_id += 1

# --- Salidas: una por cada fila de venta (sin cosecha_id especifica, es una simplificacion) ---
for _, row in df_venta.iterrows():
    # la salida ocurre 1 a 5 dias despues de la fecha de venta (tiempo de picking/empaque)
    fecha_salida = row["fecha"] + pd.Timedelta(days=int(np.random.randint(1, 6)))
    movimientos.append({
        "movimiento_id": mov_id,
        "fecha": fecha_salida,
        "cuarto_frio_id": np.random.choice(cuarto_frio_ids),
        "cosecha_id": None,
        "tipo_movimiento": "salida",
        "cantidad": row["tallos"],
    })
    mov_id += 1

# --- Mermas: aprox 8% de las cosechas generan una merma pequeña (3% a 12% de esos tallos) ---
mask_merma = np.random.random(len(df_cosecha)) < 0.08
df_merma_source = df_cosecha[mask_merma]

for _, row in df_merma_source.iterrows():
    fraccion_merma = np.random.uniform(0.03, 0.12)
    cantidad_merma = int(round(row["tallos"] * fraccion_merma))
    if cantidad_merma <= 0:
        continue
    fecha_merma = row["fecha"] + pd.Timedelta(days=int(np.random.randint(3, 10)))
    movimientos.append({
        "movimiento_id": mov_id,
        "fecha": fecha_merma,
        "cuarto_frio_id": np.random.choice(cuarto_frio_ids),
        "cosecha_id": row["cosecha_id"],
        "tipo_movimiento": "merma",
        "cantidad": cantidad_merma,
    })
    mov_id += 1

df_inventario = pd.DataFrame(movimientos).sort_values("fecha").reset_index(drop=True)
df_inventario["movimiento_id"] = range(1, len(df_inventario) + 1)

df_inventario.to_csv(RAW_DIR / "inventario_movimiento.csv", index=False)

print(f"inventario_movimiento.csv generado: {len(df_inventario)} filas")
print(df_inventario["tipo_movimiento"].value_counts())
print("\nCantidad total por tipo:")
print(df_inventario.groupby("tipo_movimiento")["cantidad"].sum())