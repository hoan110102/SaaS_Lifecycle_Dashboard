{{ config(
    materialized = 'table',
    unique_key   = ['signup_date', 'lead_source', 'gender', 'activated_bucket']
) }}

{#
======================================================================
MART : mart_acquisition_onboarding
PAGE : 1 — Acquisition & Onboarding
GRAIN: 1 row = signup_date × lead_source × gender × activated_bucket
======================================================================
#}

WITH 
    dim_user AS (
        SELECT * FROM {{ ref('dim_user') }}
    ),

    dim_date AS (
        SELECT * FROM {{ ref('dim_date') }}
    ),

    fact_product_usage AS (
        SELECT * FROM {{ ref('fact_product_usage') }}
    ),

    first_event AS (
        SELECT
            user_sk,
            MIN(CASE WHEN feature_name LIKE 'Feature%' THEN event_timestamp END) AS first_event_ts
        FROM fact_product_usage
        WHERE user_sk IS NOT NULL
        GROUP BY user_sk
    ),

    user_base AS (
        SELECT
            u.user_id,
            u.user_sk,
            u.lead_source,
            u.gender,
            d.full_date AS signup_date,
            datediff(
                'day',
                d.full_date,
                CAST(fe.first_event_ts AS DATE)
            ) AS days_to_first_action
        FROM dim_user u
        LEFT JOIN dim_date d 
            ON d.date_id = u.signup_date_id
        LEFT JOIN first_event fe 
            ON fe.user_sk = u.user_sk
    ),

    user_with_bucket AS (
        SELECT
            *,
            CASE
                WHEN days_to_first_action IS NULL THEN 'Never Activated'
                WHEN days_to_first_action = 0      THEN 'Day 0'
                WHEN days_to_first_action <= 3     THEN 'Day 1-3'
                WHEN days_to_first_action <= 7     THEN 'Day 4-7'
                ELSE 'After Day 7'
            END AS activated_bucket,

            CASE
                WHEN days_to_first_action IS NOT NULL 
                     AND days_to_first_action <= 7 
                    THEN 1 
                ELSE 0 
            END AS is_activated
        FROM user_base
    ),

    final AS (
        SELECT
            signup_date,
            lead_source,
            gender,
            activated_bucket,

            COALESCE(COUNT(DISTINCT user_id), 0) AS sum_new_signups,
            COALESCE(COUNT(DISTINCT CASE WHEN is_activated = 1 THEN user_id END), 0) AS sum_activated_users,
            COALESCE(SUM(days_to_first_action), 0) AS sum_days_to_first_action,
            COALESCE(COUNT(CASE WHEN days_to_first_action IS NOT NULL THEN user_id END), 0) AS count_users_with_first_action
        FROM user_with_bucket
        GROUP BY 
            signup_date,
            lead_source,
            gender,
            activated_bucket
    )

SELECT * FROM final