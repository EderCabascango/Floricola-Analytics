import pandas as pd
from pathlib import Path
from sqlalchemy import create_engine
from dotenv import load_dotenv
import os

BASE_DIR = Path(__file__).parent.parent
RAW_DIR = BASE_DIR / "data" / "raw"

load_dotenv(BASE_DIR / ".env")

DB_URL = (
    f"postgresql+psycopg2://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}"
    f"@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
)
engine = create_engine(DB_URL)

# Orden obligatorio: dimensiones primero, luego cosecha que depende de bloque
TABLAS_EN_ORDEN = ["variedad", "bloque", "cuarto_frio", "cliente", "aerolinea", "agencia_carga", "cosecha"]

for tabla in TABLAS_EN_ORDEN:
    df = pd.read_csv(RAW_DIR / f"{tabla}.csv")
    df.to_sql(tabla, engine, if_exists="append", index=False)
    print(f"{tabla}: {len(df)} filas cargadas")

print("\nCarga completa.")