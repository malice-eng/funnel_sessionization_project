with source as (

    select * from {{ ref('raw_events') }}

),

cleaned as (

    select
        event_id,
        user_id,
        lower(trim(event_name))         as event_name,
        event_timestamp::timestamp      as event_timestamp,
        lower(device_type)              as device_type,
        lower(channel)                  as channel,
        nullif(trim(product_id), '')    as product_id

    from source
    where user_id is not null
      and event_timestamp is not null

)

select * from cleaned
