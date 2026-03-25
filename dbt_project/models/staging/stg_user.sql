-- models/staging/stg_customer_account.sql
{{
    config(
        materialized='view',
        schema='staging'
    )
}}

WITH cleaned_user AS (
    SELECT
        user_id,
        -- Standardize names
        {{ handle_issue('first_name') }} AS first_name,
        {{ handle_issue('last_name') }} AS last_name,
        -- Clean gender
        {{ handle_issue('gender', 'Others') }} AS gender,
        -- Clean email
        CASE
            WHEN CONTAINS(email, '_at_') = TRUE 
                THEN LOWER(REPLACE(TRIM(email), '_at_', '@'))
            ELSE LOWER(TRIM(email))
        END AS email,
        country,
        TRY_CAST(signup_date AS DATE) AS signup_date,
        -- Clean lead_source
        {{ handle_issue('lead_source', 'Others') }} AS lead_source,
        -- Clean phone
        CASE
            WHEN phone IS NULL 
                THEN NULL
            ELSE REGEXP_REPLACE(phone, '[^0-9]', '', 'g')
        END AS phone,
        TRY_CAST(created_date AS DATETIME) AS created_at
    FROM {{ source('raw_data', 'users') }}
)

SELECT * 
FROM cleaned_user