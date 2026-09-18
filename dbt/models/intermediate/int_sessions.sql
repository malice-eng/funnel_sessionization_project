with sessionized_events as (

    select * from {{ ref('int_events_sessionized') }}

),

session_agg as (

    select
        session_id,
        user_id,
        min(event_timestamp)                                   as session_start,
        max(event_timestamp)                                   as session_end,
        count(*)                                                as event_count,
        max({{ funnel_step_order('event_name') }})              as furthest_step_reached,
        bool_or(event_name = 'purchase')                        as converted,
        -- first-touch attribution for the session
        (array_agg(device_type order by event_timestamp))[1]    as device_type,
        (array_agg(channel order by event_timestamp))[1]        as channel

    from sessionized_events
    group by 1, 2

)

select
    session_id,
    user_id,
    session_start,
    session_end,
    extract(epoch from (session_end - session_start))           as session_duration_seconds,
    event_count,
    furthest_step_reached,
    case furthest_step_reached
        when 1 then 'view_home'
        when 2 then 'view_product'
        when 3 then 'add_to_cart'
        when 4 then 'checkout'
        when 5 then 'purchase'
        else 'unknown'
    end                                                          as furthest_step_name,
    converted,
    device_type,
    channel

from session_agg
