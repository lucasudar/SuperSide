{{ config(materialized="view") }}

with customers as (select * from {{ ref("stg_customers") }})

select
    {{
        generate_surrogate_key(
            [
                "customer_id",
                "engagementid",
                "engagement_date",
                "project_id",
            ]
        )
    }} as id,
    service,
    project_id,
    sub_service,
    engagementid,
    service_type,
    engagement_type,
    detailed_sub_service,
    try_to_number(
        regexp_replace(
            regexp_replace(
                regexp_replace(
                    regexp_replace(lower(trim(coalesce(revenue, ''))), '[$,]|usd', ''),
                    '([0-9]+)k',
                    '\\1000'
                ),
                '(^|[^0-9.])k($|[^0-9.])',
                '\\11000\\2'
            ),
            '\\s+',
            ''
        )
    ) as revenue,
    coalesce(nullif(comments, ''), 'unknown') as comments,
    case
        when trim(customer_id) = ''
        then null
        else cast(regexp_replace(customer_id, '^0+', '') as integer)
    end as customer_id,
    coalesce(nullif(project_ref, ''), 'unknown') as project_ref,
    coalesce(
        nullif(
            try_to_decimal(
                nullif(
                    regexp_replace(
                        regexp_replace(
                            regexp_replace(
                                regexp_replace(lower(revenue_usd), '[$,]', ''),
                                '([0-9]+)k',
                                '\\1000'
                            ),
                            ' usd$',
                            ''
                        ),
                        '\\s+',
                        ''
                    ),
                    ''
                ),
                38,
                2
            ),
            null
        ),
        null
    ) as revenue_usd,
    coalesce(nullif(customer_name, ''), 'unknown') as customer_name,
    case
        when trim(client_revenue) = ''
        then 0
        when lower(client_revenue) like '%usd%'
        then
            cast(
                replace(
                    replace(replace(trim(client_revenue), '$', ''), ' USD', ''), ' ', ''
                ) as numeric
            )
        when lower(client_revenue) like '%k%'
        then
            cast(replace(replace(trim(client_revenue), '$', ''), 'k', '') as numeric)
            * 1000
        else cast(replace(replace(trim(client_revenue), '$', ''), ' ', '') as numeric)
    end as client_revenue,
    case
        when trim(employee_count) = ''
        then null
        when lower(employee_count) = 'fifty'
        then 50
        when lower(employee_count) = 'hundred'
        then 100
        when employee_count rlike '^[0-9]+$'
        then cast(employee_count as integer)
    end as employee_count,
    case
        when trim(engagement_date) = ''
        then to_date('1900-01-01')
        when
            trim(engagement_date)
            rlike '^(0[1-9]|[12][0-9]|3[01])[-](0[1-9]|1[0-2])[-](19|20)[0-9]{2}$'
        then to_date(trim(engagement_date), 'DD-MM-YYYY')
        when
            trim(engagement_date)
            rlike '^(0[1-9]|1[0-2])[-](0[1-9]|[12][0-9]|3[01])[-](19|20)[0-9]{2}$'
        then to_date(trim(engagement_date), 'MM-DD-YYYY')
        when
            trim(engagement_date)
            rlike '^(19|20)[0-9]{2}[-](0[1-9]|1[0-2])[-](0[1-9]|[12][0-9]|3[01])$'
        then to_date(trim(engagement_date), 'YYYY-MM-DD')
        when
            trim(engagement_date)
            rlike '^(19|20)[0-9]{2}[/](0[1-9]|1[0-2])[/](0[1-9]|[12][0-9]|3[01])$'
        then to_date(trim(engagement_date), 'YYYY/MM/DD')
        when
            trim(engagement_date)
            rlike '^(19|20)[0-9]{2}[.](0[1-9]|1[0-2])[.](0[1-9]|[12][0-9]|3[01])$'
        then to_date(trim(engagement_date), 'YYYY.MM.DD')
        when
            trim(engagement_date)
            rlike '^(0[1-9]|[12][0-9]|3[01])[.](0[1-9]|1[0-2])[.](19|20)[0-9]{2}$'
        then to_date(trim(engagement_date), 'DD.MM.YYYY')
        when
            trim(engagement_date)
            rlike '^(0[1-9]|1[0-2])[/](0[1-9]|[12][0-9]|3[01])[/](19|20)[0-9]{2}$'
        then to_date(trim(engagement_date), 'MM/DD/YYYY')
    end as engagement_date,
    coalesce(nullif(engagement_reference, ''), 'unknown') as engagement_reference,
    current_timestamp() as etl_timestamp
from customers
