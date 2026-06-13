{{ config(materialized='view') }}

WITH raw_source AS (
    SELECT * FROM {{ ref('bronze_drugresponse') }}
),

renamed_and_cleaned AS (
    SELECT
    
        TRY_CAST(NLME_CURVE_ID AS INTEGER) AS curve_id,
        TRY_CAST(COSMIC_ID AS INTEGER) AS cell_line_id,
        TRY_CAST(DRUG_ID AS INTEGER) AS drug_id,
        
        UPPER(TRIM(CELL_LINE_NAME)) AS cell_line_name,
        COALESCE(SANGER_MODEL_ID, 'unknown') AS sanger_model_id,
        COALESCE(TCGA_DESC, 'UNCLASSIFIED') AS cancer_type,
        COALESCE(DRUG_NAME, 'unknown') AS drug_name,
        COALESCE(PATHWAY_NAME, 'unknown') AS biological_pathway,
        COALESCE(PUTATIVE_TARGET, 'unknown') AS drug_target,
        COALESCE(COMPANY_ID, 'unknown') AS company_id,
        

        CASE 
            WHEN WEBRELEASE IN ('Y', 'N') THEN WEBRELEASE 
            ELSE 'unknown' 
        END AS is_public,

        TRY_CAST(MIN_CONC AS FLOAT) AS min_concentration,
        TRY_CAST(MAX_CONC AS FLOAT) AS max_concentration,
        TRY_CAST(LN_IC50 AS FLOAT) AS ln_ic50,
        TRY_CAST(AUC AS FLOAT) AS auc_value,
        TRY_CAST(RMSE AS FLOAT) AS rmse_score,
        TRY_CAST(Z_SCORE AS FLOAT) AS z_score

    FROM raw_source
)

SELECT * FROM renamed_and_cleaned
WHERE 
    curve_id IS NOT NULL 
    AND cell_line_id IS NOT NULL 
    AND drug_id IS NOT NULL
    AND ln_ic50 IS NOT NULL
    AND auc_value BETWEEN 0 AND 1 
    AND rmse_score >= 0           
    AND min_concentration >= 0
    AND max_concentration >= 0