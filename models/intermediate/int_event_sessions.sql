{{ config(
    materialized='incremental',
    unique_key='session_id',
    incremental_strategy='merge'
) }}
-- incremental materialization so as to not do a full refresh of the table with each run, due to clickstream data being high volume
-- unique key is the ID of the session - we want to make sure we are only ingesting events once, using a merge pattern on session_id; if a session had events after the last run, its values in the current table will be updated to reflect this
-- technically, on_schema_change configuration is not needed because the stg_thelook__event model is only selecting certain columns (instead of SELECT *), which eliminates the possibility of new columns being passed through. We could still include it if we want to account for column data type changes.


-- grabbing session ID's where the max event created_at timestamp is within the past 4 hours - this will allow us to capture late-arriving data as well as sessions where the user could have potentially left an item in their cart for some amount of time prior to purchasing that was after the time of the last load
WITH events_in_window AS (
    SELECT 
        session_id
        , sequence_number
        , user_id
        , created_at
        , ip_address
        , city
        , state
        , postal_code
        , browser
        , traffic_source
        , uri
        , event_type
    FROM {{ ref('stg_thelook__events') }}
    {% if is_incremental() %}
    WHERE created_at >= (SELECT MAX(created_at) - INTERVAL '4 hours' FROM {{ this }})
    {% endif %}
)

-- grouping by session with timing/duration attributes
, sessions_grouped AS (
    SELECT 
        session_id
        , user_id
        , city
        , state
        , postal_code
        , browser
        , traffic_source
        , MIN(created_at) AS session_starttime
        , MAX(created_at) AS session_endtime
        , DATEDIFF(minute, MIN(created_at), MAX(created_at)) AS session_duration
    FROM events_in_window
    GROUP BY ALL
)

-- grab the event type and uri of the first event in the session - this will give us insights into acquisition
, first_event_action AS (
    SELECT
        session_id
        , uri AS first_uri
        , event_type AS first_event_type
    FROM events_in_window
    QUALIFY ROW_NUMBER() OVER(PARTITION BY session_id ORDER BY sequence_number ASC) = 1
)

-- grab the event type and uri of the last event in the session - this will give us insights into whether users eventually purchase an item
, last_event_action AS (
    SELECT 
        session_id
        , uri AS last_uri
        , event_type AS last_event_type
    FROM events_in_window
    QUALIFY ROW_NUMBER() OVER(PARTITION BY session_id ORDER BY sequence_number DESC) = 1
)

SELECT 
    sg.session_id
    , sg.user_id
    , sg.session_endtime AS created_at -- for initial filter in events_in_window
    , sg.city
    , sg.state
    , sg.postal_code
    , sg.traffic_source
    , f.first_uri
    , f.first_event_type
    , l.last_uri
    , l.last_event_type
    , sg.session_starttime
    , sg.session_endtime
    , sg.session_duration
FROM sessions_grouped sg
INNER JOIN first_event_action f
    ON sg.session_id = f.session_id
LEFT JOIN last_event_action l
    ON sg.session_id = l.session_id
