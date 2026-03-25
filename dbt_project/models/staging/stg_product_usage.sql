-- models/staging/stg_product_usage.sql
{{
    config(
        materialized='view',
        schema='staging'
    )
}}

WITH cleaned_product_usage AS (
    SELECT
        event_id,

        -- Clean user_id (handle unknown values)
        CASE
            WHEN user_id IN ('user_unknown', '', 'null') 
                THEN NULL
            ELSE user_id
        END AS user_id,

        feature_name,

        -- Convert timestamp
        TRY_CAST(event_timestamp AS DATETIME) AS event_timestamp,

        -- Clean user email
        CASE
            WHEN CONTAINS(user_email, '_at_') = TRUE 
                THEN LOWER(REPLACE(TRIM(user_email), '_at_', '@'))
            ELSE LOWER(TRIM(user_email))
        END AS user_email,

        session_id,
        properties,

        -- Extract properties from JSON
        REPLACE(JSON_EXTRACT(properties, '$.device'), '"', '') AS device,
        REPLACE(JSON_EXTRACT(properties, '$.os'), '"', '') AS os,
        REPLACE(JSON_EXTRACT(properties, '$.browser'), '"', '') AS browser,
        REPLACE(JSON_EXTRACT(properties, '$.country'), '"', '') AS country,

        -- Extract and cast session duration
        TRY_CAST(
            REPLACE(JSON_EXTRACT(properties, '$.session_duration'), '"', '') 
            AS INT
        ) AS session_duration
    FROM {{ source('raw_data', 'product_usage') }}
)

SELECT * 
FROM cleaned_product_usage