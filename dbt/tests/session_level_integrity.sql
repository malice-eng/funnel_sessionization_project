-- Session-level metrics should be physically possible.
select *
from {{ ref('fct_sessions') }}
where session_start > session_end
   or session_duration_seconds < 0
   or event_count < 1
   or (converted and furthest_step_reached <> 5)
