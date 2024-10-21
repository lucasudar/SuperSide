{{ config(materialized="table") }}

with customers_info as (select * from {{ ref("tfm_customers") }})

select
    customer_id,
    customer_name,
    client_revenue,
    employee_count,
    current_timestamp() as etl_timestamp
from customers_info
