{{ config(materialized="table") }}

with customers_eng as (select * from {{ ref("tfm_customers") }})

select
    customer_id,
    engagementid,
    engagement_date,
    engagement_type,
    engagement_reference,
    current_timestamp() as etl_timestamp

from customers_eng
