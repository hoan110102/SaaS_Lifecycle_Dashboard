{{
    config(
        materialized = 'table',
        unique_key   = 'subscription_sk'
    )
}}

WITH subscription AS (
    SELECT * 
    FROM {{ ref('int_subscription_fillna') }}
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
        s.*,
        u.user_sk,
        d1.date_id AS current_period_start_id,
        d2.date_id AS current_period_end_id,
        d3.date_id AS canceled_at_id
    FROM subscription s
    LEFT JOIN dim_user u
        ON u.email = s.customer_email
    LEFT JOIN dim_date d1
        ON strftime(s.current_period_start, '%Y%m%d') = d1.date_id
    LEFT JOIN dim_date d2
        ON strftime(s.current_period_end, '%Y%m%d') = d2.date_id
    LEFT JOIN dim_date d3
        ON strftime(s.canceled_at, '%Y%m%d') = d3.date_id
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['subscription_id', 'valid_from']) }} AS subscription_sk,   -- Surrogate key
    subscription_id,                                                                       -- Business key
    user_sk,
    plan_name,
    billing_cycle,
    status,
    current_period_start,
    current_period_start_id,
    current_period_end,
    current_period_end_id,
    canceled_at,
    canceled_at_id,
    churn_reason,
    valid_from,
    valid_to,
    is_current,
    CURRENT_TIMESTAMP AS loaded_at

FROM joined_with_dims

ORDER BY subscription_sk, valid_from