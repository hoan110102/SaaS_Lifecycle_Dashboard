{{
    config(
        materialized = 'table',
        unique_key   = 'user_sk'
    )
}}

WITH user AS (
    SELECT *
    FROM {{ ref('stg_user') }}
),

dim_date AS (
    SELECT *
    FROM {{ ref('dim_date') }}
),

joined_with_date AS (
    SELECT
        u.*,
        d.date_id AS signup_date_id
    FROM user                  AS u
    LEFT JOIN dim_date         AS d
        ON STRFTIME(u.signup_date, '%Y%m%d') = d.date_id
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['user_id']) }} AS user_sk,   -- Surrogate key
    user_id,                                                          -- Business key
    email,
    first_name,
    last_name,
    gender,
    country,
    lead_source,
    signup_date_id,
    CURRENT_TIMESTAMP AS loaded_at

FROM joined_with_date