{{
    config(
        materialized = 'table',
        unique_key   = 'transaction_sk'
    )
}}

WITH 
stg_transaction AS (
    SELECT * FROM {{ ref('stg_transaction') }}
),

dim_subscription AS (
    SELECT * FROM {{ ref('dim_subscription') }}
),

dim_user AS (
    SELECT * FROM {{ ref('dim_user') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim_date') }}
),

joined_with_user AS (
    SELECT
        t.*,
        u.user_sk,
        d.date_id AS transaction_date_id
    FROM stg_transaction     AS t
    LEFT JOIN dim_user       AS u ON u.email = t.cust_email
    LEFT JOIN dim_date       AS d ON STRFTIME(t.transaction_date, '%Y%m%d') = d.date_id
),

joined_with_sub AS (
    SELECT
        u.*,
        s.subscription_sk
    FROM joined_with_user    AS u
    LEFT JOIN dim_subscription AS s
        ON u.transaction_date = STRFTIME(s.current_period_start, '%Y-%m-%d')
       AND u.user_sk = s.user_sk
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['transaction_id']) }} AS transaction_sk,   -- Surrogate key
    transaction_id,                                                                -- Business key
    subscription_sk,
    user_sk,
    transaction_type,
    quantity,
    price,
    discount,
    ROUND(price * quantity * (1 - discount), 2) AS total_amount,
    currency,
    status,
    payment_method,
    failure_code,
    transaction_date_id,
    refunded,
    refund_amount,
    description,
    CURRENT_TIMESTAMP AS loaded_at

FROM joined_with_sub