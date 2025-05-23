# Cohort Analysis - Practical Guide

Cohort analysis is like creating "generations" of your customers to understand how they behave over time. It's a super powerful tool for growing your business intelligently.

## What is a Cohort? (Simple Explanation)

Imagine you have an online store. A **cohort** is simply a group of customers who did something important in the same month:

```
January Cohort = Everyone who made their first purchase in January
February Cohort = Everyone who made their first purchase in February
March Cohort = Everyone who made their first purchase in March
```

## What is it Used For?

### 1. **Know if your customers come back**
```
Out of 100 customers who bought in January:
- How many bought again in February?
- How many kept buying in March?
- How many are still customers after 6 months?
```

### 2. **Identify problems and opportunities**
```
If you notice that:
- January customers have 80% retention
- March customers have 60% retention
→ Something changed between January and March that you should investigate
```

### 3. **Measure the impact of changes**
```
Before improving your app: 70% retention
After improving your app: 85% retention
→ Your improvement worked!
```

## Practical Example: Subscription Store

### Sample Data
```
January 2023 Cohort:
- 100 people subscribed
- Month 1: 85 kept paying (85% retention)
- Month 2: 72 kept paying (72% retention)
- Month 3: 65 kept paying (65% retention)

February 2023 Cohort:
- 120 people subscribed
- Month 1: 108 kept paying (90% retention) ← Better!
- Month 2: 96 kept paying (80% retention) ← Better!
```

### What does this tell you?
- February customers are more "sticky"
- Something improved between January and February
- You should investigate what you did right in February

## How to Use Cohorts in Native Payments

### 1. **View Customer Retention**
```
GET /api/payment/analytics/cohorts?cohort_type=first_purchase&start_cohort=2023-01
```

**Response:**
```json
{
  "cohort_analysis": [
    {
      "cohort_month": "2023-01",
      "cohort_size": 100,
      "retention_by_month": [
        {"month": 0, "users": 100, "retention_rate": 100.0},
        {"month": 1, "users": 85, "retention_rate": 85.0},
        {"month": 2, "users": 72, "retention_rate": 72.0}
      ]
    }
  ]
}
```

### 2. **Compare Different Periods**
```javascript
// Compare cohorts from different months
const comparison = {
  january: { month_1_retention: 85, month_3_retention: 65 },
  february: { month_1_retention: 90, month_3_retention: 75 },
  march: { month_1_retention: 88, month_3_retention: 70 }
};

// Conclusion: February was your best month for retention
```

## Real Use Cases

### 1. **Evaluate a Marketing Campaign**

**Situation:** You launched a campaign in March

```
Pre-Campaign Cohort (February):
- 120 new customers
- 75% retention at 3 months

Post-Campaign Cohort (March):
- 200 new customers ← More customers
- 60% retention at 3 months ← But lower quality

Conclusion: Campaign brought more customers but lower quality
```

### 2. **Optimize Your Product**

**Situation:** You improved onboarding in April

```
Before Cohort (March):
- Month 1: 70% retention
- Month 2: 55% retention

After Cohort (May):
- Month 1: 85% retention ← 15% better!
- Month 2: 75% retention ← 20% better!

Conclusion: Your onboarding improvement worked perfectly
```

### 3. **Identify Seasonality**

```
Winter Cohorts (Dec-Feb): 80% average retention
Summer Cohorts (Jun-Aug): 65% average retention

Conclusion: Winter customers are more loyal
Action: Focus marketing in winter, improve product for summer
```

## Useful Cohort Types

### 1. **First Purchase Cohort**
- Groups by month of first purchase
- Useful for: Measuring general customer retention

### 2. **First Subscription Cohort**
- Groups by month of first subscription
- Useful for: Measuring subscriber retention

### 3. **Registration Cohort**
- Groups by month of registration
- Useful for: Measuring conversion from registration to purchase

## Important Metrics

### 1. **Retention by Month**
```
Month 0: 100% (everyone starts here)
Month 1: 85% (15% left)
Month 3: 65% (35% left total)
Month 6: 45% (55% left total)
```

### 2. **Revenue by Cohort**
```
January Cohort:
- Month 1: $5,000 revenue
- Month 2: $4,200 revenue
- Month 3: $3,800 revenue
```

### 3. **Lifetime Value by Cohort**
```
January Cohort: $450 average LTV
February Cohort: $520 average LTV
March Cohort: $380 average LTV
```

## How to Interpret Results

### 🟢 **Good Signals**
- Month 1 retention > 80%
- Month 3 retention > 60%
- Recent cohorts improve vs previous ones
- Revenue per user maintains or grows

### 🟡 **Warning Signals**
- Month 1 retention < 70%
- Month 3 retention < 50%
- Recent cohorts worsen vs previous ones
- Revenue per user decreases

### 🔴 **Serious Problems**
- Month 1 retention < 60%
- Month 3 retention < 40%
- Consistent downward trend
- New cohorts much worse than old ones

## Actions Based on Cohorts

### If Retention is Low:
1. **Improve onboarding** - Help new users
2. **Retention program** - Emails, offers, support
3. **Improve product** - Remove friction
4. **Better segmentation** - Attract more suitable customers

### If Some Cohorts are Better:
1. **Analyze what you did differently** in those months
2. **Replicate successful strategies**
3. **Study characteristics** of those customers
4. **Adjust marketing** to attract similar customers

## Visualization Tools

### Retention Table
```
Cohort    | Month 0 | Month 1 | Month 2 | Month 3 | Month 6
----------|---------|---------|---------|---------|--------
2023-01   |   100%  |    85%  |    72%  |    65%  |    45%
2023-02   |   100%  |    90%  |    80%  |    75%  |    52%
2023-03   |   100%  |    88%  |    78%  |    70%  |     ?
```

### Retention Chart
```
100% ████████████████████████████████
 90% ████████████████████████████▓▓▓▓
 80% ████████████████████████▓▓▓▓▓▓▓▓
 70% ████████████████████▓▓▓▓▓▓▓▓▓▓▓▓
 60% ████████████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
     Month 0  Month 1  Month 2  Month 3  Month 6
```

## Next Steps

1. **Implement cohort tracking** in your application
2. **Review monthly** retention data
3. **Experiment** with improvements and measure impact
4. **Segment** your cohorts by characteristics (source, plan, etc.)
5. **Automate alerts** when retention drops

Cohort analysis will give you super valuable insights to grow your business intelligently and based on real data.
