{{ config(materialized='table') }}

/*
    dim_droga: Dimensión de drogas derivada del GDSC2.
    Una fila por droga única.
    Join key con hechos: drug_id
*/

WITH base AS (
    SELECT DISTINCT
        TRY_CAST(DRUG_ID AS INTEGER)                      AS drug_id,
        COALESCE(TRIM(DRUG_NAME), 'unknown')              AS drug_name,
        COALESCE(TRIM(PATHWAY_NAME), 'unknown')           AS pathway_name,
        COALESCE(TRIM(PUTATIVE_TARGET), 'unknown')        AS putative_target,
        TRY_CAST(COMPANY_ID AS INTEGER)                   AS company_id

    FROM {{ ref('bronze_drugresponse') }}
    WHERE TRY_CAST(DRUG_ID AS INTEGER) IS NOT NULL
)

SELECT * FROM base
