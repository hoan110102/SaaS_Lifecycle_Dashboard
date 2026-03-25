{{ config(
    materialized = 'table',
    unique_key   = ['cohort_month', 'months_since_start', 'plan_name', 'billing_cycle', 'churn_reason']
) }}

{#
======================================================================
MART : mart_retention_churn
PAGE : 4 — Retention & Churn
GRAIN: 1 row = cohort_month × months_since_start × plan_name × billing_cycle × churn_reason
======================================================================
#}

WITH 
    dim_subscription AS (
        SELECT * FROM {{ ref('dim_subscription') }}
    ),

    fact_transaction AS (
        SELECT * FROM {{ ref('fact_transaction') }}
    ),

    -- Chỉ lấy các giao dịch thành công
    transaction AS (
        SELECT
            transaction_sk,
            subscription_sk,
            price * (1 - discount) AS price,
            transaction_type
        FROM fact_transaction
        WHERE status = 'Succeeded'
    ),

    -- Subscription Annual để flat ra từng tháng
    annual_subscription AS (
        SELECT
            subscription_sk,
            valid_from,
            canceled_at
        FROM dim_subscription
        WHERE billing_cycle = 'Annual'
    ),

    month_spine AS (
        SELECT unnest(range(0, 12)) AS months_since_start
    ),

    annual_subscription_flat AS (
        SELECT
            *
        FROM annual_subscription
        CROSS JOIN month_spine
        WHERE months_since_start < datediff(
            'month',
            valid_from,
            COALESCE(canceled_at, DATE '2025-12-31')
        )
    ),

    subscription_joined AS (
        SELECT
            ds.subscription_id,
            ds.plan_name,
            ds.billing_cycle,
            ds.status,
            ds.current_period_start,
            ds.canceled_at,
            COALESCE(ds.churn_reason, 'N/A') AS churn_reason,
            t.transaction_type,
            t.price,
            CASE 
                WHEN asf.months_since_start IS NULL 
                    THEN ds.valid_from
                ELSE date_add(
                    ds.valid_from, 
                    CAST(asf.months_since_start || ' months' AS INTERVAL)
                )
            END AS valid_from
        FROM dim_subscription ds
        LEFT JOIN annual_subscription_flat AS asf
            ON ds.subscription_sk = asf.subscription_sk
            AND ds.status != 'Canceled'
        LEFT JOIN transaction t
            ON t.subscription_sk = ds.subscription_sk
            AND ds.status != 'Canceled'
    ),

    subscription_enriched AS (
        SELECT
            *,
            date_trunc('month', valid_from) AS current_month,
            dense_rank() OVER (
                PARTITION BY subscription_id 
                ORDER BY month(valid_from)
            ) - 1 AS months_since_start
        FROM subscription_joined
    ),

    customer_state AS (
        SELECT 
            *,
            LAG(price) OVER (PARTITION BY subscription_id ORDER BY valid_from) AS old_price,
            CASE 
                WHEN status = 'Canceled' THEN 'subscription_cancellation' 
                ELSE transaction_type 
            END AS new_transaction_type
        FROM subscription_enriched
    ),

    all_mrr AS (
        SELECT
            date_trunc('month', valid_from) AS current_month,
            plan_name,
            billing_cycle,
            months_since_start,
            churn_reason,
            SUM(CASE WHEN new_transaction_type = 'subscription_payment_new'      THEN price ELSE 0 END) AS new_mrr,
            SUM(CASE WHEN new_transaction_type = 'subscription_payment_upgrade'   THEN price - old_price ELSE 0 END) AS expansion_mrr,
            SUM(CASE WHEN new_transaction_type = 'subscription_payment_downgrade' THEN old_price - price ELSE 0 END) AS contraction_mrr,
            SUM(CASE WHEN new_transaction_type = 'subscription_cancellation'      THEN old_price ELSE 0 END) AS cancellation_mrr,
            SUM(CASE WHEN new_transaction_type = 'subscription_payment_renewal'   THEN price ELSE 0 END) AS renewal_mrr
        FROM customer_state
        GROUP BY 
            date_trunc('month', valid_from),
            plan_name,
            billing_cycle,
            months_since_start,
            churn_reason
    ),

    final AS (
        SELECT
            -- Dimensions
            se.current_month,
            se.months_since_start,
            se.plan_name,
            se.billing_cycle,
            se.churn_reason,

            -- Metrics
            COALESCE(COUNT(DISTINCT CASE WHEN se.status = 'Active' THEN se.subscription_id END), 0) AS cohort_size,
            COALESCE(COUNT(DISTINCT CASE WHEN se.status = 'Canceled' THEN se.subscription_id END), 0) AS churned_users,

            COALESCE(SUM(am.new_mrr), 0)         AS new_mrr,
            COALESCE(SUM(am.expansion_mrr), 0)   AS expansion_mrr,
            COALESCE(SUM(am.contraction_mrr), 0) AS contraction_mrr,
            COALESCE(SUM(am.cancellation_mrr), 0) AS cancellation_mrr,
            COALESCE(SUM(am.renewal_mrr), 0)     AS renewal_mrr
        FROM subscription_enriched se
        LEFT JOIN all_mrr am
            ON se.current_month       = am.current_month
           AND se.months_since_start  = am.months_since_start
           AND se.plan_name           = am.plan_name
           AND se.billing_cycle       = am.billing_cycle
           AND se.churn_reason        = am.churn_reason
        GROUP BY 
            se.current_month,
            se.months_since_start,
            se.plan_name,
            se.billing_cycle,
            se.churn_reason
    )

SELECT * FROM final