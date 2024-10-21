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
    )

select *
from renamed
