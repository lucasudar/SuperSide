{{ config(materialized="table") }}

with customer_project as (select * from {{ ref("dw_customer_project") }})

select
    customer_id,
    customer_name,
    service,
    sum(client_revenue) as total_revenue,
    avg(client_revenue) as avg_client_revenue,
    max(employee_count) as max_employee_count,
    count(distinct project_id) as total_projects,
    array_agg(distinct product) as products_used,
    array_agg(distinct sub_service) as sub_services_used,
    max(date_project_updated) as last_project_update,
    current_timestamp() as etl_timestamp
from customer_project
group by customer_id, customer_name, service
