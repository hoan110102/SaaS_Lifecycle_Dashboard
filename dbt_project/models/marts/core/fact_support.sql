{{
    config(
        materialized = 'table',
        unique_key   = 'ticket_sk'
    )
}}

WITH support AS (
    SELECT * FROM {{ ref('stg_support_ticket') }}
),

dim_user AS (
    SELECT * FROM {{ ref('dim_user') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim_date') }}
),

joined_with_dims AS (
    SELECT
        s.*,
        u.user_sk,
        d1.date_id AS created_at_id,
        d2.date_id AS first_response_at_id,
        d3.date_id AS solved_at_id,
        d4.date_id AS updated_at_id
    FROM support                AS s
    LEFT JOIN dim_user          AS u  ON u.email = s.requester_email
    LEFT JOIN dim_date          AS d1 ON STRFTIME(s.created_at, '%Y%m%d') = d1.date_id
    LEFT JOIN dim_date          AS d2 ON STRFTIME(s.first_response_at, '%Y%m%d') = d2.date_id
    LEFT JOIN dim_date          AS d3 ON STRFTIME(s.solved_at, '%Y%m%d') = d3.date_id
    LEFT JOIN dim_date          AS d4 ON STRFTIME(s.updated_at, '%Y%m%d') = d4.date_id
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['ticket_id']) }} AS ticket_sk,        -- Surrogate key
    ticket_id,                                                                 -- Business key
    user_sk,
    ticket_type,
    subject,
    description,
    priority,
    status,
    channel,
    created_at,
    created_at_id,
    first_response_at,
    first_response_at_id,
    solved_at,
    solved_at_id,
    updated_at,
    updated_at_id,
    first_reply_time,
    full_resolution_time,
    satisfaction_rating,
    CURRENT_TIMESTAMP AS loaded_at

FROM joined_with_dims