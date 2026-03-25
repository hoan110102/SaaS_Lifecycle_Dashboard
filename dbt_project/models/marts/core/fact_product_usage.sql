{{
    config(
        materialized = 'table',
        unique_key   = 'event_sk'
    )
}}

WITH usage AS (
    SELECT *
    FROM {{ ref('int_product_usage_fillna') }}
),

dim_user AS (
    SELECT *
    FROM {{ ref('dim_user') }}
),

dim_date AS (
    SELECT *
    FROM {{ ref('dim_date') }}
),

joined_with_dims AS (
    SELECT
        pu.*,
        u.user_sk,
        d.date_id AS event_timestamp_id
    FROM usage                AS pu
    LEFT JOIN dim_user        AS u
        ON u.email = pu.user_email
    LEFT JOIN dim_date        AS d
        ON STRFTIME(pu.event_timestamp, '%Y%m%d') = d.date_id
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['event_id']) }} AS event_sk,   -- Surrogate key
    event_id,                                                           -- Business key
    user_sk,
    feature_name,
    event_timestamp,
    event_timestamp_id,
    session_id,
    session_duration,
    device,
    browser,
    os,
    country,
    CURRENT_TIMESTAMP AS loaded_at

FROM joined_with_dims