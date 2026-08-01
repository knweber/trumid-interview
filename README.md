# Readme

This repo utilizes five of the tables included in the thelook_ecommerce dataset to create the following models:

## Staging
The staging models in this project serve as the bronze-layer of our warehouse -- the layer of data closest to the source. The staging models here are 1:1 with the source tables and only contain minor transformations/logic, mostly to standardize inputs. 

## Intermediate
The intermediate model in this project is int_event_patterns_bucketed. This table aggregates clickstream data 

## Marts
The mart model in this project is customer_summary_daily -- an aggregated look at the behavior of a customer per day.