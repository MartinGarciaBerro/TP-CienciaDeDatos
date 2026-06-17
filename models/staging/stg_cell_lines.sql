{{ config(materialized='view') }}

/*
    stg_cell_lines: Capa Silver para Cell_Lines_Details.xlsx
    Fuente: Dataset C (Cell_Lines_Details.xlsx)
    Join key con GDSC2: COSMIC_ID
*/

WITH raw_cell_lines AS (
    SELECT * FROM {{ source('capa_raw', 'cell_lines_details') }}
),

cleaned AS (
    SELECT
        CAST("COSMIC identifier"            AS INTEGER)     AS cosmic_id,
        UPPER(TRIM("Sample Name"))                          AS cell_line_name,

        LOWER(TRIM("GDSC
Tissue descriptor 1"))                                      AS tissue_type_broad,
        LOWER(TRIM("GDSC
Tissue
descriptor 2"))                                             AS tissue_type_specific,

        COALESCE(
            UPPER(TRIM("Cancer Type
(matching TCGA label)")),
            'UNCLASSIFIED'
        )                                                   AS cancer_type_tcga,

        COALESCE(TRIM("Growth Properties"), 'unknown')      AS growth_properties,
        COALESCE(TRIM("Screen Medium"), 'unknown')          AS screen_medium,

        COALESCE(
            TRIM("Microsatellite 
instability Status (MSI)"),
            'unknown'
        )                                                   AS msi_status,

        CASE WHEN "Whole Exome Sequencing (WES)" = 'Y' THEN 1 ELSE 0 END   AS has_wes,
        CASE WHEN "Copy Number Alterations (CNA)" = 'Y' THEN 1 ELSE 0 END  AS has_cna,
        CASE WHEN "Gene Expression" = 'Y' THEN 1 ELSE 0 END                AS has_gene_expression,
        CASE WHEN "Methylation" = 'Y' THEN 1 ELSE 0 END                    AS has_methylation

    FROM raw_cell_lines
    WHERE "COSMIC identifier" IS NOT NULL
)

SELECT * FROM cleaned
