{{ config(
    materialized = 'table',
    unique_key   = ['user_sk', 'event_date', 'feature_name']
) }}

{#
======================================================================
MART : mart_product_engagement
PAGE : 2 — Product Engagement
GRAIN: 1 row = user_sk × event_date × feature_name
======================================================================
#}

WITH 
    fact_product_usage AS (
        SELECT * FROM {{ ref('fact_product_usage') }}
    ),

    dim_date AS (
        SELECT * FROM {{ ref('dim_date') }}
    ),

    usage_enriched AS (
        SELECT
            pu.event_id,
            pu.user_sk,
            pu.feature_name,
            pu.session_id,
            pu.session_duration,
            d.full_date AS event_date
        FROM fact_product_usage pu
        LEFT JOIN dim_date d 
            ON d.date_id = pu.event_timestamp_id
        WHERE pu.user_sk IS NOT NULL
    ),

    final AS (
        SELECT
            user_sk,
            event_date,
            feature_name,

            COALESCE(COUNT(event_id), 0)                  AS total_events,
            COALESCE(COUNT(DISTINCT session_id), 0)       AS distinct_sessions,
            COALESCE(SUM(COALESCE(session_duration, 0)), 0) AS sum_session_duration
        FROM usage_enriched
        GROUP BY 
            user_sk,
            event_date,
            feature_name
    )

SELECT * FROM final