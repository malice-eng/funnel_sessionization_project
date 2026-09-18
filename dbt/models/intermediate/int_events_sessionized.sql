-- Classic "gaps and islands" sessionization:
-- 1. Order each user's events by time.
-- 2. Look at the gap since their previous event (LAG).
-- 3. Flag a "new session" whenever that gap exceeds the inactivity threshold
--    (or it's the user's very first event).
-- 4. Running SUM() of that flag gives a stable session number per user.

{% set session_timeout_minutes = 30 %}

with events as (

    select * from {{ ref('stg_events') }}

),

with_prev_event as (

    select
        *,
        lag(event_timestamp) over (
            partition by user_id
            order by event_timestamp
        ) as prev_event_timestamp

    from events

),

with_gap as (

    select
        *,
        extract(epoch from (event_timestamp - prev_event_timestamp)) / 60.0 as minutes_since_prev_event,
        case
            when prev_event_timestamp is null then 1
            when extract(epoch from (event_timestamp - prev_event_timestamp)) / 60.0 > {{ session_timeout_minutes }} then 1
            else 0
        end as is_new_session

    from with_prev_event

),

with_session_number as (

    select
        *,
        sum(is_new_session) over (
            partition by user_id
            order by event_timestamp
            rows between unbounded preceding and current row
        ) as session_number

    from with_gap

)

select
    event_id,
    user_id,
    event_name,
    event_timestamp,
    device_type,
    channel,
    product_id,
    minutes_since_prev_event,
    session_number,
    -- human-friendly, globally unique session id
    user_id || '-' || session_number::text as session_id

from with_session_number
