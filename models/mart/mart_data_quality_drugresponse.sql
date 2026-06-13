{{ config(materialized='table') }}

WITH quality_metrics AS (
    SELECT
        'bronze_drugresponse' AS table_name,
        'completitud' AS quality_dimension,
        'NLME_CURVE_ID' AS column_name,
        'No se permiten valores nulos' AS rule,
        COUNT(*) AS total_records,
        SUM(CASE WHEN NLME_CURVE_ID IS NULL THEN 1 ELSE 0 END) AS failed_records,
        100.0 AS threshold_pct
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'completitud', 'COSMIC_ID', 'No se permiten valores nulos', COUNT(*), SUM(CASE WHEN COSMIC_ID IS NULL THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'completitud', 'DRUG_ID', 'No se permiten valores nulos', COUNT(*), SUM(CASE WHEN DRUG_ID IS NULL THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'unicidad', 'NLME_CURVE_ID', 'Cada curva debe identificar una sola fila', COUNT(*), COUNT(*) - COUNT(DISTINCT NLME_CURVE_ID), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'validez', 'MIN_CONC', 'Debe ser mayor o igual a 0 y no nulo', COUNT(*), SUM(CASE WHEN MIN_CONC IS NULL OR MIN_CONC < 0 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'validez', 'MAX_CONC', 'Debe ser mayor o igual a 0 y no nulo', COUNT(*), SUM(CASE WHEN MAX_CONC IS NULL OR MAX_CONC < 0 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'validez', 'MIN_CONC/MAX_CONC', 'La concentracion maxima debe ser mayor o igual a la minima', COUNT(*), SUM(CASE WHEN MIN_CONC IS NULL OR MAX_CONC IS NULL OR MAX_CONC < MIN_CONC THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'validez', 'LN_IC50', 'Debe ser numerico finito y no nulo', COUNT(*), SUM(CASE WHEN LN_IC50 IS NULL OR NOT isfinite(LN_IC50) THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'validez', 'AUC', 'Debe estar entre 0 y 1', COUNT(*), SUM(CASE WHEN AUC IS NULL OR AUC < 0 OR AUC > 1 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'bronze_drugresponse', 'validez', 'RMSE', 'Debe ser mayor o igual a 0 y no nulo', COUNT(*), SUM(CASE WHEN RMSE IS NULL OR RMSE < 0 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('bronze_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'completitud', 'curve_id', 'No se permiten valores nulos', COUNT(*), SUM(CASE WHEN curve_id IS NULL THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('stg_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'unicidad', 'curve_id', 'Cada curva debe identificar una sola fila', COUNT(*), COUNT(*) - COUNT(DISTINCT curve_id), 100.0
    FROM {{ ref('stg_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'validez', 'min_concentration', 'Debe ser mayor o igual a 0 y no nulo', COUNT(*), SUM(CASE WHEN min_concentration IS NULL OR min_concentration < 0 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('stg_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'validez', 'max_concentration', 'Debe ser mayor o igual a 0 y no nulo', COUNT(*), SUM(CASE WHEN max_concentration IS NULL OR max_concentration < 0 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('stg_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'validez', 'min_concentration/max_concentration', 'La concentracion maxima debe ser mayor o igual a la minima', COUNT(*), SUM(CASE WHEN min_concentration IS NULL OR max_concentration IS NULL OR max_concentration < min_concentration THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('stg_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'validez', 'ln_ic50', 'Debe ser numerico finito y no nulo', COUNT(*), SUM(CASE WHEN ln_ic50 IS NULL OR NOT isfinite(ln_ic50) THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('stg_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'validez', 'auc_value', 'Debe estar entre 0 y 1', COUNT(*), SUM(CASE WHEN auc_value IS NULL OR auc_value < 0 OR auc_value > 1 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('stg_drugresponse') }}

    UNION ALL
    SELECT 'stg_drugresponse', 'validez', 'rmse_score', 'Debe ser mayor o igual a 0 y no nulo', COUNT(*), SUM(CASE WHEN rmse_score IS NULL OR rmse_score < 0 THEN 1 ELSE 0 END), 100.0
    FROM {{ ref('stg_drugresponse') }}
)

SELECT
    table_name,
    quality_dimension,
    column_name,
    rule,
    total_records,
    total_records - failed_records AS passed_records,
    failed_records,
    CAST(ROUND(100.0 * (total_records - failed_records) / NULLIF(total_records, 0), 2) AS DOUBLE) AS quality_score_pct,
    CAST(threshold_pct AS DOUBLE) AS threshold_pct,
    CASE
        WHEN ROUND(100.0 * (total_records - failed_records) / NULLIF(total_records, 0), 2) >= threshold_pct
            THEN 'Cumple'
        ELSE 'No cumple'
    END AS status
FROM quality_metrics
