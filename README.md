# AdventureWorks Sales Analytics — Power BI Data Modeling & DAX Solution

An end-to-end Business Intelligence project built with **Power BI Desktop**, **Power Query (M)**, **DAX**, and **SQL Server (T-SQL)** on the AdventureWorks Reseller Sales dataset. The solution integrates relational SQL Server tables with external CSV sources into a clean **9-table dimensional model**, solves many-to-many salesperson-territory attribution via a bridge table and role-playing dimension, and implements custom fiscal Time Intelligence (July–June fiscal year) and hierarchical filter-context analytics.

---

## Tech Stack

* **BI & Modeling:** Microsoft Power BI Desktop
* **ETL / Data Shaping:** Power Query (M) — multi-source merging, unpivoting, custom cost imputation, and data cleansing
* **Analytics Engine:** DAX (Calculated Tables, Calculated Columns, Filter-Context Manipulation, Time Intelligence)
* **Source Database:** SQL Server (`AdventureWorksDW`) + T-SQL incremental `BULK INSERT` script

---

## Data Sources & Power Query ETL Pipeline

The model integrates **6 SQL Server tables** with **2 flat CSV files** (`ColorFormats.csv` merged into `Product` with load disabled; `ResellerSalesTargets.csv` unpivoted into `Targets`) plus an incremental monthly sales load (`ResellerSales_202006.csv`, 3,004 order lines):

| Model Table | Source | Key Power Query / DAX Transformations |
| :--- | :--- | :--- |
| **`Sales`** *(Fact)* | `FactResellerSales` | Imputed missing `TotalProductCost` via `[OrderQuantity] * [StandardCost]` (merged from `DimProduct`), typed financials as Fixed Decimal, hid surrogate keys. |
| **`Targets`** *(Fact)* | `ResellerSalesTargets.csv` (81 rows) | Unpivoted `M01`–`M12` columns, filtered `-` placeholders, derived `TargetMonth` dates (`MM/1/YYYY`), scaled targets by `× 1,000` into Fixed Decimal. |
| **`Product`** *(Dim)* | `DimProduct` + `ColorFormats.csv` | Filtered `FinishedGoodsFlag = TRUE` (397 products), expanded `Subcategory` and `Category`, left-outer merged hex color codes (`Background Color Format`, `Font Color Format`), built `Products` hierarchy. |
| **`Reseller`** *(Dim)* | `DimReseller` (701 rows) | Expanded `DimGeography` (`City`, `State-Province`, `Country-Region`), standardized `"Ware House"` → `"Warehouse"`, configured geographic data categories and `Resellers` / `Geography` hierarchies. |
| **`Region`** *(Dim)* | `DimSalesTerritory` (10 rows) | Filtered out `SalesTerritoryAlternateKey = 0`, built `Regions` hierarchy (`Group` → `Country` → `Region`). |
| **`Salesperson (Performance)`** *(Dim)* | `DimEmployee` (18 rows) | Filtered `SalesPersonFlag = TRUE`, merged `FirstName` + `LastName` into `Salesperson`, renamed `EmployeeID` & `UPN` (for RLS readiness). |
| **`SalespersonRegion`** *(Bridge)* | `DimEmployeeSalesTerritory` (39 rows) | Hidden bridge table resolving M:N salesperson-to-region assignments via bi-directional cross-filtering (with security filter enabled in both directions). |
| **`Salesperson`** *(Calculated Dim)* | DAX copy of `Salesperson (Performance)` | Role-playing dimension directly related (`1:*`) to `Sales[EmployeeKey]` to analyze direct individual sales independently from territory-level performance. |
| **`Date`** *(Calculated Dim)* | `CALENDARAUTO(6)` (1,826 rows) | Marked as official Date Table covering AdventureWorks' **July–June fiscal calendar** (`FY2018`–`FY2022`), with `Year`, `Quarter`, `Month` (sorted chronologically via hidden `MonthKey`), and `Fiscal` hierarchy. |

<!-- Uncomment once you export screenshots from Power BI Desktop -->
<!-- ![Data Model Schema](docs/images/data_model.png) -->

---

## DAX Calculation Architecture (`dax/measures_and_tables.dax`)

Measures are organized into structured display folders (`Pricing`, `Counts`, `Ratios`, `Time Intelligence`) while raw numeric columns such as `Unit Price` and `TargetAmount` are hidden to prevent accidental mis-aggregation:

* **Profitability:** `Profit` (`Sales - Cost`) and `Profit Margin` (`DIVIDE([Profit], SUM(Sales[Sales]))`).
* **Pricing & Order Counts:** `Avg Price`, `Median Price`, `Min Price`, `Max Price`, `Orders` (`DISTINCTCOUNT(Sales[SalesOrderNumber])`), and `Order Lines` (`COUNTROWS(Sales)`).
* **Non-Additive Target Tracking:** `Target`, `Variance`, and `Variance Margin` guarded with `HASONEVALUE('Salesperson (Performance)'[Salesperson])` so non-additive salesperson targets return `BLANK` at the grand-total level rather than double-counting.
* **Hierarchical Filter-Context Ratios:** `Sales All Region` / `Sales % All Region`, `Sales % Country`, and `Sales % Group` using `CALCULATE`, `REMOVEFILTERS`, and `ISINSCOPE` to compute clean percentage shares across the `Group → Country → Region` hierarchy.
* **Fiscal Time Intelligence:**
  * `Sales YTD` using `TOTALYTD(SUM(Sales[Sales]), 'Date'[Date], "6-30")` for June 30 fiscal year-end.
  * `Sales YoY Growth` using `VAR` + `PARALLELPERIOD('Date'[Date], -12, MONTH)` to compute prior-year variance cleanly.

---

## Report Views & Incremental Refresh Workflow

### Included Views in `powerbi/AdventureWorks_Sales_Analytics.pbix`
* **Page 1 — Category Profitability & Salesperson Target Variance:** Compares `Sales`, `Profit`, and `Profit Margin` by product category alongside individual `Salesperson` actuals vs. `Target`, `Variance`, and `Variance Margin`.
* **Page 2 — Fiscal Pricing, Volume & Time Intelligence Matrix:** Tracks `Avg`/`Median`/`Min`/`Max Price`, `Orders`, `Order Lines`, `Sales YTD`, and `Sales YoY Growth` across fiscal years and months.
* **Page 3 — Regional Contribution Matrix:** Breaks down `Sales` and hierarchical share percentages across `Group`, `Country`, and `Region`.

### Incremental Data Load (`sql/load_june_2020_sales.sql`)
To simulate a monthly warehouse refresh, run `sql/load_june_2020_sales.sql` against `AdventureWorksDW` to backfill missing `ShipDate` values (`+7 days` from `OrderDate`) and bulk-load the **3,004 June 2020 order lines** from `data/ResellerSales_202006.csv` (`widechar` UTF-16 format), then click **Refresh** in Power BI Desktop.

---

## Setup & Reproduction

1. **Restore Database:** Download and restore Microsoft's `AdventureWorksDW` sample database on your local SQL Server instance.
2. **Open Report:** Launch `powerbi/AdventureWorks_Sales_Analytics.pbix` in Power BI Desktop.
3. **Update Data Sources:** Go to **Home → Transform data → Data source settings** and update the SQL Server instance name and the local path to `data/ColorFormats.csv` and `data/ResellerSalesTargets.csv`.
4. **Test Incremental Refresh (Optional):** Update the file path inside `sql/load_june_2020_sales.sql`, execute it in SSMS, and refresh the `Sales` table in Power BI Desktop.
