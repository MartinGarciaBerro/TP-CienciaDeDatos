"""
ingesta.py — Carga el dataset GDSC2 a DuckDB en formato Parquet.

Dataset:
  - GDSC2-dataset.csv → raw_drugresponse.parquet (Dataset A)
"""
import duckdb

DUCKDB_PATH = "TPO_DATA.duckdb"

def main() -> None:
    conn = duckdb.connect(DUCKDB_PATH)
    print("Iniciando ingesta de datos...\n")

    conn.execute("""
        COPY (SELECT * FROM read_csv_auto('GDSC2-dataset.csv'))
        TO 'raw_drugresponse.parquet' (FORMAT PARQUET);
    """)
    print("  ✓ GDSC2-dataset.csv → raw_drugresponse.parquet")

    conn.close()
    print("\nIngesta completada.")

if __name__ == "__main__":
    main()
