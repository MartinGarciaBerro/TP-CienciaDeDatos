SELECT *
FROM {{ ref('stg_drugresponse') }}
WHERE
    min_concentration < 0
    OR max_concentration < 0
    OR max_concentration < min_concentration
    OR NOT isfinite(ln_ic50)
    OR auc_value < 0
    OR auc_value > 1
    OR rmse_score < 0
