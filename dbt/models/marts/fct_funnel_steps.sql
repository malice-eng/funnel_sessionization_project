select
    session_id,
    user_id,
    session_start,
    device_type,
    channel,
    furthest_step_reached >= 1  as reached_view_home,
    furthest_step_reached >= 2  as reached_view_product,
    furthest_step_reached >= 3  as reached_add_to_cart,
    furthest_step_reached >= 4  as reached_checkout,
    furthest_step_reached >= 5  as reached_purchase

from {{ ref('int_sessions') }}
