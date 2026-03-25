-- models/intermediate/int_product_usage.sql
{{
    config(
        materialized='view',
        schema='intermediate'
    )
}}

WITH usage AS (
    SELECT * 
    FROM {{ ref('stg_product_usage') }}
),

user AS (
    SELECT * 
    FROM {{ ref('stg_user') }}
),

cleaned_product_usage AS (
    SELECT
        p.event_id,

        -- Prioritize user_id from product_usage, fallback to user table
        CASE
            WHEN p.user_id IS NULL 
                THEN u1.user_id
            ELSE p.user_id
        END AS user_id,

        -- Prioritize user_email from product_usage, fallback to user table (skip anonymous users)
        CASE
            WHEN p.user_email IS NULL 
             AND CONTAINS(p.user_id, 'ano') = FALSE 
                THEN u2.email
            ELSE p.user_email
        END AS user_email,

        p.properties,
        p.feature_name,
        p.event_timestamp,
        p.session_id,
        p.session_duration,
        p.device,
        p.browser,
        p.os,
        p.country
    FROM usage p
    LEFT JOIN user u1
        ON p.user_email = u1.email
    LEFT JOIN user u2
        ON p.user_id = u2.user_id
)

SELECT * 
FROM cleaned_product_usage