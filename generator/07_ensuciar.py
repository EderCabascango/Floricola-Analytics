import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)

BASE_DIR = Path(__file__).parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"

df_cliente = pd.read_csv(RAW_DIR / "cliente.csv")
df_venta = pd.read_csv(RAW_DIR / "venta.csv")

# --- 1. Nombres de cliente con mayusculas/espacios inconsistentes (~10%) ---
mask_nombre = np.random.random(len(df_cliente)) < 0.10
idx_nombre = df_cliente[mask_nombre].index

def ensuciar_nombre(nombre):
    variante = np.random.choice(["upper", "lower", "espacios"])
    if variante == "upper":
        return nombre.upper()
    elif variante == "lower":
        return nombre.lower()
    else:
        return f"  {nombre}  "

df_cliente.loc[idx_nombre, "nombre"] = df_cliente.loc[idx_nombre, "nombre"].apply(ensuciar_nombre)

# --- 2. Pais escrito de varias formas (~15% de las filas de USA) ---
mask_usa = df_cliente["pais_destino"] == "USA"
idx_usa = df_cliente[mask_usa].sample(frac=0.4, random_state=42).index
variantes_usa = ["Usa", "USA", "U.S.A.", "Estados Unidos", "usa "]
df_cliente.loc[idx_usa, "pais_destino"] = np.random.choice(variantes_usa, size=len(idx_usa))

# --- 3. Duplicados exactos de cliente (5 filas duplicadas con nuevo ID) ---
duplicados = df_cliente.sample(n=5, random_state=42).copy()
nuevo_id_inicio = df_cliente["cliente_id"].max() + 1
duplicados["cliente_id"] = range(nuevo_id_inicio, nuevo_id_inicio + 5)
df_cliente = pd.concat([df_cliente, duplicados], ignore_index=True)

# --- 4. Espacios extra en 'tipo' (~5%) ---
mask_tipo = np.random.random(len(df_cliente)) < 0.05
idx_tipo = df_cliente[mask_tipo].index
df_cliente.loc[idx_tipo, "tipo"] = df_cliente.loc[idx_tipo, "tipo"] + "  "

df_cliente.to_csv(RAW_DIR / "cliente.csv", index=False)
print(f"cliente.csv ensuciado: {len(df_cliente)} filas totales ({len(duplicados)} duplicados agregados)")

# --- 5. precio_tallo nulo en ~2% de las ventas ---
mask_precio_nulo = np.random.random(len(df_venta)) < 0.02
df_venta.loc[mask_precio_nulo, "precio_tallo"] = np.nan

df_venta.to_csv(RAW_DIR / "venta.csv", index=False)
print(f"venta.csv ensuciado: {mask_precio_nulo.sum()} precios puestos en null")