{{ config(
    materialized='external',
    location='mart_BI_drugresponse.parquet'
) }}

WITH silver_data AS (
    SELECT * FROM {{ ref('stg_drugresponse') }}
),

business_aggregations AS (
    SELECT
        cancer_type,
        biological_pathway,
        drug_id,

        COUNT(curve_id) AS total_experimentos_realizados,
        ROUND(AVG(auc_value), 4) AS efectividad_promedio_auc,
        ROUND(AVG(ln_ic50), 4) AS concentracion_promedio_ic50,

        MIN(min_concentration) AS dosis_minima_historica,
        MAX(max_concentration) AS dosis_maxima_historica,

        CASE 
            WHEN AVG(auc_value) >= 0.85 THEN 'Alta Efectividad'
            WHEN AVG(auc_value) BETWEEN 0.50 AND 0.84 THEN 'Moderada'
            ELSE 'Baja Efectividad'
        END AS nivel_efectividad_droga

    FROM silver_data
    
    GROUP BY 
        cancer_type,
        biological_pathway,
        drug_id
)

SELECT * FROM business_aggregations