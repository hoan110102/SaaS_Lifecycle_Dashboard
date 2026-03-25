-- models/staging/stg_subscription.sql
{{
    config(
        materialized='view',
        schema='staging'
    )
}}

WITH cleaned_subscription AS (
    SELECT
        subscription_id,
        transaction_id,
        customer_id,

        -- Clean customer email
        CASE
            WHEN CONTAINS(customer_email, '_at_') = TRUE 
                THEN LOWER(REPLACE(TRIM(customer_email), '_at_', '@'))
            ELSE LOWER(TRIM(customer_email))
        END AS customer_email,

        -- Clean plan_name
        {{ handle_issue('plan_name') }} AS plan_name,

        -- Clean billing_cycle
        {{ handle_issue('billing_cycle') }} AS billing_cycle,

        -- Clean status
        {{ handle_issue('status') }} AS status,

        -- Convert datetime columns
        TRY_CAST(current_period_start AS DATETIME) AS current_period_start,
        TRY_CAST(current_period_end AS DATETIME) AS current_period_end,
        TRY_CAST(created AS DATETIME) AS created_at,
        TRY_CAST(canceled_at AS DATETIME) AS canceled_at,

        churn_reason,

        -- Validity period
        TRY_CAST(valid_from AS DATETIME) AS valid_from,
        TRY_CAST(valid_to AS DATETIME) AS valid_to,

        -- Current flag
        CASE 
            WHEN is_current = TRUE THEN 1 
            ELSE 0 
        END AS is_current
    FROM {{ source('raw_data', 'subscriptions') }}
)

SELECT * 
FROM cleaned_subscription