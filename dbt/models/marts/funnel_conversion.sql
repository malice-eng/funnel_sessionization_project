with steps as (

    select * from {{ ref('fct_funnel_steps') }}

),

overall as (

    select
        'overall'                                              as segment_type,
        'all'                                                   as segment_value,
        count(*)                                                as total_sessions,
        sum(reached_view_home::int)                             as view_home,
        sum(reached_view_product::int)                          as view_product,
        sum(reached_add_to_cart::int)                           as add_to_cart,
        sum(reached_checkout::int)                               as checkout,
        sum(reached_purchase::int)                               as purchase

    from steps

),

by_channel as (

    select
        'channel'                                              as segment_type,
        channel                                                 as segment_value,
        count(*)                                                as total_sessions,
        sum(reached_view_home::int)                             as view_home,
        sum(reached_view_product::int)                          as view_product,
        sum(reached_add_to_cart::int)                           as add_to_cart,
        sum(reached_checkout::int)                               as checkout,
        sum(reached_purchase::int)                               as purchase

    from steps
    group by channel

),

by_device as (

    select
        'device'                                               as segment_type,
        device_type                                             as segment_value,
        count(*)                                                as total_sessions,
        sum(reached_view_home::int)                             as view_home,
        sum(reached_view_product::int)                          as view_product,
        sum(reached_add_to_cart::int)                           as add_to_cart,
        sum(reached_checkout::int)                               as checkout,
        sum(reached_purchase::int)                               as purchase

    from steps
    group by device_type

),

unioned as (

    select * from overall
    union all
    select * from by_channel
    union all
    select * from by_device

)

select
    segment_type,
    segment_value,
    total_sessions,
    view_home,
    view_product,
    add_to_cart,
    checkout,
    purchase,
    -- conversion relative to the very top of the funnel
    round(100.0 * view_product / nullif(view_home, 0), 1)   as pct_home_to_product,
    round(100.0 * add_to_cart / nullif(view_product, 0), 1) as pct_product_to_cart,
    round(100.0 * checkout / nullif(add_to_cart, 0), 1)     as pct_cart_to_checkout,
    round(100.0 * purchase / nullif(checkout, 0), 1)        as pct_checkout_to_purchase,
    round(100.0 * purchase / nullif(view_home, 0), 1)       as pct_overall_conversion

from unioned
order by segment_type, segment_value
