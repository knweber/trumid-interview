# Readme

This repo utilizes four of the tables included in the thelook_ecommerce dataset -- events, order items, orders, and users -- to create an analytics-ready mart table summarizing and aggregating customer activity by day.

## Business Value
This model is designed to provide stakeholders with a once-daily report of customer activity, and can be expanded upon in the future to provide a near-real-time model of user behavior on our website.
The questions our current model can answer:
- How many customers were "active" (visited our website or made an order) on a given day? How many of these active customers actually made a purchases, versus just navigating on our website?
- For the active customers, how much time was spent on our website, and what was the source that brought them to our website (e.g. social media ad, email)?
- How much revenue did the active customers bring in? What was the average revenue by order?
- Were there any trends in customer activity within certain geographic areas? If we were running ads in local markets, this could give us data on conversion rates and the most effective advertising channels

## Models

### Staging
The staging models in this project serve as the bronze-layer of our warehouse -- the layer of data closest to the source. The staging models here are 1:1 with the source tables and only contain minor transformations/logic, mostly to standardize inputs (e.g., ensuring correct casing of an ID if it's a string -- this will ensure correct joins between tables later on). I have four staging models -- one each for the events, orders, order items, and users tables from BigQuery. 

In my specific example, I am assuming that the orders, order items, and users tables refresh once daily via batching, while the events table comes from a streaming and/or microbatching source. The cadence of dbt runs should be once daily for orders, order items, and users, and every 15 minutes for events. The final mart table will follow the once-daily cadence of the four batch tables.

The grain for each of these stage tables is as follows:
- events: one record per event within a session
- orders: one record per order
- order_items: one record per item in a given order
- users: one record per user

### Intermediate
The intermediate model in this project serves as the silver layer of our warehouse -- the layer of data after the bronze layer, where the majority of the joins, transformations, and business logic are implemented. I have one intermediate model here, int_event_sessions. The model takes the streaming events data and publishes it at the session level. Looking at events in aggregate typically provides more "meaning" and context than an isolated event, and rolling the events up into their respective sessions also allows for more meaningful joins further downstream. This intermediate model with session-level data will be fed into our final mart table, joining with customer and order information to provide a daily snapshot of customer activity. 

### Marts
The mart model in this project serves as the gold layer of our warehouse -- the analytics-ready layer where data has been aggregated and tailored for specific business reporting. The mart model in this project is customer_summary_daily -- an aggregated look at the behavior of a customer per day. The model contains one record per customer per day, even if a customer does not have any events or purchases for that given day. If the Analytics team only wants active customers, then we can tweak the model to instead only publish records for customers who had an active session on the reporting day. I've also decided to only include metrics on created orders/actions, excluding returns and shipping metrics. This can be something we implement later, either in this table or a more specific customer action-based mart table.

**Note:** This mart refreshes once a day, which means it does not make full use of the more frequent load cadence of the int_event_sessions model. This mart is therefore better suited for downstream consumers that are reporting on daily numbers; for other consumers that want near-real-time analytics, we can create a second mart that focuses on sessions (as opposed to users), refreshing every 15 minutes along with the int_event_sessions model.

## Validations
I've included basic built-in dbt tests across all models, primarily not_null and unique checks on the most important identifying/ID columns and join keys. In order to ensure that our upstream sources are not missing data/affected by a source system outage, I've also added referential checks on columns like user_id and order_id. If our order table contains user ID's that do not have a match in the user table, then we will know that the user source system has most likely had an incomplete load.

To build a more robust monitoring framework, we will leverage quality checks across both dbt and Airflow, which can include: 
- Freshness: for our batch tables (orders, order items, users), we can make use of Fivetran's built-in `_fivetran_synced` column (which does not currently exist in the source BQ tables). If the sync timestamp of our ingested records violates our freshness SLA (i.e., if the sync timestamp is older than 24 hours), we will be alerted and can assume that there's been a lag in the refresh of our upstream tables.
- Row count monitoring: if we suddenly receive a load of orders that's 25% lower than the average across the past 7 days, that can indicate that only a partial load occurred. 
- Schema changes: we want to capture any schema changes made to upstream models, including the addition of new columns, the deletion of existing columns, and any changes made to a column's data type. Dbt offers several types of configurations to handle schema changes; in order to adhere to standard data governance principles, in which a table's definition is standardized and all metadata changes are tracked, I would set this configuration to fail upon encountering any schema changes. This will ensure that we are aligned with the upstream teams who publish the data and allow us to make sure the actual data structure is in sync with our published definitions and lineage.


## Architecture Diagram
<img width="390" height="503" alt="trumid_arch" src="https://github.com/user-attachments/assets/3d73cd3a-104b-4158-bdfa-6ebd92f77e98" />


## AI Tools
I used Google to refresh my memory on some of the dbt configuration syntax and values, and checked my code for int_event_sessions in Claude to make sure I had structured the merge + lookback window logic correctly. 