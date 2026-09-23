# E-Commerce Data Warehouse Project Report

## 1. Project Overview

I built a small e-commerce data warehouse pipeline using AWS Glue, PySpark, Amazon S3, and Athena SQL. The main goal was to take raw e-commerce data, clean and transform it, create dimensions and fact tables, save the results as Parquet files, process new API orders incrementally, and run analytical SQL queries.

The final data flow was:

```text
Python API / JSON Orders
          |
          v
      Amazon S3 Raw Layer
          |
          v
     AWS Glue / PySpark
          |
          v
   S3 Processed Parquet Layer
          |
          v
       Athena SQL Analytics
```

> **Screenshot placeholder:** Insert a screenshot of the final AWS architecture or data flow here.

I continued using my existing S3 bucket instead of creating a new historical dataset. This kept the project consistent with the previous work and avoided duplicating data.

## 2. AWS Environment and Storage

The S3 bucket used in the project was:

```text
s3://mahmoud-sic-ecommerce-2026/
```

The historical raw data was stored in:

```text
s3://mahmoud-sic-ecommerce-2026/raw/ecommerce/
```

The source layer contained these CSV files:

```text
customers.csv
categories.csv
products.csv
departments.csv
employees.csv
suppliers.csv
orders.csv
order_details.csv
payments.csv
product_suppliers.csv
shippers.csv
shipments.csv
```

The processed data was stored in:

```text
s3://mahmoud-sic-ecommerce-2026/processed/ecommerce/
```

I kept the old processed outputs and added the new warehouse outputs beside them. This protected the previous work and made it possible to compare the old outputs with the new warehouse design.

> **Screenshot placeholder:** Insert an S3 screenshot showing the raw and processed folders.

## 3. Data Understanding and Profiling

I created a Glue PySpark notebook named `mahmoud-ecommerce-dw-pipeline`. I used it to read the source CSV files from S3 with Spark.

For every source table, I checked the schema, displayed sample records, counted rows, counted columns, reviewed keys, and checked null values and duplicate business keys.

The source table sizes were:

| Source table | Rows | Columns |
|---|---:|---:|
| customers | 10,000 | 7 |
| categories | 20 | 2 |
| products | 1,000 | 7 |
| departments | 10 | 2 |
| employees | 200 | 7 |
| suppliers | 100 | 3 |
| orders | 50,000 | 4 |
| order_details | 100,000 | 6 |
| payments | 45,000 | 5 |
| product_suppliers | 2,027 | 2 |
| shippers | 10 | 2 |
| shipments | 40,000 | 5 |

The main business keys were `CustomerID`, `CategoryID`, `ProductID`, `DepartmentID`, `EmployeeID`, `SupplierID`, `OrderID`, `OrderDetailID`, `PaymentID`, `ShipperID`, and `ShipmentID`. The bridge table `product_suppliers` was checked using the combination of `ProductID` and `SupplierID`.

> **Screenshot placeholder:** Insert a screenshot showing a Spark schema and sample records.

## 4. Data Quality Checks

### 4.1 Null Values

I checked null values in every source table. The source data was mostly complete. The main expected nullable value was `ManagerID` in the employee table because the top-level manager does not have another manager.

The profiling output showed one null value in `ManagerID` and zero null values in the other displayed source columns.

### 4.2 Duplicate Business Keys

I checked duplicate values using the appropriate key for each table. The profiling results showed zero duplicate groups for the primary/business keys in the source tables.

For the bridge table, I checked duplicate `ProductID + SupplierID` combinations.

### 4.3 Invalid Values and Relationships

I included checks for negative prices, negative quantities, negative payment amounts, invalid email formats, invalid dates, and shipments delivered before they were shipped. I also checked relationships using joins and anti-joins, including:

- Orders with missing customers.
- Order details with missing products.
- Payments with missing orders.
- Shipments with missing orders.

These checks helped confirm that the transformed facts could be connected to the dimensions without orphan keys.

## 5. Data Cleaning and Standardization

I cleaned the source data with PySpark before building the warehouse tables. The main cleaning actions were:

1. I converted the source column names to lowercase snake-case style.
2. I removed unnecessary spaces from string values.
3. I standardized string values such as order statuses.
4. I converted dates and timestamps to appropriate Spark date or timestamp types.
5. I converted numeric values to suitable integer, double, or decimal types.
6. I cleaned email fields and checked their format.
7. I removed duplicate records using the business key.
8. I validated numeric values and dates.
9. I separated the cleaned data from the raw data instead of changing the original CSV files.

The cleaned and transformed outputs were saved as Parquet files with Snappy compression.

## 6. Dimension Tables

I built ten dimensions. Each dimension has a surrogate key generated in the transformation layer and keeps the original business identifier where it is available.

| Dimension | Main source | Final rows |
|---|---|---:|
| `dim_customer` | customers | 10,000 |
| `dim_product` | products and categories | 1,000 |
| `dim_category` | categories | 20 |
| `dim_department` | departments | 10 |
| `dim_supplier` | suppliers | 100 |
| `dim_employee` | employees | 200 |
| `dim_shipper` | shippers | 10 |
| `dim_date` | generated calendar | 999 |
| `dim_payment_method` | unique payment methods | 6 |
| `dim_order_status` | unique order statuses | 6 |

### 6.1 Customer Dimension

I created `dim_customer` from the customer source table. It contains the generated `customer_key`, the original `customer_id`, customer name, email, city, country, and registration date.

### 6.2 Product Dimension

I created `dim_product` from products and joined it to the category dimension. I also calculated product-level business attributes such as:

```text
profit_per_unit = price - cost
profit_margin = (price - cost) / price
```

The source product table did not contain a reliable `department_id`. Therefore, the `department_key` was not populated with an invented relationship. I documented this limitation instead of creating a false mapping.

### 6.3 Date, Payment Method, and Order Status Dimensions

I generated `dim_date` to cover the complete date range in the source data. It contains `date_key`, `full_date`, day, month, month name, quarter, year, week, day name, and a weekend flag.

I created `dim_payment_method` from the unique payment methods in the payments data. I created `dim_order_status` from the unique statuses in the orders data.

> **Screenshot placeholder:** Insert a screenshot showing the dimension output and row counts.

## 7. Fact Tables and Grain

Before building each fact table, I defined its grain. The grain explains what one row represents.

| Fact table | Grain |
|---|---|
| `fact_order` | One row per order |
| `fact_order_detail` | One row per product line inside an order |
| `fact_payment` | One row per payment transaction |
| `fact_shipment` | One row per shipment |
| `fact_customer_sales` | One customer per day |
| `fact_product_sales` | One product per day |

### 7.1 Order Detail Fact

I built `fact_order_detail` by joining orders, order details, products, customers, dates, and order statuses. It contains the required foreign keys and measures:

```text
order_id
order_detail_id
product_key
customer_key
date_key
quantity
unit_price
discount
gross_sales
discount_amount
net_sales
cost_amount
profit
```

The calculated measures were:

```text
gross_sales = quantity * unit_price
discount_amount = gross_sales * discount / 100
net_sales = gross_sales - discount_amount
cost_amount = quantity * product_cost
profit = net_sales - cost_amount
```

### 7.2 Order Fact

I built `fact_order` at one row per order. I aggregated the order detail rows to calculate line count, product count, total quantity, gross sales, discount amount, net sales, cost, and profit.

### 7.3 Payment and Shipment Facts

I built `fact_payment` at one row per payment transaction and connected it to the customer, date, and payment method dimensions.

I built `fact_shipment` at one row per shipment and connected it to the customer, shipper, and date dimensions. I calculated delivery duration using the difference between delivery date and ship date:

```text
delivery_days = delivery_date - ship_date
```

### 7.4 Aggregated Sales Facts

I created `fact_customer_sales` by grouping the detail fact by `customer_key` and `date_key`.

I created `fact_product_sales` by grouping the detail fact by `product_key` and `date_key`.

The final output row counts were:

| Fact table | Rows |
|---|---:|
| `fact_order` | 50,003 |
| `fact_order_detail` | 100,010 |
| `fact_payment` | 45,003 |
| `fact_shipment` | 40,003 |
| `fact_customer_sales` | 43,039 |
| `fact_product_sales` | 95,112 |

## 8. JSON and Incremental Processing

I processed new API orders separately from the historical CSV files. The new records were stored in the same S3 bucket under a separate API raw area and were transformed into the same structure as the historical data.

I used the existing historical maximum IDs as the starting point. The incremental data contained:

- New order IDs from 50,001 to 50,003.
- New order detail IDs from 100,001 to 100,010.
- New payment IDs from 45,001 to 45,003.
- New shipment IDs from 40,001 to 40,003.

The new incremental output contained three new orders, ten order detail rows, three payments, and three shipments.

I used a checkpoint file to store the last processed order ID:

```text
s3://mahmoud-sic-ecommerce-2026/api_raw/checkpoint/last_order_id.txt
```

The final checkpoint value was:

```text
50003
```

This prevents the pipeline from processing the same API orders again during the next run.

> **Screenshot placeholder:** Insert a screenshot showing the checkpoint file or the incremental validation output.

## 9. S3 Processed Layer Validation

After writing the dimensions and facts to S3, I read the Parquet outputs again and compared their actual row counts with the expected counts.

All expected row-count checks passed:

| Table group | Result |
|---|---|
| Dimensions | All expected counts passed |
| Transaction facts | All expected counts passed |
| Aggregated facts | All expected counts passed |

I also checked duplicate keys in all dimensions and facts. The duplicate-key validation passed for every table.

The incremental record validation also confirmed that the new records were present in the final Parquet outputs.

## 10. Sales Reconciliation

I compared the totals from the detail fact and both aggregated sales facts.

| Measure | `fact_order_detail` | `fact_customer_sales` | `fact_product_sales` |
|---|---:|---:|---:|
| Net sales | 781,050,389.06 | 781,050,389.06 | 781,050,389.06 |
| Profit | 216,904,417.76 | 216,904,417.76 | 216,904,417.76 |
| Quantity | 549,510 | 549,510 | 549,510 |

This confirmed that the aggregation logic did not lose or duplicate sales values.

> **Screenshot placeholder:** Insert a screenshot of the reconciliation output.

## 11. Athena SQL Analytics

After finishing the data preparation, I used Athena to query the warehouse outputs. I wrote and executed queries for the required analytics tasks.

### 11.1 Overall KPIs

The KPI query calculated total sales, total orders, total customers, total products, total quantity sold, and total profit.

The main results were:

```text
Total sales: 781,050,389.06
Total quantity sold: 549,510
Total profit: 216,904,417.76
```

The counts were calculated using distinct business or surrogate keys.

### 11.2 Monthly Analysis

I grouped the detail fact by year, month, and month name. The query calculated monthly sales, order count, quantity, and profit. I ordered the output chronologically by year and month.

### 11.3 Sales by Category, Product, and Customer

I joined the detail fact to the appropriate dimensions and calculated sales, quantity, profit, and order count for each category, product, and customer.

Sales by department could not be calculated reliably because the source product data did not contain a valid department relationship. I did not create an artificial mapping.

### 11.4 Top Products and Customers

I used descending sales order with `LIMIT 10` to return the top ten products by sales. I used the same approach to return the top ten customers by total spending.

### 11.5 Average Order Value

I calculated Average Order Value using `fact_order`, because it contains one row per order. This avoids counting the same order multiple times when an order has several detail lines.

The result was:

```text
Total orders: 50,003
Total sales: 781,050,389.06
Average order value: 15,620.07
```

### 11.6 Order Status and Payment Analysis

I grouped orders by order status and calculated the number and value of orders for each status.

I grouped payments by payment method and calculated the number of transactions, total payment amount, and average payment amount.

### 11.7 Shipment Performance

I calculated total shipments, average delivery days, minimum delivery days, and maximum delivery days from `fact_shipment`. Invalid negative delivery durations were excluded from the performance calculation.

> **Screenshot placeholder:** Insert screenshots of the Athena outputs for status, payment, and shipment analysis.

## 12. Advanced SQL Queries

I also completed the required window-function queries:

1. **Running sales:** calculated daily sales and cumulative sales using `SUM(...) OVER (ORDER BY full_date)`.
2. **Month-over-month growth:** calculated current month sales, previous month sales with `LAG`, sales difference, and growth percentage.
3. **Product ranking:** ranked products by sales within each category and returned the top three products from each category.
4. **Customer ranking:** ranked customers by total spending and returned the order count for each customer.

These queries demonstrate that the warehouse can support both standard reporting and advanced analytical queries.

> **Screenshot placeholder:** Insert screenshots of the running sales, month-over-month, and ranking query results.

## 13. Final Validation Summary

The main validation results were successful:

- All source tables were profiled.
- The required dimensions were created.
- The required fact tables were created.
- Incremental records were added without duplicating historical business keys.
- All final S3 row counts matched the expected values.
- Duplicate-key checks passed.
- Surrogate-key null checks passed for the tested fact relationships.
- Detail and aggregate sales totals reconciled.
- Athena analytics queries executed successfully.

## 14. Limitations and Notes

The main limitation is the department relationship. The `products` source table contains a category relationship but does not contain a reliable department identifier. Therefore, I left the product department relationship unpopulated instead of inventing incorrect data. A real department analysis requires either a `department_id` in the product source or an approved category-to-department mapping.

The current execution evidence documents the AWS Glue, PySpark, S3 Parquet, incremental processing, and Athena analytics work. If a Redshift load is required for the final submission, the Redshift schemas, DDL, load commands, and row-count validation should be added as a separate deployment section with screenshots from the Redshift console.

## 15. Conclusion

I completed the main data warehouse pipeline from raw e-commerce data to cleaned Parquet outputs and Athena analytics. The pipeline includes source profiling, data-quality checks, cleaning, dimensions, facts, incremental API processing, S3 validation, sales reconciliation, and the required analytical SQL queries.

The final data was consistent across the detail and aggregate facts, and the incremental records were added correctly. The project is now ready to be documented with screenshots and uploaded as a clean GitHub repository.

## References

[1]: https://docs.aws.amazon.com/glue/latest/dg/what-is-glue.html "AWS Glue documentation"

[2]: https://spark.apache.org/docs/latest/sql-programming-guide.html "Apache Spark SQL programming guide"

[3]: https://docs.aws.amazon.com/athena/latest/ug/what-is.html "Amazon Athena documentation"

[4]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html "Amazon S3 documentation"

[5]: https://docs.aws.amazon.com/redshift/latest/dg/welcome.html "Amazon Redshift documentation"
