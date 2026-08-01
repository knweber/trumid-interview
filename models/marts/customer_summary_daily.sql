{{ config(materialized='table') }}
-- this table is loaded on a daily grain at 4am, due to the event_sessions model having a lookback window of 4 hours. This ensures that we capture all possible sessions from the day before

WITH users AS (
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
        , traffic_source
        , created_at
    FROM {{ ref('stg_thelook__users') }}
)

, orders AS ( -- in this specific mart, I'm only tracking purchases -- in the future, we can decide whether or not we want to capture shipping, return, or delivery dates. I am also filtering on status = 'Processing', under the assumption that that means the order was created today. Again, this can be revisited in the future if we want to tweak the business assumptions about order status and tracking
    SELECT 
        order_id
        , user_id
        , status
        , gender
        , created_at
        , num_of_item
    FROM {{ ref('stg_thelook__orders' )}}
    WHERE CAST(created_at AS DATE) = current_date - 1
    AND status = 'Processing'
)

, order_items AS (
    SELECT 
        id
        , order_id
        , user_id
        , sale_price
    FROM {{ ref('stg_thelook__order_items') }}
    WHERE CAST(created_at AS DATE) = current_date - 1
)

, order_revenue AS (
    SELECT 
        o.order_id
        , o.user_id
        , o.created_at as order_date
        , SUM(oi.sale_price) as order_total
    FROM orders o
    LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
)

, sessions AS (
    SELECT 
        session_id
        , user_id
        , session_endtime
        , traffic_source
        , first_uri
        , first_event_type
        , last_uri
        , last_event_type
        , session_duration
    FROM {{ ref('int_event_sessions') }}
    WHERE CAST(session_endtime AS DATE) = current_date - 1
    GROUP BY session_id
)

-- right now, this table produces one record per user per day, even if they didn't have a session or an order on that day. We can also tweak the logic to select from sessions instead of users -- this would give us only "active" users for the given day, and ignore users who had no activity
SELECT 
    u.user_id
    , u.email
    , u.age
    , u.gender
    , u.street_address
    , u.city
    , u.state
    , u.postal_code
    , u.country
    , u.traffic_source -- tracking how the user was initially sourced; helpful if they are new users that created an account and an order on the same day
    , COALESCE(COUNT(DISTINCT o.order_id), 0) AS total_orders
    , COALESCE(SUM(o.order_total), 0) AS total_revenue
    , COALESCE(COUNT(DISTINCT s.session_id), 0) AS total_sessions
    , LISTAGG(distinct(s.traffic_source), '|') WITHIN GROUP (ORDER BY s.traffic_source) AS session_traffic_sources -- list of the traffic sources of each session, will give an overview of how a user decided to initiate with our website, especially if they had multiple distinct sessions
FROM users u
LEFT JOIN order_revenue o
    ON o.user_id = u.user_id
LEFT JOIN sessions s
    ON s.user_id = u.user_id
GROUP BY u.user_id -- one row per user per day
;
