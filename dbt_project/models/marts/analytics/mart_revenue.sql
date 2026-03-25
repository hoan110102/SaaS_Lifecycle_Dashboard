{{
    config(
        materialized = 'table',
        unique_key   = ['transaction_month', 'plan_name', 'billing_cycle',
                        'transaction_type', 'payment_method', 'failure_code']
    )
}}

/*
=======================================================================
MART : mart_revenue_health
PAGE : 3 — Revenue Health
GRAIN: 1 row = transaction_month × plan_name × billing_cycle × 
               transaction_type × payment_method × failure_code
=======================================================================
*/

WITH 
fact_transaction AS (
    SELECT * FROM {{ ref('fact_transaction') }}
),

dim_subscription AS (
    SELECT * FROM {{ ref('dim_subscription') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim_date') }}
),

month_spine AS (
    SELECT UNNEST(RANGE(0, 12)) AS months_since_start
),

txn AS (
    SELECT
        ft.*,
        COALESCE(s.canceled_at, d.full_date) AS transaction_date,
        s.subscription_id,
        s.plan_name,
        s.billing_cycle,
        s.canceled_at
    FROM fact_transaction     AS ft
    LEFT JOIN dim_date        AS d  ON d.date_id = ft.transaction_date_id
    LEFT JOIN dim_subscription AS s ON s.subscription_sk = ft.subscription_sk
),

annual_txn AS (
    SELECT
        transaction_sk,
        transaction_date,
        canceled_at
    FROM txn
    WHERE billing_cycle = 'Annual'
),

annual_txn_flat AS (
    SELECT 
        *
    FROM annual_txn
    CROSS JOIN month_spine
    WHERE months_since_start < DATEDIFF('month', transaction_date, 
            COALESCE(canceled_at, DATE '2025-12-31'))
),

txn_enriched AS (
    SELECT
        transaction_id,
        subscription_id,
        CASE 
            WHEN months_since_start IS NULL 
                THEN t.transaction_date
            ELSE DATE_ADD(t.transaction_date, CAST(months_since_start || ' months' AS INTERVAL))
        END AS transaction_date,

        user_sk,
        CASE 
            WHEN t.canceled_at IS NOT NULL 
                THEN 'subscription_cancellation' 
            WHEN months_since_start > 0 
                THEN 'subscription_payment_renewal'
            ELSE transaction_type
        END AS transaction_type,

        payment_method,
        t.canceled_at,
        status,
        price * (1 - discount) AS price,
        refunded,
        refund_amount,

        -- plan_name & billing_cycle fallback từ description nếu không có subscription
        COALESCE(plan_name, 
            CASE 
                WHEN 'Basic'    IN description THEN 'Basic'
                WHEN 'Standard' IN description THEN 'Standard'
                WHEN 'Premium'  IN description THEN 'Premium'
                ELSE 'Ultimate'
            END) AS plan_name,

        COALESCE(billing_cycle, 
            CASE 
                WHEN 'Monthly' IN description THEN 'Monthly'
                ELSE 'Annual'
            END) AS billing_cycle,

        COALESCE(failure_code, 'N/A') AS failure_code

    FROM txn t
    LEFT JOIN annual_txn_flat atf 
        ON t.transaction_sk = atf.transaction_sk 
       AND t.canceled_at IS NULL
),

customer_state AS (
    SELECT 
        *,
        LAG(price) OVER (PARTITION BY subscription_id ORDER BY transaction_date) AS old_price
    FROM txn_enriched
    WHERE status = 'Succeeded'
      AND transaction_type LIKE 'subscription%'
),

all_mrr AS (
    SELECT
        MONTH(transaction_date) AS transaction_month,
        plan_name,
        billing_cycle,
        transaction_type,
        payment_method,
        failure_code,

        SUM(CASE WHEN transaction_type = 'subscription_payment_new'      THEN price ELSE 0 END) AS new_mrr,
        SUM(CASE WHEN transaction_type = 'subscription_payment_upgrade'  THEN price - old_price ELSE 0 END) AS expansion_mrr,
        SUM(CASE WHEN transaction_type = 'subscription_payment_downgrade' THEN old_price - price ELSE 0 END) AS contraction_mrr,
        SUM(CASE WHEN transaction_type = 'subscription_cancellation'     THEN price ELSE 0 END) AS cancellation_mrr,
        SUM(CASE WHEN transaction_type = 'subscription_payment_renewal'  THEN price ELSE 0 END) AS renewal_mrr
    FROM customer_state
    GROUP BY 
        MONTH(transaction_date),
        plan_name,
        billing_cycle,
        transaction_type,
        payment_method,
        failure_code
),

final AS (
    SELECT
        MONTH(te.transaction_date)          AS transaction_month,
        te.plan_name,
        te.billing_cycle,
        te.transaction_type,
        te.payment_method,
        COALESCE(te.failure_code, 'N/A')    AS failure_code,

        -- Volume
        COALESCE(COUNT(DISTINCT te.transaction_id), 0)   AS transaction_count,
        COALESCE(COUNT(DISTINCT te.user_sk), 0)          AS paying_users,

        -- MRR components
        COALESCE(SUM(new_mrr), 0)         AS new_mrr,
        COALESCE(SUM(expansion_mrr), 0)   AS expansion_mrr,
        COALESCE(SUM(contraction_mrr), 0) AS contraction_mrr,
        COALESCE(SUM(cancellation_mrr), 0) AS cancellation_mrr,
        COALESCE(SUM(renewal_mrr), 0)     AS renewal_mrr,

        -- Refund
        SUM(CASE WHEN refunded = TRUE THEN refund_amount ELSE 0 END) AS total_refund_amount,
        COALESCE(COUNT(CASE WHEN refunded = TRUE THEN te.transaction_id END), 0) AS refund_count,

        -- Outcome
        COALESCE(COUNT(CASE WHEN status = 'Succeeded' THEN te.transaction_id END), 0) AS success_count,
        COALESCE(COUNT(CASE WHEN status = 'Failed'    THEN te.transaction_id END), 0) AS failed_count

    FROM txn_enriched te
    LEFT JOIN all_mrr am
        ON am.transaction_month = MONTH(te.transaction_date)
       AND am.plan_name         = te.plan_name
       AND am.billing_cycle     = te.billing_cycle
       AND am.payment_method    = te.payment_method
       AND am.transaction_type  = te.transaction_type
       AND am.failure_code      = te.failure_code
    GROUP BY 
        MONTH(te.transaction_date),
        te.plan_name,
        te.billing_cycle,
        te.transaction_type,
        te.payment_method,
        te.failure_code
)

SELECT * FROM final