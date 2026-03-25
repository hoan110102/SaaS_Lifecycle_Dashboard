-- models/intermediate/int_subscription.sql
{{
    config(
        materialized='view',
        schema='intermediate'
    )
}}

WITH subscription AS (
    SELECT * 
    FROM {{ ref('stg_subscription') }}
),

transaction AS (
    SELECT * 
    FROM {{ ref('stg_transaction') }}
),

sub_joined_with_trans AS (
    SELECT
        s.*,
        t.description
    FROM subscription s
    LEFT JOIN transaction t
        ON s.transaction_id = t.transaction_id
),

cleaned_subscription AS (
    SELECT
        subscription_id,
        transaction_id,
        customer_id,
        customer_email,

        -- Fill missing plan_name from transaction description
        CASE
            WHEN plan_name = '' THEN
                CASE
                    WHEN description LIKE '%Basic%'    THEN 'Basic'
                    WHEN description LIKE '%Standard%' THEN 'Standard'
                    WHEN description LIKE '%Premium%'  THEN 'Premium'
                    ELSE 'Ultimate'
                END
            ELSE plan_name
        END AS plan_name_filled,

        -- Fill missing billing_cycle from transaction description
        CASE
            WHEN billing_cycle = '' THEN
                CASE
                    WHEN description LIKE '%Monthly%' THEN 'Monthly'
                    ELSE 'Annual'
                END
            ELSE billing_cycle
        END AS billing_cycle_filled,

        status,
        current_period_start,
        current_period_end,
        created_at,
        canceled_at,
        churn_reason,
        valid_from,
        valid_to,
        is_current
    FROM sub_joined_with_trans
)

SELECT
    subscription_id,
    transaction_id,
    customer_id,
    customer_email,
    plan_name_filled AS plan_name,
    billing_cycle_filled AS billing_cycle,
    status,
    current_period_start,
    current_period_end,
    created_at,
    canceled_at,
    churn_reason,
    valid_from,
    valid_to,
    is_current
FROM cleaned_subscription