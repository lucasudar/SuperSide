with
    projects as (select * from {{ source("SUPERSIDE", "PROJECT") }}),

    renamed as (
        select
            id,
            cpm,
            name,
            rate,
            team,
            cpm_id,
            folder,
            status,
            product,
            quality,
            service,
            team_id,
            delivery,
            discount,
            timezone,
            team_type,
            dim_cpm_id,
            product_id,
            project_id,
            source_app,
            ad_estimate,
            cast(customer_id as number) as customer_id,
            description,
            pm_estimate,
            sp_estimate,
            sub_service,
            max_estimate,
            min_estimate,
            staffing_version,
            cast(date_project_ended as date) as date_project_ended,
            project_service_id,
            cast(date_project_created as date) as date_project_created,
            cast(date_project_grabbed as date) as date_project_grabbed,
            cast(date_project_started as date) as date_project_started,
            cast(date_project_updated as date) as date_project_updated,
            internal_description,
            is_critical_delivery,
            cast(date_project_deadline as date) as date_project_deadline,
            is_project_ai_enabled,
            cast(date_project_submitted as date) as date_project_submitted,
            is_submitted_from_internal,
            is_created_with_deliverables,
            is_critical_delivery_success,
            current_timestamp() as etl_timestamp
        from projects
    )

select *
from renamed
