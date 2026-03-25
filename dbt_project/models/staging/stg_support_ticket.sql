-- models/staging/stg_support_ticket.sql
{{
    config(
        materialized='view',
        schema='staging'
    )
}}

WITH cleaned_support_ticket AS (
    SELECT
        ticket_id,

        -- Clean requester email
        CASE
            WHEN CONTAINS(requester_email, '_at_') = TRUE 
                THEN LOWER(REPLACE(TRIM(requester_email), '_at_', '@'))
            ELSE LOWER(TRIM(requester_email))
        END AS requester_email,

        -- Clean requester name
        requester_name,
        ticket_type,
        subject,
        description,
        priority,
        status,
        channel,

        -- Convert timestamps
        TRY_CAST(created_at AS DATETIME) AS created_at,
        TRY_CAST(first_response_at AS DATETIME) AS first_response_at,
        TRY_CAST(updated_at AS DATETIME) AS updated_at,
        TRY_CAST(solved_at AS DATETIME) AS solved_at,

        -- Convert time metrics
        TRY_CAST(first_reply_time AS FLOAT) AS first_reply_time,
        TRY_CAST(full_resolution_time AS FLOAT) AS full_resolution_time,

        satisfaction_rating
    FROM {{ source('raw_data', 'support_tickets') }}
)

SELECT * 
FROM cleaned_support_ticket