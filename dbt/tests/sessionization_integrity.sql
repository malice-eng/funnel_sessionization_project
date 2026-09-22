-- Every event must belong to exactly one session, and session numbering must start at 1.
with session_stats as (
    select
        user_id,
        session_id,
        min(session_number) as min_session_number,
        max(session_number) as max_session_number,
        count(*) as event_count
    from {{ ref('int_events_sessionized') }}
    group by 1, 2
)
select *
from session_stats
where min_session_number <> max_session_number
   or min_session_number < 1
   or event_count < 1
