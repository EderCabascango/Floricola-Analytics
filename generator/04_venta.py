import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)

BASE_DIR = Path(__file__).parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"

df_cosecha = pd.read_csv(RAW_DIR / "cosecha.csv", parse_dates=["fecha"])
df_bloque = pd.read_csv(RAW_DIR / "bloque.csv")
df_cliente = pd.read_csv(RAW_DIR / "cliente.csv")

# Le pegamos variedad_id a cada cosecha, a traves de bloque
df_cosecha = df_cosecha.merge(df_bloque[["bloque_id", "variedad_id"]], on="bloque_id")

# Disponible por variedad y mes
df_cosecha["anio_mes"] = df_cosecha["fecha"].dt.to_period("M")
disponible = df_cosecha.groupby(["anio_mes", "variedad_id"])["tallos"].sum().reset_index()
disponible = disponible.rename(columns={"tallos": "tallos_disponibles"})

print(f"Combinaciones variedad-mes con cosecha: {len(disponible)}")
print(disponible.head(10))

# --- Cuanto de lo disponible se vende realmente (85% a 96%, el resto es reserva/merma futura) ---
disponible["fraccion_vendida"] = np.random.uniform(0.85, 0.96, size=len(disponible))
disponible["tallos_a_vender"] = (disponible["tallos_disponibles"] * disponible["fraccion_vendida"]).round().astype(int)

# --- Precio base por variedad (USD por tallo), con la gypsophila y clavel mas baratos que rosa ---
df_variedad = pd.read_csv(RAW_DIR / "variedad.csv")
precio_base_tipo = {"Rosa": 0.32, "Gypsophila": 0.14, "Clavel": 0.18}
df_variedad["precio_base"] = df_variedad["tipo"].map(precio_base_tipo)

filas_venta = []
venta_id = 1

for _, row in disponible.iterrows():
    variedad_id = row["variedad_id"]
    anio_mes = row["anio_mes"]
    tallos_restantes = row["tallos_a_vender"]

    precio_base = df_variedad.loc[df_variedad["variedad_id"] == variedad_id, "precio_base"].values[0]

    # Repartimos el total del mes en varias transacciones (entre 8 y 20 ventas por variedad-mes)
    n_transacciones = np.random.randint(8, 21)
    # Pesos aleatorios que suman 1, para repartir tallos_restantes de forma desigual (mas realista)
    pesos = np.random.dirichlet(np.ones(n_transacciones))

    fecha_inicio = anio_mes.to_timestamp()
    dias_en_mes = anio_mes.days_in_month

    for peso in pesos:
        tallos_venta = int(round(tallos_restantes * peso))
        if tallos_venta <= 0:
            continue

        cliente_id = np.random.choice(df_cliente["cliente_id"])
        empaque = np.random.choice(["FB", "HB", "QB", "EB"], p=[0.15, 0.35, 0.35, 0.15])

        # Precio con variacion: +/- 15%, y un pequeño extra en temporada alta (semana del mes simulada)
        variacion_precio = np.random.normal(loc=1.0, scale=0.08)
        precio_tallo = round(max(precio_base * variacion_precio, 0.05), 3)

        # Fecha aleatoria dentro del mes, con un pequeño desfase (la venta ocurre unos dias despues de cosechar)
        dia_random = np.random.randint(1, dias_en_mes + 1)
        fecha_venta = fecha_inicio + pd.Timedelta(days=dia_random - 1)

        filas_venta.append({
            "venta_id": venta_id,
            "fecha": fecha_venta,
            "cliente_id": cliente_id,
            "variedad_id": variedad_id,
            "empaque": empaque,
            "tallos": tallos_venta,
            "precio_tallo": precio_tallo,
        })
        venta_id += 1

df_venta = pd.DataFrame(filas_venta).sort_values("fecha").reset_index(drop=True)
df_venta["venta_id"] = range(1, len(df_venta) + 1)

df_venta.to_csv(RAW_DIR / "venta.csv", index=False)

print(f"\nventa.csv generado: {len(df_venta)} filas")
print(df_venta.head(10))
print(f"\nTotal tallos vendidos: {df_venta['tallos'].sum():,}")
print(f"Total tallos disponibles (cosechados): {df_cosecha['tallos'].sum():,}")
print(f"Ingreso total simulado: ${(df_venta['tallos'] * df_venta['precio_tallo']).sum():,.2f}")