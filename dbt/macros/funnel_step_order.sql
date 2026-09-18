{% macro funnel_step_order(event_name_column) %}
    case {{ event_name_column }}
        when 'view_home'     then 1
        when 'view_product'  then 2
        when 'add_to_cart'   then 3
        when 'checkout'      then 4
        when 'purchase'      then 5
        else 0
    end
{% endmacro %}
