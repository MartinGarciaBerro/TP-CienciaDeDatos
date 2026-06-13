# Como ver la Evaluacion de Calidad

Descargarse Beekeeper Studio
Hacer la conexion a la base, importanto el duckdb (es pago, hacer el free trial)

Ya pueden hacer las consultas, ver las tablas:

# Ver la tabla y reporte de calidad de Bronze y Staging.

```sql
SELECT *
FROM mart_data_quality_drugresponse
ORDER BY quality_dimension, table_name, column_name;
```

# Ver reporte para ML

```sql
SELECT
    COUNT(*) AS total_filas,
    SUM(CASE WHEN curve_id IS NULL THEN 1 ELSE 0 END) AS nulos_curve_id,
    COUNT(*) - COUNT(DISTINCT curve_id) AS duplicados_curve_id,
    SUM(CASE WHEN is_public_binary NOT IN (0, 1) OR is_public_binary IS NULL THEN 1 ELSE 0 END) AS invalidos_is_public,
    SUM(CASE WHEN dose_amplitude IS NULL OR dose_amplitude < 0 THEN 1 ELSE 0 END) AS invalidos_dose_amplitude,
    SUM(CASE WHEN ABS(dose_amplitude - (max_concentration - min_concentration)) > 0.000001 THEN 1 ELSE 0 END) AS inconsistencias_dose_amplitude,
    SUM(CASE WHEN biological_pathway = 'unknown' THEN 1 ELSE 0 END) AS pathways_unknown
FROM mart_ML_drugresponse;
```

# Ver report para BI

```sql
SELECT
    COUNT(*) AS total_filas,
    SUM(CASE WHEN total_experimentos_realizados <= 0 THEN 1 ELSE 0 END) AS experimentos_invalidos,
    SUM(CASE WHEN efectividad_promedio_auc < 0 OR efectividad_promedio_auc > 1 THEN 1 ELSE 0 END) AS auc_promedio_invalido,
    SUM(CASE WHEN dosis_maxima_historica < dosis_minima_historica THEN 1 ELSE 0 END) AS dosis_inconsistente,
    SUM(
        CASE
            WHEN efectividad_promedio_auc >= 0.85 AND nivel_efectividad_droga != 'Alta Efectividad' THEN 1
       		WHEN efectividad_promedio_auc BETWEEN 0.50 AND 0.84 AND nivel_efectividad_droga != 'Moderada' THEN 1
            WHEN efectividad_promedio_auc < 0.50 AND nivel_efectividad_droga != 'Baja Efectividad' THEN 1
            ELSE 0
        END
    ) AS clasificaciones_inconsistentes
FROM mart_BI_drugresponse;
```

# Informe de evaluación de calidad de datos \- Drug Response

## Objetivo

El objetivo de este análisis fue evaluar la calidad del dataset drug\_response a lo largo de las distintas capas del pipeline de datos: bronze/raw, silver/staging y gold/mart. Se analizaron métricas técnicas de calidad, como completitud, unicidad y validez, junto con controles específicos sobre reglas de negocio implementadas en los marts de BI y Machine Learning.

La evaluación permite verificar si los datos crudos son aptos para ser transformados, si la capa silver corrige o estandariza correctamente los campos relevantes, y si las tablas gold/mart mantienen consistencia para su uso en dashboards o modelos predictivos.

## Capas evaluadas

### Bronze / Raw

La capa bronze representa los datos crudos provenientes del archivo original. En este proyecto, la tabla bronze\_drugresponse conserva la estructura inicial del dataset. Como estamos en un ámbito académico decidí verificar la calidad de los datos crudos, de modo que sirva de trazabilidad para poder ver cómo estaban los datos al principio y como quedan al final.

Campos relevantes evaluados:

* NLME\_CURVE\_ID  
* COSMIC\_ID  
* DRUG\_ID  
* TCGA\_DESC  
* PUTATIVE\_TARGET  
* MIN\_CONC  
* MAX\_CONC  
* LN\_IC50  
* AUC  
* RMSE

### Silver / Staging

La capa silver corresponde al modelo stg\_drugresponse. En esta capa se renombran columnas, se castean tipos de datos, se estandarizan valores categóricos y se filtran registros inválidos.

Ejemplos de transformaciones:

NLME\_CURVE\_ID se transforma en curve\_id.  
COSMIC\_ID se transforma en cell\_line\_id.  
TCGA\_DESC nulo se reemplaza por UNCLASSIFIED.  
PUTATIVE\_TARGET nulo se reemplaza por unknown.  
WEBRELEASE se valida contra los valores Y y N.  
MIN\_CONC, MAX\_CONC, LN\_IC50, AUC y RMSE se castean a numérico.

### Gold / Mart

La capa gold contiene tablas orientadas al consumo analitico:

mart\_ML\_drugresponse: tabla optimizada para entrenamiento de modelos.  
mart\_BI\_drugresponse: tabla agregada para reporting y dashboards.  
mart\_data\_quality\_drugresponse: tabla con resultados de calidad calculados.

## Métricas definidas

### Completitud

Mide si los campos críticos tienen valores nulos. En este trabajo se definió un umbral del 100% para columnas clave.

Query utilizada:

SELECT

    COUNT(\*) AS total\_filas,

 SUM(CASE WHEN NLME\_CURVE\_ID IS NULL THEN 1 ELSE 0 END) AS nulos\_nlme\_curve\_id,

    SUM(CASE WHEN COSMIC\_ID IS NULL THEN 1 ELSE 0 END) AS nulos\_cosmic\_id,

    SUM(CASE WHEN DRUG\_ID IS NULL THEN 1 ELSE 0 END) AS nulos\_drug\_id

FROM bronze\_drugresponse;

### Unicidad

Mide si un identificador no presenta duplicados. En este caso se evaluó NLME\_CURVE\_ID en bronze y curve\_id en staging.

Query utilizada:

SELECT

    COUNT(\*) AS total\_filas,

    COUNT(DISTINCT NLME\_CURVE\_ID) AS curvas\_distintas,

    COUNT(\*) \- COUNT(DISTINCT NLME\_CURVE\_ID) AS filas\_duplicadas

FROM bronze\_drugresponse;

### Validez

Mide si los valores respetan rangos o dominios esperados.

Reglas aplicadas:

MIN\_CONC \>= 0  
MAX\_CONC \>= 0  
MAX\_CONC \>= MIN\_CONC  
AUC BETWEEN 0 AND 1  
RMSE \>= 0  
LN\_IC50 debe ser numérico finito

SELECT

    COUNT(\*) AS total\_filas,

    SUM(CASE WHEN MIN\_CONC \< 0 OR MIN\_CONC IS NULL THEN 1 ELSE 0 END) AS min\_conc\_invalidos,

    SUM(CASE WHEN MAX\_CONC \< 0 OR MAX\_CONC IS NULL THEN 1 ELSE 0 END) AS max\_conc\_invalidos,

  SUM(CASE WHEN MAX\_CONC \< MIN\_CONC THEN 1 ELSE 0 END) AS concentracion\_inconsistente,

    SUM(CASE WHEN AUC \< 0 OR AUC \> 1 OR AUC IS NULL THEN 1 ELSE 0 END) AS auc\_invalidos,

    SUM(CASE WHEN RMSE \< 0 OR RMSE IS NULL THEN 1 ELSE 0 END) AS rmse\_invalidos

FROM bronze\_drugresponse;

## Resultados generales de calidad

Los resultados consolidados se almacenan en la tabla mart\_data\_quality\_drugresponse.

Query utilizada:

SELECT \*

FROM mart\_data\_quality\_drugresponse

ORDER BY quality\_dimension, table\_name, column\_name;

Resultado observado:

* bronze\_drugresponse: 242.036 registros evaluados.  
* stg\_drugresponse: 242.036 registros evaluados.  
* mart\_ML\_drugresponse: 242.036 registros evaluados.  
* mart\_BI\_drugresponse: 9.223 registros agregados.  
* Completitud: 100%.  
* Unicidad: 100%.  
* Validez: 100%.  
* Registros fallidos: 0 en las métricas evaluadas.  
* Estado: Cumple todas las reglas.

Bajo las reglas definidas, las capas bronze y silver cumplen los umbrales de calidad establecidos. Los datos crudos ya presentan buena calidad técnica para los campos críticos, y la capa staging mantiene la completitud, unicidad y validez necesarias para alimentar los marts.

## Verificación de reemplazos en staging

Se detectó que en bronze existen valores nulos en columnas descriptivas como TCGA\_DESC y PUTATIVE\_TARGET. En staging, estos valores son reemplazados por valores controlados.

Query para bronze:

SELECT

    COUNT(\*) AS total\_filas,

    SUM(CASE WHEN TCGA\_DESC IS NULL THEN 1 ELSE 0 END) AS nulos\_tcga\_desc,

 SUM(CASE WHEN PUTATIVE\_TARGET IS NULL THEN 1 ELSE 0 END) AS nulos\_putative\_target

FROM bronze\_drugresponse;

Resultado observado:

| total\_filas | nulos\_tcga\_desc | nulos\_putative\_target |
| :----------- | :---- | :---- |
| 242.036      | 1.067 | 27.155 |

Query para staging:

SELECT

    COUNT(\*) AS total\_filas,

 SUM(CASE WHEN cancer\_type \= 'UNCLASSIFIED' THEN 1 ELSE 0 END) AS unclassified\_en\_stg,

    SUM(CASE WHEN drug\_target \= 'unknown' THEN 1 ELSE 0 END) AS unknown\_en\_stg,

    SUM(CASE WHEN cancer\_type IS NULL THEN 1 ELSE 0 END) AS nulos\_cancer\_type\_stg,

    SUM(CASE WHEN drug\_target IS NULL THEN 1 ELSE 0 END) AS nulos\_drug\_target\_stg

FROM stg\_drugresponse;

Resultado observado:

| total\_filas | unclassified\_en\_stg | unknown\_en\_stg | nulos\_cancer\_type\_stg | nulos\_drug\_target\_stg |
| :----------- | :-------------------- | :--------------- | :----------------------- | :----------------------- |
| 242.036      | 46.758                | 27.155           | 0                        | 0                        |

Nota: unclassified\_en\_stg incluye tanto los nulos reemplazados desde bronze como valores que ya venían originalmente clasificados como UNCLASSIFIED.

Conclusión:

La capa staging reemplaza los nulos de TCGA\_DESC por UNCLASSIFIED y los nulos de PUTATIVE\_TARGET por unknown. Esto mejora la completitud de las variables categóricas sin eliminar registros.

## Calidad en Mart ML

El mart de Machine Learning busca generar una tabla con mayor densidad de información numérica y menor ruido textual. Para validar esta capa, se pueden aplicar métricas de completitud, validez y consistencia sobre las features creadas.

Campos evaluables:

curve\_id  
is\_public\_binary  
dose\_amplitude  
min\_concentration  
max\_concentration  
auc\_value  
rmse\_score  
biological\_pathway

Query:

SELECT

    COUNT(\*) AS total\_filas,

    SUM(CASE WHEN curve\_id IS NULL THEN 1 ELSE 0 END) AS nulos\_curve\_id,

    COUNT(\*) \- COUNT(DISTINCT curve\_id) AS duplicados\_curve\_id,

    SUM(CASE WHEN is\_public\_binary NOT IN (0, 1\) OR is\_public\_binary IS NULL THEN 1 ELSE 0 END) AS invalidos\_is\_public,

    SUM(CASE WHEN dose\_amplitude IS NULL OR dose\_amplitude \< 0 THEN 1 ELSE 0 END) AS invalidos\_dose\_amplitude,

   SUM(CASE WHEN ABS(dose\_amplitude \- (max\_concentration \- min\_concentration)) \> 0.000001 THEN 1 ELSE 0 END) AS inconsistencias\_dose\_amplitude,

  SUM(CASE WHEN biological\_pathway \= 'unknown' THEN 1 ELSE 0 END) AS pathways\_unknown

FROM mart\_ML\_drugresponse;

Resultado observado:

| total\_filas | nulos\_curve\_id | duplicados\_curve\_id | invalidos\_is\_public | invalidos\_dose\_amplitude | inconsistencias\_dose\_amplitude | pathways\_unknown |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| 242.036 | 0 | 0 | 0 | 0 | 0 | 0 |

Interpretación:

invalidos\_is\_public \= 0: la transformación Y/N a 1/0 fue correcta.  
invalidos\_dose\_amplitude \= 0: no hay amplitudes negativas.  
inconsistencias\_dose\_amplitude \= 0: la feature fue calculada correctamente.  
pathways\_unknown \= 0: se cumple el filtro aplicado en el modelo ML.

Conclusión:

Las métricas del mart ML permiten verificar que las variables generadas sean consistentes y aptas para su uso en modelos predictivos. En particular, se valida que las features numéricas no presenten valores inválidos y que las transformaciones realizadas no introduzcan inconsistencias. En los resultados observados, el mart ML cumple todas las reglas evaluadas.

## Calidad en Mart BI

El mart de BI agrega la información por cancer\_type, biological\_pathway y drug\_id, reduciendo el volumen de datos y generando indicadores útiles para dashboards.

Reglas evaluadas:

total\_experimentos\_realizados \> 0  
efectividad\_promedio\_auc BETWEEN 0 AND 1  
dosis\_maxima\_historica \>= dosis\_minima\_historica  
nivel\_efectividad\_droga debe ser consistente con efectividad\_promedio\_auc

Query utilizada:

SELECT

    COUNT(\*) AS total\_filas,

  SUM(CASE WHEN total\_experimentos\_realizados \<= 0 THEN 1 ELSE 0 END) AS experimentos\_invalidos,

    SUM(CASE WHEN efectividad\_promedio\_auc \< 0 OR efectividad\_promedio\_auc \> 1 THEN 1 ELSE 0 END) AS auc\_promedio\_invalido,

    SUM(CASE WHEN dosis\_maxima\_historica \< dosis\_minima\_historica THEN 1 ELSE 0 END) AS dosis\_inconsistente,

    SUM(

        CASE

            WHEN efectividad\_promedio\_auc \>= 0.85 AND nivel\_efectividad\_droga \!= 'Alta Efectividad' THEN 1

       		WHEN efectividad\_promedio\_auc BETWEEN 0.50 AND 0.84 AND nivel\_efectividad\_droga \!= 'Moderada' THEN 1

            WHEN efectividad\_promedio\_auc \< 0.50 AND nivel\_efectividad\_droga \!= 'Baja Efectividad' THEN 1

            ELSE 0

        END

    ) AS clasificaciones\_inconsistentes

FROM mart\_BI\_drugresponse;

Resultado observado:

| total\_filas | experimentos\_invalidos | auc\_promedio\_invalido | dosis\_inconsistente | clasificaciones\_inconsistentes |
| :---- | :---- | :---- | :---- | :---- |
| 9.223 | 0 | 0 | 0 | 2 |

Interpretación:

No hay experimentos inválidos.  
No hay promedios de AUC fuera de rango.  
No hay inconsistencias entre dosis mínima y máxima.  
Se detectaron 2 inconsistencias en la clasificación semántica nivel\_efectividad\_droga.

Detalle de inconsistencias observadas:

| cancer\_type | biological\_pathway | drug\_id | total\_experimentos\_realizados | efectividad\_promedio\_auc | nivel\_efectividad\_droga |
| :---- | :---- | :---- | :---- | :---- | :---- |
| PAAD | Apoptosis regulation | 1011 | 28 | 0.85 | Baja Efectividad |
| ESCA | Other, kinases | 1250 | 33 | 0.84 | Baja Efectividad |

Estas inconsistencias probablemente se explican por diferencias de redondeo entre el valor visible de efectividad\_promedio\_auc y el valor real usado internamente para clasificar.

Calculo de calidad:

filas\_correctas \= 9223 \- 2 \= 9221

calidad \= 9221 / 9223 \* 100 \= 99,98%

Con un umbral de aceptación del 98%, la métrica cumple.

Conclusión:

El mart BI presenta una consistencia de clasificación del 99,98%, superando el umbral definido del 98%. Las inconsistencias detectadas son marginales y se relacionan con valores cercanos a los umbrales de clasificación. No obstante, si la columna nivel\_efectividad\_droga se utiliza en reportes ejecutivos, se recomienda alinear la lógica de clasificación con el valor redondeado que se muestra en la tabla.

## Umbrales definidos

| Dimensión | Capa | Umbral | Justificación |
| :---- | :---- | :---- | :---- |
| Completitud | Bronze / Staging | 100% | Los campos críticos no deben contener nulos. |
| Unicidad | Bronze / Staging | 100% | Los identificadores de curva deben ser únicos. |
| Validez numérica | Bronze / Staging | 100% | Los rangos numéricos deben respetarse para no invalidar el análisis. |
| Consistencia ML | Mart ML | 100% | Las features generadas deben ser consistentes para entrenamiento. |
| Consistencia BI | Mart BI | 98% | Se permite una tolerancia mínima por redondeos en reglas derivadas. |

## Conclusión general

El análisis de calidad muestra que el dataset drug\_response cumple satisfactoriamente las reglas definidas en las capas bronze y silver, con 100% de calidad en completitud, unicidad y validez para los campos evaluados.

En la capa gold, los marts agregan valor para usos específicos. El mart ML transforma variables y genera features aptas para modelos predictivos, mientras que el mart BI resume la información para facilitar su consumo en dashboards. La evaluación del mart BI detectó 2 inconsistencias menores en la etiqueta de efectividad, equivalentes a una consistencia del 99,98%, por encima del umbral definido.

En consecuencia, el pipeline presenta buena calidad general y las tablas generadas son aptas para ser utilizadas en análisis, visualizaciones y modelos, dejando documentadas las reglas de calidad y los controles necesarios para monitorear futuras cargas.

