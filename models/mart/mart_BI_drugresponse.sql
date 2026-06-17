{{ config(
    materialized='external',
    location='mart_BI_drugresponse.parquet'
) }}

/*
    mart_BI_drugresponse — Capa Gold / Mart
    =========================================
    Modelo estrella para consumo en dashboards de BI.

    JOINS realizados:
      1. stg_drugresponse  ← tabla de hechos principal
      2. stg_compounds     ← dimensión droga (DRUG_ID)
      3. stg_cell_lines    ← dimensión línea celular (COSMIC_ID / cell_line_id)
      4. dim_tiempo (seed) ← dimensión temporal derivada del DRUG_ID

    DIMENSIONES disponibles para filtros en el tablero:
      - Temporal:   anio_screening, fase_screening
      - Terapéutica: drug_pathway_detail, screening_site
      - Oncológica:  cancer_type, tissue_type_broad, tissue_type_specific
      - Celular:     growth_properties, msi_status

    Granularidad de agregación:
      cancer_type + tissue_type_broad + drug_pathway_detail + drug_id + fase_screening
*/

WITH facts AS (
    SELECT * FROM {{ ref('stg_drugresponse') }}
),

dim_droga AS (
    SELECT * FROM {{ ref('stg_compounds') }}
),

dim_celula AS (
    SELECT * FROM {{ ref('stg_cell_lines') }}
),

dim_tiempo AS (
    SELECT * FROM {{ ref('dim_tiempo') }}
),

-- ──────────────────────────────────────────────
-- JOIN 1: hechos + dimensión droga
-- ──────────────────────────────────────────────
enriched_with_drug AS (
    SELECT
        f.curve_id,
        f.drug_id,
        f.cell_line_id,
        f.cancer_type,
        f.biological_pathway,
        f.ln_ic50,
        f.auc_value,
        f.min_concentration,
        f.max_concentration,
        f.rmse_score,
        f.z_score,

        -- Campos enriquecidos desde dim_droga
        d.drug_name,
        d.drug_target_detail,
        d.drug_pathway_detail,
        d.screening_site,
        d.drug_synonyms

    FROM facts f
    LEFT JOIN dim_droga d
        ON f.drug_id = d.drug_id
),

-- ──────────────────────────────────────────────
-- JOIN 2: + dimensión línea celular
-- ──────────────────────────────────────────────
enriched_with_cell AS (
    SELECT
        e.*,
        c.tissue_type_broad,
        c.tissue_type_specific,
        c.growth_properties,
        c.msi_status,
        c.has_wes,
        c.has_cna,
        c.has_gene_expression,
        c.has_methylation

    FROM enriched_with_drug e
    LEFT JOIN dim_celula c
        ON e.cell_line_id = c.cosmic_id
),

-- ──────────────────────────────────────────────
-- JOIN 3: + dimensión temporal
-- Los DRUG_IDs en GDSC2 son asignados secuencialmente según
-- el orden de incorporación al screening. Esto permite derivar
-- la fase temporal de cada experimento.
-- Referencia: Iorio et al. (2016), Yang et al. (2013)
-- ──────────────────────────────────────────────
enriched_full AS (
    SELECT
        e.*,
        t.periodo_id,
        t.anio_screening,
        t.fase_screening,
        t.descripcion_fase

    FROM enriched_with_cell e
    LEFT JOIN dim_tiempo t
        ON e.drug_id BETWEEN t.drug_id_min AND t.drug_id_max
),

-- ──────────────────────────────────────────────
-- AGREGACIÓN para BI
-- Granularidad: cancer_type + tissue_type + pathway + drug + fase temporal
-- ──────────────────────────────────────────────
business_aggregations AS (
    SELECT
        -- DIMENSIÓN TEMPORAL
        anio_screening,
        fase_screening,
        descripcion_fase,

        -- DIMENSIÓN TERAPÉUTICA / DROGA
        drug_id,
        drug_name,
        drug_pathway_detail                         AS via_biologica,
        screening_site                              AS sitio_screening,

        -- DIMENSIÓN ONCOLÓGICA / TEJIDO
        cancer_type,
        tissue_type_broad                           AS tejido_origen,
        tissue_type_specific                        AS tejido_especifico,

        -- DIMENSIÓN CELULAR / BIOLÓGICA
        growth_properties                           AS tipo_crecimiento_celular,
        msi_status                                  AS estado_msi,

        -- MÉTRICAS AGREGADAS (hechos)
        COUNT(curve_id)                             AS total_experimentos,
        ROUND(AVG(auc_value), 4)                    AS efectividad_promedio_auc,
        ROUND(AVG(ln_ic50), 4)                      AS concentracion_promedio_ic50,
        ROUND(AVG(z_score), 4)                      AS z_score_promedio,
        ROUND(STDDEV(auc_value), 4)                 AS variabilidad_auc,

        MIN(min_concentration)                      AS dosis_minima_historica,
        MAX(max_concentration)                      AS dosis_maxima_historica,

        -- Porcentaje de experimentos con datos ómicos disponibles
        ROUND(100.0 * AVG(has_wes), 1)              AS pct_con_wes,
        ROUND(100.0 * AVG(has_gene_expression), 1)  AS pct_con_gene_expression,

        -- CLASIFICACIÓN SEMÁNTICA
        -- Se aplica ROUND al valor antes de clasificar para evitar
        -- inconsistencias de redondeo (bug conocido en versión anterior)
        CASE
            WHEN ROUND(AVG(auc_value), 4) >= 0.85 THEN 'Alta Efectividad'
            WHEN ROUND(AVG(auc_value), 4) >= 0.50 THEN 'Moderada'
            ELSE 'Baja Efectividad'
        END                                         AS nivel_efectividad_droga

    FROM enriched_full
    GROUP BY
        anio_screening,
        fase_screening,
        descripcion_fase,
        drug_id,
        drug_name,
        drug_pathway_detail,
        screening_site,
        cancer_type,
        tissue_type_broad,
        tissue_type_specific,
        growth_properties,
        msi_status
)

SELECT * FROM business_aggregations
ORDER BY anio_screening, drug_id, cancer_type
