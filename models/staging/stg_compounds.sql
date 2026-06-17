{{ config(materialized='view') }}

/*
    stg_compounds: Capa Silver para Compounds-annotation.csv
    Fuente: Dataset B (Compounds-annotation.csv)
    Join key con GDSC2: DRUG_ID
*/

WITH raw_compounds AS (
    SELECT * FROM {{ source('capa_raw', 'compounds_annotation') }}
),

cleaned AS (
    SELECT
        CAST(DRUG_ID AS INTEGER)                        AS drug_id,
        UPPER(TRIM(DRUG_NAME))                          AS drug_name,
        COALESCE(UPPER(TRIM(TARGET)), 'unknown')        AS drug_target_detail,
        UPPER(TRIM(TARGET_PATHWAY))                     AS drug_pathway_detail,
        UPPER(TRIM(SCREENING_SITE))                     AS screening_site,
        COALESCE(TRIM(SYNONYMS), 'unknown')             AS drug_synonyms

    FROM raw_compounds
    WHERE DRUG_ID IS NOT NULL
)

SELECT * FROM cleaned
