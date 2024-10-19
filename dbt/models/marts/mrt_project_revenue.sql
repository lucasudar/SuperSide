{{ config(materialized="table") }}

with
    stg_customers as (select * from {{ ref("dim_customers") }}),

    stg_projects as (select * from {{ ref("dim_projects") }})

select
    c.customer_id,
    c.customer_name,
    count(p.project_id) as total_projects,
    sum(c.revenue_usd) as total_revenue_usd,
    avg(c.revenue_usd) as avg_revenue_per_project,
    avg(p.max_estimate) as avg_max_estimate_per_project,
    count(case when p.status = 'Active' then p.project_id end) as active_projects,
    count(case when p.status = 'On Hold' then p.project_id end) as on_hold_projects,
    count(case when p.status = 'Cancelled' then p.project_id end) as cancelled_projects,
    count(case when p.status = 'Completed' then p.project_id end) as completed_projects,
    min(p.date_project_created) as earliest_project_start,
    max(p.date_project_ended) as latest_project_end,
    current_timestamp() as etl_timestamp
from stg_projects as p
inner join stg_customers as c on p.customer_id = c.customer_id
group by c.customer_id, c.customer_name
order by c.customer_name
