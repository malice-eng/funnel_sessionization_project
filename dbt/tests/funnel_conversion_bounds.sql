-- Funnel counts and percentages must be internally valid.
select *
from {{ ref('funnel_conversion') }}
where view_product > view_home
   or add_to_cart > view_product
   or checkout > add_to_cart
   or purchase > checkout
   or pct_home_to_product < 0 or pct_home_to_product > 100
   or pct_product_to_cart < 0 or pct_product_to_cart > 100
   or pct_cart_to_checkout < 0 or pct_cart_to_checkout > 100
   or pct_checkout_to_purchase < 0 or pct_checkout_to_purchase > 100
   or pct_overall_conversion < 0 or pct_overall_conversion > 100
