{{ config(materialized='table') }}

/*
    dim_cancer: Dimensión de tipos de cáncer derivada del GDSC2.
    Una fila por tipo de cáncer único.
    Join key con hechos: cancer_type
*/

WITH base AS (
    SELECT DISTINCT
        COALESCE(UPPER(TRIM(TCGA_DESC)), 'UNCLASSIFIED')   AS cancer_type,
        CASE
            WHEN TCGA_DESC IN ('BRCA','OV','UCEC','CESC','PRAD')
                THEN 'Reproductive'
            WHEN TCGA_DESC IN ('LUAD','LUSC','MESO','SCLC')
                THEN 'Thoracic'
            WHEN TCGA_DESC IN ('COREAD','STAD','ESCA','LIHC','PAAD')
                THEN 'Gastrointestinal'
            WHEN TCGA_DESC IN ('GBM','LGG','MB','NB')
                THEN 'Neural'
            WHEN TCGA_DESC IN ('LAML','ALL','CLL','DLBC','LCML','MM')
                THEN 'Hematological'
            WHEN TCGA_DESC IN ('SKCM','HNSC','BLCA','KIRC','THCA','ACC')
                THEN 'Other Solid'
            ELSE 'Unclassified'
        END                                                 AS cancer_group

    FROM {{ ref('bronze_drugresponse') }}
)

SELECT * FROM base
ORDER BY cancer_type
