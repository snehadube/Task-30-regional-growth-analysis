# Regional Growth Analysis (SQL + Excel)

Task from my Data Analytics internship at **Veda Technology**: compare how fast each region grew over time, and check whether the growth numbers are actually trustworthy.

**Dataset:** Superstore (9,994 order lines, Jan 2014 - Dec 2017, 4 regions)
**Tools:** SQL (SQLite) and Excel

## What I found

| Region | 2014 sales | 2017 sales | CAGR |
|---|---|---|---|
| West | $147.9k | $250.1k | 19.1% |
| East | $128.7k | $213.1k | 18.3% |
| Central | $103.8k | $147.1k | 12.3% |
| South | $103.8k | $122.9k | 5.8% |

1. **West and East carry the growth** - about 75% of the company's $249k sales gain. East grew every single year.
2. **South's swings are partly one order.** A single $22.6k Cisco order was 21.8% of South's 2014 sales. Without it, the 2015 drop is -12%, not -31%.
3. **Central's +2,072% profit growth (2015) is a small-base effect.** It started from $540, so the gain was only $11.2k.
4. **Central grows sales but loses profit.** 2017 sales were flat, profit fell 62%. Highest discounts, and Texas + Illinois lost ~$15.6k.
5. **Compare the same quarter, not the previous one.** Q3 to Q4 shows +104% for Central in 2016; the real year-on-year growth was +59.7%.

## How I did it

- **Periods:** calendar years and calendar quarters, so every comparison uses the same length of time.
- **SQL:** one clean view (`orders_clean`), then 8 queries with CTEs and `LAG()` for YoY, CAGR, same-quarter growth, a small-base flag, growth contribution, outlier check and discount analysis.
- **Excel:** the same tables rebuilt with `SUMIFS` on the raw data, charts, and a `SQL_vs_Excel` sheet that checks both methods give identical numbers (16/16 match).

## Repo structure

```
sql/regional_growth_analysis.sql      all queries, commented
excel/Regional_Growth_Analysis.xlsx   formulas, charts, small-base check, insights
report/Regional_Growth_Analysis_Report.pdf
query_results/                        CSV output of each SQL query
images/                               charts used in the report
data/superstore.csv                   original source data
data/superstore_clean.csv             cleaned copy used for the SQL import
```

## Run it yourself

1. Open DB Browser for SQLite, create a new database and import `data/superstore_clean.csv` (File > Import > Table from CSV) as a table named `superstore`.
2. Run `sql/regional_growth_analysis.sql`.

`superstore_clean.csv` is the original file with lower_case column names and dates written as YYYY-MM-DD.

## What I learned

Growth rate on its own can mislead: a tiny base inflates it, one big order can distort it, and seasonality can fake it. I now always look at the percentage, the dollar change and CAGR together.
