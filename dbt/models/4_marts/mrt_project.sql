{{ config(materialized="table") }}

with customer_project as (select * from {{ ref("dw_customer_project") }})

select
    project_id,
    customer_id,
    service,
    name,
    team,
    cpm,
    rate as project_rate,
    discount as project_discount,
    status as project_status,
    quality as project_quality,
    ad_estimate,
    pm_estimate,
    sp_estimate,
    max_estimate,
    min_estimate,
    is_critical_delivery_success,
    current_timestamp() as etl_timestamp,
    datediff(
        'day', date_project_started, coalesce(date_project_ended, current_date())
    ) as project_duration_days,
    datediff(
        'day', date_project_created, date_project_started
    ) as project_start_delay_days,
    case when is_critical_delivery = true then 1 else 0 end as is_critical_delivery,
    case when is_project_ai_enabled = true then 1 else 0 end as is_ai_enabled,
    case
        when status = 'Completed' and date_project_ended <= date_project_deadline
        then 1
        else 0
    end as is_completed_on_time
from customer_project
