{{ config(materialized="table") }}

with
    customers as (select * from {{ ref("tfm_customer_info") }}),

    projects as (select * from {{ ref("tfm_projects") }})

select
    {{ generate_surrogate_key(["customers.customer_id", "projects.project_id"]) }}
    as id,
    customers.customer_id,
    customers.customer_name,
    customers.client_revenue,
    customers.employee_count,
    projects.cpm,
    projects.name,
    projects.rate,
    projects.team,
    projects.cpm_id,
    projects.folder,
    projects.status,
    projects.product,
    projects.quality,
    projects.service,
    projects.team_id,
    projects.delivery,
    projects.discount,
    projects.timezone,
    projects.team_type,
    projects.dim_cpm_id,
    projects.product_id,
    projects.project_id,
    projects.source_app,
    projects.ad_estimate,
    projects.description,
    projects.pm_estimate,
    projects.sp_estimate,
    projects.sub_service,
    projects.max_estimate,
    projects.min_estimate,
    projects.staffing_version,
    projects.date_project_ended,
    projects.project_service_id,
    projects.date_project_created,
    projects.date_project_grabbed,
    projects.date_project_started,
    projects.date_project_updated,
    projects.internal_description,
    projects.is_critical_delivery,
    projects.date_project_deadline,
    projects.is_project_ai_enabled,
    projects.date_project_submitted,
    projects.is_submitted_from_internal,
    projects.is_created_with_deliverables,
    projects.is_critical_delivery_success
from projects
left join customers on projects.customer_id = customers.customer_id
