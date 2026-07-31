{{ config(materialized='view') }}

SELECT
    id
    , first_name
    , last_name
    , email
    , age
    , gender
    , state
    , street_address
    , postal_code
    , city
    , country
    , latitude
    , longitude
    , traffic_source
    , created_at
    , user_geom
FROM {{ source('thelook', 'users') }}