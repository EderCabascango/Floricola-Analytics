import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)  # reproducibilidad: siempre genera los mismos "aleatorios"

OUTPUT_DIR = Path(__file__).parent.parent / "data" / "raw"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# --- variedad ---
variedades = [
    {"nombre": "Freedom",        "tipo": "Rosa",       "color": "Rojo"},
    {"nombre": "Explorer",       "tipo": "Rosa",       "color": "Rojo"},
    {"nombre": "Vendela",        "tipo": "Rosa",       "color": "Blanco"},
    {"nombre": "Mondial",        "tipo": "Rosa",       "color": "Blanco"},
    {"nombre": "Pink Floyd",     "tipo": "Rosa",       "color": "Rosado"},
    {"nombre": "Circus",         "tipo": "Rosa",       "color": "Bicolor"},
    {"nombre": "Million Star",   "tipo": "Gypsophila", "color": "Blanco"},
    {"nombre": "Clavel Estandar","tipo": "Clavel",     "color": "Rojo"},
]

df_variedad = pd.DataFrame(variedades)
df_variedad.insert(0, "variedad_id", range(1, len(df_variedad) + 1))

df_variedad.to_csv(OUTPUT_DIR / "variedad.csv", index=False)
print(f"variedad.csv generado: {len(df_variedad)} filas")
print(df_variedad)

# --- bloque ---
N_BLOQUES = 18

bloque_variedad_id = np.random.choice(df_variedad["variedad_id"], size=N_BLOQUES)
hectareas = np.round(np.random.uniform(1.5, 8.0, size=N_BLOQUES), 2)

df_bloque = pd.DataFrame({
    "bloque_id": range(1, N_BLOQUES + 1),
    "codigo": [f"B{str(i).zfill(2)}" for i in range(1, N_BLOQUES + 1)],
    "hectareas": hectareas,
    "variedad_id": bloque_variedad_id,
})

df_bloque.to_csv(OUTPUT_DIR / "bloque.csv", index=False)
print(f"\nbloque.csv generado: {len(df_bloque)} filas")
print(df_bloque.head(10))

# --- cuarto_frio ---
N_CUARTOS = 4

df_cuarto_frio = pd.DataFrame({
    "cuarto_frio_id": range(1, N_CUARTOS + 1),
    "codigo": [f"CF{str(i).zfill(2)}" for i in range(1, N_CUARTOS + 1)],
    "temperatura_objetivo": np.round(np.random.uniform(1.0, 4.0, size=N_CUARTOS), 1),
    "capacidad_cajas": np.random.choice([500, 800, 1000, 1200], size=N_CUARTOS),
})

df_cuarto_frio.to_csv(OUTPUT_DIR / "cuarto_frio.csv", index=False)
print(f"\ncuarto_frio.csv generado: {len(df_cuarto_frio)} filas")
print(df_cuarto_frio)

# --- cliente ---
from faker import Faker

fake = Faker()
Faker.seed(42)

N_CLIENTES = 28

# Distribución realista de países destino para exportación florícola
paises = (
    ["USA"] * 10 +
    ["Rusia"] * 5 +
    ["Países Bajos"] * 5 +
    ["Reino Unido"] * 3 +
    ["Canadá"] * 3 +
    ["España"] * 2
)
np.random.shuffle(paises)

tipos_cliente = np.random.choice(
    ["Importador", "Broker", "Retailer"],
    size=N_CLIENTES,
    p=[0.5, 0.3, 0.2]  # la mayoría son importadores
)

df_cliente = pd.DataFrame({
    "cliente_id": range(1, N_CLIENTES + 1),
    "nombre": [fake.company() for _ in range(N_CLIENTES)],
    "pais_destino": paises,
    "tipo": tipos_cliente,
})

df_cliente.to_csv(OUTPUT_DIR / "cliente.csv", index=False)
print(f"\ncliente.csv generado: {len(df_cliente)} filas")
print(df_cliente.head(10))

# --- aerolinea ---
aerolineas = [
    {"nombre": "KLM Cargo",        "codigo_iata": "KL"},
    {"nombre": "American Airlines","codigo_iata": "AA"},
    {"nombre": "LATAM Cargo",      "codigo_iata": "LA"},
    {"nombre": "Avianca Cargo",    "codigo_iata": "AV"},
    {"nombre": "Aeroflot Cargo",   "codigo_iata": "SU"},
]

df_aerolinea = pd.DataFrame(aerolineas)
df_aerolinea.insert(0, "aerolinea_id", range(1, len(df_aerolinea) + 1))

df_aerolinea.to_csv(OUTPUT_DIR / "aerolinea.csv", index=False)
print(f"\naerolinea.csv generado: {len(df_aerolinea)} filas")
print(df_aerolinea)

# --- agencia_carga ---
N_AGENCIAS = 9

df_agencia_carga = pd.DataFrame({
    "agencia_carga_id": range(1, N_AGENCIAS + 1),
    "nombre": [fake.company() + " Logistics" for _ in range(N_AGENCIAS)],
    "pais": np.random.choice(["Ecuador", "USA", "Países Bajos"], size=N_AGENCIAS),
})

df_agencia_carga.to_csv(OUTPUT_DIR / "agencia_carga.csv", index=False)
print(f"\nagencia_carga.csv generado: {len(df_agencia_carga)} filas")
print(df_agencia_carga)