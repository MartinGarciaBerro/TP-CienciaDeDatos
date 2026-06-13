{{ config(materialized='table') }}
SELECT * FROM {{ source('capa_raw', 'drug_response') }}