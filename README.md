# E-Commerce Data Warehouse Project

This repository contains my AWS Glue and PySpark e-commerce data warehouse project.

## Project flow

```text
Raw CSV Data in Amazon S3
          |
          v
AWS Glue / PySpark
          |
          v
Processed Parquet Data in S3
          |
          v
Athena SQL Analytics
```

## Repository contents

- `mahmoud-ecommerce-dw-pipeline.ipynb`: Glue PySpark notebook used for profiling, cleaning, dimensions, facts, incremental processing, and validation.
- `athena_analytics_queries.sql`: Athena queries for KPIs, monthly analysis, rankings, running sales, and month-over-month growth.
- `ecommerce_dw_project_report.md`: Simple first-person project report with screenshot placeholders.
- `.gitignore`: Prevents credentials, environment files, private keys, and notebook checkpoints from being committed.

## Main outputs

The pipeline creates ten dimensions and six fact tables in the processed S3 layer. It also processes new API orders incrementally and validates sales totals across the transaction and aggregate facts.

## Important note

AWS credentials, IAM private keys, `.env` files, and other secrets must never be uploaded to this repository. The S3 bucket name and SQL/table names are project metadata, but access keys and private credentials must remain private.
