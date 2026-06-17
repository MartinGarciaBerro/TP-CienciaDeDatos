"""
ingesta.py — Carga los tres datasets a DuckDB en formato Parquet.

Datasets:
  - GDSC2-dataset.csv        → raw_drugresponse.parquet    (Dataset A)
  - Compounds-annotation.csv → raw_compounds.parquet       (Dataset B)
  - Cell_Lines_Details.xlsx  → raw_cell_lines.parquet      (Dataset C)
"""
import duckdb

DUCKDB_PATH = "TPO_DATA.duckdb"

SOURCES = [
    {
        "name": "drug_response",
        "input": "GDSC2-dataset.csv",
        "output": "raw_drugresponse.parquet",
        "read_sql": "SELECT * FROM read_csv_auto('GDSC2-dataset.csv')",
    },
    {
        "name": "compounds_annotation",
        "input": "Compounds-annotation.csv",
        "output": "raw_compounds.parquet",
        "read_sql": "SELECT * FROM read_csv_auto('Compounds-annotation.csv')",
    },
    {
        "name": "cell_lines_details",
        "input": "Cell_Lines_Details.xlsx",
        "output": "raw_cell_lines.parquet",
        "read_sql": None,   # xlsx requiere pandas, ver abajo
    },
]


def ingest_csv(conn: duckdb.DuckDBPyConnection, source: dict) -> None:
    query = f"""
        COPY ({source['read_sql']})
        TO '{source['output']}' (FORMAT PARQUET);
    """
    conn.execute(query)
    print(f"  ✓ {source['input']} → {source['output']}")


def ingest_xlsx(conn: duckdb.DuckDBPyConnection, source: dict) -> None:
    import pandas as pd

    df = pd.read_excel(source["input"])
    # Limpiar nombres de columna con saltos de línea
    df.columns = [c.replace("\n", "\n") for c in df.columns]  # se preservan para dbt
    conn.execute(f"COPY (SELECT * FROM df) TO '{source['output']}' (FORMAT PARQUET)")
    print(f"  ✓ {source['input']} → {source['output']}")


def main() -> None:
    conn = duckdb.connect(DUCKDB_PATH)
    print("Iniciando ingesta de datos...\n")

    for source in SOURCES:
        if source["input"].endswith(".xlsx"):
            ingest_xlsx(conn, source)
        else:
            ingest_csv(conn, source)

    conn.close()
    print("\nIngesta completada. Todos los archivos Parquet generados.")


if __name__ == "__main__":
    main()
