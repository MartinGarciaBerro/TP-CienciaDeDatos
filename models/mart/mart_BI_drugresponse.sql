{{ config(
    materialized='external',
    location='mart_BI_drugresponse.parquet'
) }}

/*
    mart_BI_drugresponse — Capa Gold / Mart
    =========================================
    Modelo estrella para consumo en dashboards de BI.
    Construido únicamente con el dataset GDSC2.

    JOINs realizados:
      1. stg_drugresponse (hechos) + dim_droga  → por drug_id
      2. stg_drugresponse (hechos) + dim_cancer → por cancer_type
      3. stg_drugresponse (hechos) + dim_tiempo → por drug_id BETWEEN min AND max

    Dimensiones para filtros en el tablero:
      - Temporal:     anio_screening, fase_screening
      - Terapéutica:  pathway_name, drug_name
      - Oncológica:   cancer_type, cancer_group
      - Experimental: company_id
*/

WITH hechos AS (
    SELECT * FROM {{ ref('stg_drugresponse') }}
),

dim_droga AS (
    SELECT * FROM {{ ref('dim_droga') }}
),

dim_cancer AS (
    SELECT * FROM {{ ref('dim_cancer') }}
),

dim_tiempo AS (
    SELECT * FROM {{ ref('dim_tiempo') }}
),

-- ── JOIN 1: hechos + dimensión droga ──────────────────────────────────────
con_droga AS (
    SELECT
        h.curve_id,
        h.drug_id,
        h.cell_line_id,
        h.cancer_type,
        h.ln_ic50,
        h.auc_value,
        h.min_concentration,
        h.max_concentration,
        h.rmse_score,
        h.z_score,

        d.drug_name,
        d.pathway_name,
        d.putative_target,
        d.company_id

    FROM hechos h
    LEFT JOIN dim_droga d ON h.drug_id = d.drug_id
),

-- ── JOIN 2: + dimensión cáncer ────────────────────────────────────────────
con_cancer AS (
    SELECT
        e.*,
        c.cancer_group

    FROM con_droga e
    LEFT JOIN dim_cancer c ON e.cancer_type = c.cancer_type
),

-- ── JOIN 3: + dimensión temporal ──────────────────────────────────────────
con_tiempo AS (
    SELECT
        e.*,
        t.anio_screening,
        t.fase_screening,
        t.descripcion_fase

    FROM con_cancer e
    LEFT JOIN dim_tiempo t ON e.drug_id BETWEEN t.drug_id_min AND t.drug_id_max
),

-- ── AGREGACIÓN ────────────────────────────────────────────────────────────
agregado AS (
    SELECT
        -- DIMENSIÓN TEMPORAL
        anio_screening,
        fase_screening,
        descripcion_fase,

        -- DIMENSIÓN TERAPÉUTICA
        drug_id,
        drug_name,
        pathway_name,
        putative_target,

        -- DIMENSIÓN ONCOLÓGICA
        cancer_type,
        cancer_group,

        -- DIMENSIÓN EXPERIMENTAL
        company_id,

        -- MÉTRICAS
        COUNT(curve_id)                         AS total_experimentos,
        ROUND(AVG(auc_value), 4)                AS efectividad_promedio_auc,
        ROUND(AVG(ln_ic50), 4)                  AS concentracion_promedio_ic50,
        ROUND(AVG(z_score), 4)                  AS z_score_promedio,
        ROUND(STDDEV(auc_value), 4)             AS variabilidad_auc,
        MIN(min_concentration)                   AS dosis_minima_historica,
        MAX(max_concentration)                   AS dosis_maxima_historica,

        -- CLASIFICACIÓN con ROUND antes del CASE para evitar bug de redondeo
        CASE
            WHEN ROUND(AVG(auc_value), 4) >= 0.85 THEN 'Alta Efectividad'
            WHEN ROUND(AVG(auc_value), 4) >= 0.50 THEN 'Moderada'
            ELSE 'Baja Efectividad'
        END                                     AS nivel_efectividad_droga

    FROM con_tiempo
    GROUP BY
        anio_screening, fase_screening, descripcion_fase,
        drug_id, drug_name, pathway_name, putative_target,
        cancer_type, cancer_group,
        company_id
)

SELECT * FROM agregado
ORDER BY anio_screening, drug_id, cancer_type
