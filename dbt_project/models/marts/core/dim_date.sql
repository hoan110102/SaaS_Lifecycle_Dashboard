-- models/intermediate/int_date_dimension.sql
{{
    config(
        materialized='table',
        unique_key='date_id'
    )
}}

WITH date_spine AS (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2025-01-01' as date)",
        end_date="cast('2026-01-01' as date)"
    ) }}
),

date_extract AS (
    SELECT
        CAST(STRFTIME(date_day, '%Y%m%d') AS INT) AS date_id,
        CAST(date_day AS DATE) AS full_date,

        EXTRACT(YEAR FROM date_day) AS year,
        EXTRACT(QUARTER FROM date_day) AS quarter,
        EXTRACT(MONTH FROM date_day) AS month,
        EXTRACT(WEEK FROM date_day) AS week,
        EXTRACT(DAY FROM date_day) AS day_of_month,
        EXTRACT(DAYOFWEEK FROM date_day) AS day_of_week,

        -- Flag weekend
        CASE
            WHEN EXTRACT(DAYOFWEEK FROM date_day) IN (1, 7) 
                THEN TRUE
            ELSE FALSE
        END AS is_weekend
    FROM date_spine
)

SELECT * 
FROM date_extract