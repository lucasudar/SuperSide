with
    stg_customers as (select * from {{ ref("dim_customers") }}),

    stg_projects as (select * from {{ ref("dim_projects") }})

select
    p.project_id,
    p.name as project_name,
    p.status as project_status,
    c.customer_id,
    c.customer_name,
    p.date_project_created,
    p.date_project_ended,
    p.service as project_service,
    c.service as customer_service,
    p.min_estimate as project_min_estimate,
    p.max_estimate as project_max_estimate,
    c.revenue_usd,
    c.client_revenue,
    count(p.project_id) over (partition by c.customer_id) as project_count_per_customer,
    avg(p.max_estimate) over (partition by p.service) as avg_max_estimate_per_service,
    sum(c.revenue_usd) over (partition by c.customer_id) as total_revenue_per_customer,
    current_timestamp() as etl_timestamp
from stg_projects as p
inner join stg_customers as c on p.customer_id = c.customer_id
