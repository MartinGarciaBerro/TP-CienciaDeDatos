#Código para pasar los datos de CSV  a Parquet y cargarlos en duck db
import duckdb

def main():
  conn = duckdb.connect('TPO_DATA.duckdb')

  query = """
        COPY (SELECT * FROM 'GDSC2-dataset.csv')
        TO 'raw_drugresponse.parquet' (FORMAT PARQUET);
        """

  conn.execute(query)
  conn.close()
  print("datos copiados")
  return

if __name__ == "__main__":
  main()