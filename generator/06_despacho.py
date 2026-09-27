import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)

BASE_DIR = Path(__file__).parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"

df_venta = pd.read_csv(RAW_DIR / "venta.csv", parse_dates=["fecha"])
df_aerolinea = pd.read_csv(RAW_DIR / "aerolinea.csv")
df_agencia = pd.read_csv(RAW_DIR / "agencia_carga.csv")

aerolinea_ids = df_aerolinea["aerolinea_id"].tolist()
agencia_ids = df_agencia["agencia_carga_id"].tolist()

# Peso promedio por tallo, con su empaque (caja + agua + tallo), en kg. Varia un poco por venta.
peso_promedio_tallo = np.random.normal(loc=0.045, scale=0.005, size=len(df_venta))
peso_promedio_tallo = np.clip(peso_promedio_tallo, 0.03, 0.07)

# ~2% de despachos aun no tienen agencia de carga asignada (recien registrados)
tiene_agencia = np.random.random(len(df_venta)) > 0.02

filas_despacho = []
for i, row in df_venta.iterrows():
    fecha_despacho = row["fecha"] + pd.Timedelta(days=int(np.random.randint(0, 3)))
    peso_kg = round(row["tallos"] * peso_promedio_tallo[i], 2)

    awb = f"{np.random.randint(100, 999)}-{np.random.randint(10000000, 99999999)}"

    filas_despacho.append({
        "despacho_id": i + 1,
        "fecha": fecha_despacho,
        "venta_id": row["venta_id"],
        "aerolinea_id": np.random.choice(aerolinea_ids),
        "agencia_carga_id": np.random.choice(agencia_ids) if tiene_agencia[i] else None,
        "awb": awb,
        "peso_kg": peso_kg,
    })

df_despacho = pd.DataFrame(filas_despacho)

# Aseguramos que el AWB sea unico (por si el azar genero un duplicado)
df_despacho = df_despacho.drop_duplicates(subset="awb", keep="first")

df_despacho.to_csv(RAW_DIR / "despacho.csv", index=False)

print(f"despacho.csv generado: {len(df_despacho)} filas")
print(df_despacho.head(10))
print(f"\nDespachos sin agencia de carga: {df_despacho['agencia_carga_id'].isna().sum()}")
print(f"Peso total despachado: {df_despacho['peso_kg'].sum():,.2f} kg")