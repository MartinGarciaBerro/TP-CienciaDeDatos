{{ config(
    materialized='external',
    location='mart_ML_drugresponse.parquet'
) }}

WITH silver_data AS (
    SELECT * FROM {{ ref('stg_drugresponse') }}
),

features AS (
    SELECT
        curve_id,
        drug_id,
        cell_line_id,

        ln_ic50,
        auc_value,

        min_concentration,
        max_concentration,
        rmse_score,
        z_score,

        cancer_type,
        biological_pathway,

        CASE 
            WHEN is_public = 'Y' THEN 1 
            ELSE 0 
        END AS is_public_binary,

        -- Amplitud de dosis
        (max_concentration - min_concentration) AS dose_amplitude

    FROM silver_data
    
    --Preguntar al pela si le interesa esta config
    WHERE biological_pathway != 'unknown'
)

SELECT * FROM features