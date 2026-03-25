-- models/staging/stg_transaction.sql
{{
    config(
        materialized='view',
        schema='staging'
    )
}}

WITH cleaned_transaction AS (
    SELECT
        transaction_id,
        customer_id,
        -- Clean customer email
        CASE
            WHEN CONTAINS(cust_email, '_at_') = TRUE 
                THEN LOWER(REPLACE(TRIM(cust_email), '_at_', '@'))
            ELSE LOWER(TRIM(cust_email))
        END AS cust_email,

        -- Clean transaction_type with fallback logic
        CASE
            WHEN {{ handle_issue('transaction_type') }} = '' THEN
                CASE
                    WHEN CONTAINS(description, 'upgrade') = TRUE THEN 'subscription_payment_upgrade'
                    WHEN CONTAINS(description, 'new') = TRUE THEN 'subscription_payment_new'
                    WHEN CONTAINS(description, 'downgrade') = TRUE THEN 'subscription_payment_downgrade'
                    WHEN CONTAINS(description, 'renewal') = TRUE THEN 'subscription_payment_renewal'
                    WHEN CONTAINS(transaction_id, 're') THEN 'refund'
                END
            ELSE LOWER(TRIM({{ handle_issue('transaction_type') }}))
        END AS transaction_type,

        quantity,
        price,
        discount,

        -- Clean currency
        CASE
            WHEN LOWER(currency) LIKE 'us%' 
              OR CONTAINS(currency, '$') 
                THEN 'USD'
            ELSE TRIM(currency)
        END AS currency,

        {{ handle_issue('status') }} AS status,
        payment_method,
        failure_code,

        TRY_CAST(transaction_date AS DATE) AS transaction_date,
        created_at,

        -- Flag refunded
        CASE 
            WHEN refunded = TRUE THEN 1 
            ELSE 0 
        END AS refunded,

        COALESCE(refund_amount, 0) AS refund_amount,
        description
    FROM {{ source('raw_data', 'transactions') }}
)

SELECT * 
FROM cleaned_transaction