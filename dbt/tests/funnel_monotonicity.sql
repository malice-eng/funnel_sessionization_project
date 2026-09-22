-- A session cannot reach a later funnel step without reaching every earlier step.
select *
from {{ ref('fct_funnel_steps') }}
where reached_view_product and not reached_view_home
   or reached_add_to_cart and not reached_view_product
   or reached_checkout and not reached_add_to_cart
   or reached_purchase and not reached_checkout
