# Retail Profitability Analysis

## Project Overview

This project analyzes whether increasing discounts are driving
**profitable growth** or whether revenue growth is masking **margin
erosion caused by discounts and product returns**.

The workflow is:

**Python & Pandas → MySQL → Power BI**

The project prepares an analysis-ready order-line dataset, calculates
realized revenue and profitability after discounts and returns, answers
four business questions using SQL, and presents the findings in a
single-page Power BI management dashboard.

## Business Problem

Management believes:

> "Increasing discounts is helping us grow."

The Finance Head is concerned that:

> "Revenue is increasing, but we may actually be destroying
> profitability through discounts and returns."

The objective is to determine:

* Whether higher discounts generate profitable revenue
* Which product categories experience discount-driven margin erosion
* Whether revenue growth is accompanied by profit growth
* Whether high-revenue customers are actually profitable
* Where revenue targets are achieved while margin targets are missed

## Project Structure

```text
Retail-Profitability-Analysis/
│
├── python/
│   └── profitability_analyzer.py
│
├── sql/
│   └── profitability_analysis.sql
│
├── powerbi/
│   └── Retail_Profitability_Dashboard.pbix
│
├── data/
│   └── README.md
│
└── README.md
```

## Part 1 --- Python & Pandas

A Python class named `ProfitabilityAnalyzer` is used to load and prepare
the retail data.

### Data Quality Checks

The analysis handles:

* Duplicate or missing `order_line_id`
* Quantity less than or equal to zero
* Invalid `unit_price`
* Invalid `cost_per_unit`
* Discount percentage outside 0--100%
* Returns where `return_qty > quantity`
* Return date earlier than order date
* Returns linked to non-existing `order_line_id`

Only the required validation checks are performed.

### Data Grain

The `order_lines` table is at **order-line level**.

One `order_id` can contain multiple products, and the returns table can
contain multiple return records for the same order line.

Returns are therefore aggregated by `order_line_id` before joining to
sales data. This prevents sales revenue from being duplicated.

### Calculated Fields

* `gross_revenue`
* `discount_amount`
* `net_revenue`
* `total_return_qty`
* `total_refund`
* `realized_revenue`
* `realized_cogs`
* `realized_profit`
* `realized_margin_pct`

### Key Calculations

```text
gross_revenue = quantity × unit_price

discount_amount = gross_revenue × discount_pct / 100

net_revenue = gross_revenue - discount_amount

realized_revenue = net_revenue - total_refund

realized_cogs = cost_per_unit × (quantity - total_return_qty)

realized_profit = realized_revenue - realized_cogs

realized_margin_pct = realized_profit / realized_revenue × 100
```

The final analysis-ready dataset is loaded into MySQL.

## Part 2 --- SQL Analysis

All business questions are solved using SQL.

### Question 1 --- Is Higher Discount Actually Better?

Discount groups:

Discount Group    Range

---

Low Discount      0%--10%
Medium Discount   >10%--25%
High Discount     >25%

For each `product_category` and discount group, the analysis calculates:

* Distinct orders
* Average order value
* Realized revenue
* Realized profit
* Realized margin %
* Return rate

The objective is to identify categories where higher discounts generate
higher revenue per order but lower realized profit margins.

### Question 2 --- Growth Without Profitability

For each region and month, the analysis calculates:

* Realized revenue
* Realized profit
* Realized margin %
* Month-on-month revenue growth %
* Month-on-month profit growth %

SQL window functions are used to compare each month with the previous
month.

The analysis identifies cases where:

```text
Revenue Growth > 0
AND
Profit Growth < 0
```

These represent periods where revenue is growing while profitability is
declining.

### Question 3 --- High-Value Customers That May Not Actually Be Valuable

Customer-level metrics include:

* Total orders
* Realized revenue
* Realized profit
* Realized margin %
* Return rate
* Average discount %

Window functions identify customers in the **top 20% by realized
revenue**.

Among those customers, the analysis identifies customers with:

```text
Realized Margin % below company median
OR
Return Rate above company average
```

The final result returns the top 15 such customers ranked by realized
revenue.

### Question 4 --- Revenue Target Achieved but Business Target Missed

Actual monthly performance is joined with `monthly_targets`.

The analysis calculates:

```text
Revenue Target Attainment %
= Actual Realized Revenue / Revenue Target × 100

Margin Gap
= Actual Realized Margin % - Target Margin %
```

A region-month is classified as **Unprofitable Growth** when:

```text
Revenue Target Attainment >= 100%
AND
Actual Margin < Target Margin
```

## Part 3 --- Power BI Dashboard

A single-page management dashboard answers:

> **Where is revenue growth healthy, and where is growth being purchased
> through discounts and margin loss?**

### Main DAX Measures

```dax
Trusted Revenue =
SUM(analysis_ready[realized_revenue])
```

```dax
Total Realized Revenue =
SUM(analysis_ready[realized_revenue])
```

```dax
Realized Profit =
SUM(analysis_ready[realized_profit])
```

```dax
Total Realized Profit =
SUM(analysis_ready[realized_profit])
```

```dax
Realized Margin % =
DIVIDE(
    [Realized Profit],
    [Trusted Revenue],
    0
)
```

```dax
Revenue Target =
SUM(monthly_targets[revenue_target])
```

```dax
Revenue Target Attainment % =
DIVIDE(
    [Trusted Revenue],
    [Revenue Target],
    0
)
```

Supporting measures include:

* Average Discount %
* Return Rate %
* Margin Target %
* Margin Gap %

### Dashboard Visuals

#### 1. Discount Effectiveness --- Scatter Plot

* X-axis → Average Discount %
* Y-axis → Realized Margin %
* Bubble Size → Realized Revenue
* Legend → Product Category

This helps identify categories where high discounting is associated with
lower margins.

#### 2. Growth Quality --- Monthly Trend

Shows:

* Realized Revenue
* Realized Profit

A region slicer allows management to analyze individual regions.

#### 3. Target Quality Matrix

Shows:

* Region
* Month
* Revenue Target Attainment %
* Realized Margin %
* Margin Target
* Margin Gap

Conditional formatting highlights cases where revenue targets are
achieved but margin targets are missed.

#### 4. Customer Value Paradox

Shows high-revenue customers with:

* Revenue
* Profit
* Margin %
* Return Rate
* Average Discount %

Customers with high revenue but low profitability or high returns are
highlighted.

## Technologies Used

* Python
* Pandas
* NumPy
* MySQL
* SQL Window Functions
* Power BI
* DAX
* Excel

## End-to-End Workflow

```text
Raw Excel Data
      ↓
Python & Pandas
      ↓
Data Quality Checks
      ↓
Aggregate Returns
      ↓
Calculate Realized Revenue & Profit
      ↓
Analysis-Ready Dataset
      ↓
MySQL
      ↓
SQL Business Analysis
      ↓
Power BI
      ↓
Management Dashboard
      ↓
Business Insights
```

## Key Business Questions

This project helps management determine:

1. Does higher discounting improve profitable revenue?
2. Are there regions where revenue grows while profit declines?
3. Are the highest-revenue customers also profitable?
4. Are revenue targets being achieved at the expense of margin?
5. Which categories, regions, and customers represent profitability
   risks?


# Final Business Conclusion

## Answer: NO

Increasing discounts are **not demonstrating profitable growth** in the analysis. The results show clear cases where higher discounting is associated with substantial margin erosion and periods where revenue grows while profit declines.

### Three Quantitative Findings

**1. Discounting is associated with major margin erosion in Electronics.**

Electronics realized margin falls from **23.20% at Low Discount** to **5.33% at Medium Discount** and **-14.62% at High Discount**. This represents a **37.82 percentage-point decline** from Low to High Discount.

**2. Revenue can grow while profit declines sharply.**

In **West, April 2026**, realized revenue increased by **14.59%**, while realized profit decreased by **50.50%**. This is a direct example of growth without profitability.

**3. High-revenue customers can still have weak profitability.**

Customer **C1187** generated **₹205,404.42** in realized revenue but only **₹14,394.50** in realized profit, resulting in a realized margin of **7.01%**. The customer also had an average discount of **25.25%**.

### Business Interpretation

The analysis indicates that revenue growth should not be evaluated in isolation. Higher discounting can increase sales activity while reducing realized margins, and returns can further reduce realized revenue and profit.

Therefore:

> **Increasing discounts are not, by themselves, demonstrating profitable growth.**

---

## Author

**Shraddha Gobare**

Computer Science & Engineering Graduate
Data Analytics | Python | SQL | Power BI | Data Science
