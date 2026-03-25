{{
    config(
        materialized = 'table',
        unique_key   = ['created_date', 'ticket_type', 'priority', 'channel']
    )
}}

/*
=======================================================================
MART : mart_support_health
PAGE : 5 — Customer Support Health
GRAIN: 1 row = created_date × ticket_type × priority × channel
=======================================================================
*/

WITH 
fact_support AS (
    SELECT * FROM {{ ref('fact_support') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim_date') }}
),

dim_user AS (
    SELECT * FROM {{ ref('dim_user') }}
),

support_enriched AS (
    SELECT
        fs.ticket_id,
        fs.user_sk,
        fs.ticket_type,
        fs.priority,
        fs.status,
        fs.channel,
        fs.first_reply_time,
        fs.full_resolution_time,
        fs.satisfaction_rating,
        d.full_date AS created_date
    FROM fact_support     AS fs
    LEFT JOIN dim_date    AS d ON d.date_id = fs.created_at_id
),

final AS (
    SELECT
        created_date,
        ticket_type,
        priority,
        channel,
        COALESCE(satisfaction_rating, 0) AS satisfaction_rating,

        -- Volume
        COALESCE(COUNT(ticket_id), 0)                        AS ticket_count,
        COALESCE(COUNT(DISTINCT user_sk), 0)                 AS users_with_ticket,

        -- Status breakdown
        COALESCE(COUNT(CASE WHEN status IN ('Solved', 'Closed') THEN ticket_id END), 0) AS solved_count,
        COALESCE(COUNT(CASE WHEN status = 'Open'    THEN ticket_id END), 0) AS open_count,
        COALESCE(COUNT(CASE WHEN status = 'Pending' THEN ticket_id END), 0) AS pending_count,

        -- First Reply Time
        COALESCE(SUM(first_reply_time), 0)                                      AS sum_first_reply_time,
        COALESCE(COUNT(CASE WHEN first_reply_time IS NOT NULL THEN ticket_id END), 0) AS count_tickets_with_reply,

        -- Full Resolution Time
        COALESCE(SUM(full_resolution_time), 0)                                  AS sum_resolution_time,
        COALESCE(COUNT(CASE WHEN full_resolution_time IS NOT NULL THEN ticket_id END), 0) AS count_tickets_resolved,

        -- CSAT
        COALESCE(SUM(satisfaction_rating), 0)                                   AS sum_satisfaction_rating,
        COALESCE(COUNT(CASE WHEN satisfaction_rating IS NOT NULL THEN ticket_id END), 0) AS count_tickets_rated

    FROM support_enriched
    GROUP BY 
        created_date,
        ticket_type,
        priority,
        channel,
        satisfaction_rating
)

SELECT * FROM final