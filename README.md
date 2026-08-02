# Readme

This repo utilizes four of the tables included in the thelook_ecommerce dataset -- events, order items, orders, and users -- to create an analytics-ready mart table summarizing customer activity and revenue by day.

## Business Value
This model is designed to provide stakeholders with a once-daily report of customer activity, and can be built upon in the future to provide a near-real-time dataset of user behavior on our website.
The questions our current model can answer:
- How many customers were "active" (visited our website or made an order) on a given day? How many of these active customers actually made a purchases, versus just navigating on our website?
- For the active customers, how much time was spent on our website, and what was the source that brought them to our website (e.g. social media ad, email)?
- How much revenue did the active customers bring in? And what was the average revenue by order?
- Is there any correlation between geographic location and customer activity? If we were running ads in local markets, this could give us data on conversion rates

## Models

### Staging
The staging models in this project serve as the bronze-layer of our warehouse -- the layer of data closest to the source. The staging models here are 1:1 with the source tables and only contain minor transformations/logic, mostly to standardize inputs (e.g., ensuring correct casing of an ID if it's a string -- this will ensure correct joins between tables later on). I have four staging models -- one each for the events, orders, order items, and users tables from BigQuery. 

In my specific example, I am assuming that the orders, order items, and users tables refresh once daily via batching, while the events table comes from a streaming and/or microbatching source. The cadence of dbt runs should be once daily for orders, order items, and users, and every 15 minutes for events. The final mart table will follow the once-daily cadence of the four batch tables.

### Intermediate
The intermediate model in this project serves as the silver layer of our warehouse -- the layer of data after the bronze layer, where the majority of the joins, transformations, and business logic are implemented. I have one intermediate model here, int_event_sessions. The model takes the streaming events data and publishes it at the session level. Looking at events in aggregate typically provides more "meaning" and context than an isolated event, and rolling the events up into their respective sessions also allows for more meaningful joins further downstream.

### Marts
The mart model in this project is customer_summary_daily -- an aggregated look at the behavior of a customer per day. I've currently designed it to be at the customer level, even if a customer does not have any events or purchases for that given day. If the Analytics team only wants active customers, then we can tweak the model to instead only publish records for customers who had an active session on the reporting day. I've also decided to only include metrics on created orders/actions, excluding returns and shipping metrics. This can be something we implement later, either in this table or a more specific customer action-based mart table.

**Note:** this mart refreshes once a day, which means it does not make full use of the more frequent load cadence of the int_event_sessions model. This mart is therefore better suited for downstream consumers that are reporting on daily numbers; for other consumers that want near-real-time analytics, we can create a second mart that focuses on sessions (as opposed to users), refreshing every 15 minutes along with the int_event_sessions model.

## Validations
I've included basic built-in dbt tests across all models, primarily not_null and unique checks on the most important identifying/ID columns and join keys. In order to ensure that our upstream sources are not missing data/affected by a source system outage, I've also added referential checks on columns like user_id and order_id. If our user source system had an incomplete load, then it will be missing user ID's and we will be alerted by these checks.

To build a more robust monitoring framework, we will have to leverage quality checks across both dbt and Airflow that check for data freshness. For our batch tables (orders, order items, users), we can make use of Fivetran's built-in `_fivetran_synced` column (which does not currently exist in the source BQ tables). If this timestamp violates our freshness SLA, we will be alerted and can assume that there's been a lag in the refresh of our upstream tables. Additional checks can include row count monitoring -- if we suddenly receive a load of orders that's 25% lower than the average across the past 7 days, that can indicate that only a partial load occurred.


## Architecture Diagram
<img width="390" height="503" alt="trumid_arch" src="https://github.com/user-attachments/assets/3d73cd3a-104b-4158-bdfa-6ebd92f77e98" />

