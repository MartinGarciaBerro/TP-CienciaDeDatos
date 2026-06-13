# Para ver el Informe de calidad, ver el archivo qualityDoc.md

## PASO 1: Descargate el CSV y pegalo en la raíz del proyecto

https://www.kaggle.com/datasets/samiraalipour/genomics-of-drug-sensitivity-in-cancer-gdsc
es el csv que se llama GDSC2-dataset.csv

## PASO 2: Crean y activan el entorno virtual e instalan dependencias

python -m venv venv  
.\venv\Scripts\activate  
(Creo que en mac es distinto)  
pip install dbt-duckdb pandas pyarrow duckdb

## PASO 3: Ingestar datos

Ejecuta solamente el script de python 'ingesta.py', eso va a convertir el csv en .parquet y va a guardarlo en duckdb. Deberían ver el archivo raw_drugresponse.parquet en la raíz del proyecto

## PASO 4: Ejecutar

ejecuta el comando:  
dbt build --profiles-dir .  
Eso va a construír el pipeline dbt y crear las tablas de staging y mart (BI y ML)  
Además va a ejecutar los tests de los schema.yml

## PASO 5: Ver las tablas

Todo el resultado se guarda en el archivo .duckdb que tienen en la raíz del proyecto  
Para ver las tablas pueden descargarse alguna extensión o usar alguna app. Yo uso beekeeper y me anda espectacular, no tienen ni que crear la conexión, van al archivo .duckdb y ponen abrir con beekeeper

## etc

Lo importante del proyecto está en la carpeta models, ahí pueden ver los scripts sql de cada capa y las validaciones que se hacen con el schema.yml

Si quieren ver una documentación autogenerada, pueden usar los comandos:  
dbt docs generate  
dbt docs serve

Es un poco más visual
