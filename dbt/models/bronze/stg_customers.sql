{{ config(materialized="view") }}

with
    customers as (select * from {{ source("SUPERSIDE", "CUSTOMERS") }}),

    renamed as (
        select
            revenue,
            service,
            comments,
            customer_id,
            project_ref,
            project_id,
            revenue_usd,
            sub_service,
            engagementid,
            service_type,
            customer_name,
            client_revenue,
            employee_count,
            engagement_date,
            engagement_type,
            detailed_sub_service,
            engagement_reference,
            current_timestamp() as etl_timestamp
        from customers
    ),

    deduped as (
        select
            *,
            row_number() over (
                partition by customer_id, engagementid, engagement_date, project_id
                order by etl_timestamp desc
            ) as row_num
        from renamed
    )

select
    {{
        generate_surrogate_key(
            ["customer_id", "engagementid", "engagement_date", "project_id"]
        )
    }} as id, *
from deduped
where row_num = 1
