# Customer Revenue Analysis - Individual Customer Insights

Understanding how much revenue each individual customer generates is crucial for making smart business decisions. This feature helps you identify your most valuable customers and optimize your strategies.

## What is Customer Revenue Analysis?

Customer Revenue Analysis tracks the complete financial relationship with each individual customer:

```
Customer #123:
- Total Spent: $1,250
- First Purchase: January 2023
- Last Purchase: December 2023
- Average Order: $125
- Purchase Frequency: Every 2 months
- Predicted LTV: $2,400
```

## Why Track Individual Customer Revenue?

### 1. **Identify VIP Customers**
```
Top 10% of customers might generate 50% of your revenue
→ Give them special treatment and retention focus
```

### 2. **Personalize Marketing**
```
High-value customers: Premium offers
Low-value customers: Entry-level promotions
At-risk customers: Retention campaigns
```

### 3. **Optimize Customer Acquisition**
```
If average customer LTV is $500
You can spend up to $400 on acquisition and still profit
```

### 4. **Predict Future Revenue**
```
Based on customer behavior patterns:
- When will they likely purchase again?
- What's their lifetime value potential?
- Are they at risk of churning?
```

## API Endpoint for Customer Revenue

### Get Individual Customer Revenue
```
GET /api/payment/analytics/customers/:userId/revenue
```

**Query Parameters:**
- `period`: 'all_time', 'last_12_months', 'last_6_months', 'ytd'
- `include_predictions`: true/false
- `breakdown`: 'monthly', 'quarterly', 'by_product'

**Example Request:**
```bash
curl "http://localhost:3000/api/payment/analytics/customers/user_123/revenue?period=all_time&include_predictions=true&breakdown=monthly"
```

**Example Response:**
```json
{
  "success": true,
  "customer_id": "user_123",
  "period": "all_time",
  "revenue_summary": {
    "total_revenue_cents": 125000,
    "total_orders": 10,
    "avg_order_value_cents": 12500,
    "first_purchase_date": "2023-01-15",
    "last_purchase_date": "2023-12-10",
    "customer_lifespan_days": 329,
    "purchase_frequency_days": 33,
    "total_refunds_cents": 2500,
    "net_revenue_cents": 122500
  },
  "monthly_breakdown": [
    {
      "month": "2023-01",
      "revenue_cents": 15000,
      "orders": 2,
      "avg_order_value_cents": 7500
    },
    {
      "month": "2023-02",
      "revenue_cents": 0,
      "orders": 0,
      "avg_order_value_cents": 0
    },
    {
      "month": "2023-03",
      "revenue_cents": 25000,
      "orders": 1,
      "avg_order_value_cents": 25000
    }
  ],
  "product_breakdown": [
    {
      "product_id": "premium_plan",
      "product_name": "Premium Monthly",
      "revenue_cents": 60000,
      "orders": 6,
      "percentage_of_total": 48.0
    },
    {
      "product_id": "addon_storage",
      "product_name": "Extra Storage",
      "revenue_cents": 30000,
      "orders": 3,
      "percentage_of_total": 24.0
    }
  ],
  "predictions": {
    "estimated_ltv_cents": 240000,
    "next_purchase_probability": 0.75,
    "next_purchase_predicted_date": "2024-01-15",
    "churn_risk_score": 0.15,
    "recommended_actions": [
      "Offer loyalty discount",
      "Suggest premium upgrade"
    ]
  },
  "customer_segment": "high_value",
  "meta": {
    "calculation_date": "2023-12-15T10:30:00Z",
    "data_freshness": "real_time"
  }
}
```

## Database View for Customer Revenue

### Customer Revenue View
```sql
CREATE VIEW customer_revenue_analysis AS
SELECT 
    o.user_id,
    u.name as customer_name,
    u.email as customer_email,
    COUNT(DISTINCT o.id) as total_orders,
    SUM(o.total_cents) as total_revenue_cents,
    AVG(o.total_cents) as avg_order_value_cents,
    MIN(o.created_at) as first_purchase_date,
    MAX(o.created_at) as last_purchase_date,
    DATEDIFF(MAX(o.created_at), MIN(o.created_at)) as customer_lifespan_days,
    CASE 
        WHEN COUNT(DISTINCT o.id) > 1 
        THEN DATEDIFF(MAX(o.created_at), MIN(o.created_at)) / (COUNT(DISTINCT o.id) - 1)
        ELSE NULL 
    END as avg_days_between_purchases,
    SUM(CASE WHEN o.status = 'refunded' THEN o.total_cents ELSE 0 END) as total_refunds_cents,
    SUM(CASE WHEN o.status = 'paid' THEN o.total_cents ELSE 0 END) - 
    SUM(CASE WHEN o.status = 'refunded' THEN o.total_cents ELSE 0 END) as net_revenue_cents,
    CASE 
        WHEN SUM(o.total_cents) >= 100000 THEN 'high_value'
        WHEN SUM(o.total_cents) >= 50000 THEN 'medium_value'
        WHEN SUM(o.total_cents) >= 10000 THEN 'low_value'
        ELSE 'minimal_value'
    END as customer_segment,
    CASE 
        WHEN DATEDIFF(CURDATE(), MAX(o.created_at)) > 90 THEN 'at_risk'
        WHEN DATEDIFF(CURDATE(), MAX(o.created_at)) > 60 THEN 'declining'
        WHEN DATEDIFF(CURDATE(), MAX(o.created_at)) > 30 THEN 'active'
        ELSE 'highly_active'
    END as activity_status
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.status IN ('paid', 'refunded')
GROUP BY o.user_id, u.name, u.email;
```

## Customer Segmentation

### Automatic Customer Segments
```javascript
const customerSegments = {
  "whale": {
    criteria: "total_revenue >= $10,000",
    percentage: "1%",
    treatment: "White-glove service, dedicated support"
  },
  "high_value": {
    criteria: "total_revenue >= $1,000",
    percentage: "10%", 
    treatment: "Priority support, exclusive offers"
  },
  "medium_value": {
    criteria: "total_revenue >= $100",
    percentage: "30%",
    treatment: "Regular promotions, loyalty program"
  },
  "low_value": {
    criteria: "total_revenue < $100",
    percentage: "59%",
    treatment: "Onboarding focus, conversion campaigns"
  }
};
```

### Customer Lifecycle Stages
```javascript
const lifecycleStages = {
  "new": {
    criteria: "first_purchase < 30 days ago",
    focus: "Onboarding and second purchase"
  },
  "active": {
    criteria: "last_purchase < 60 days ago",
    focus: "Engagement and upselling"
  },
  "at_risk": {
    criteria: "last_purchase 60-120 days ago",
    focus: "Retention campaigns"
  },
  "churned": {
    criteria: "last_purchase > 120 days ago",
    focus: "Win-back campaigns"
  }
};
```

## Practical Use Cases

### 1. **VIP Customer Identification**

```javascript
// Find your top 10 customers by revenue
const topCustomers = await db.query(`
  SELECT 
    user_id,
    customer_name,
    total_revenue_cents / 100 as total_revenue,
    total_orders,
    customer_segment
  FROM customer_revenue_analysis 
  ORDER BY total_revenue_cents DESC 
  LIMIT 10
`);

// Result:
[
  { user_id: "user_123", customer_name: "John Doe", total_revenue: 2500, total_orders: 15, customer_segment: "high_value" },
  { user_id: "user_456", customer_name: "Jane Smith", total_revenue: 1800, total_orders: 8, customer_segment: "high_value" }
]
```

### 2. **Churn Risk Detection**

```javascript
// Find customers at risk of churning
const atRiskCustomers = await db.query(`
  SELECT 
    user_id,
    customer_name,
    last_purchase_date,
    DATEDIFF(CURDATE(), last_purchase_date) as days_since_purchase,
    total_revenue_cents / 100 as total_revenue
  FROM customer_revenue_analysis 
  WHERE activity_status = 'at_risk'
  AND customer_segment IN ('high_value', 'medium_value')
  ORDER BY total_revenue_cents DESC
`);
```

### 3. **Personalized Offers**

```javascript
// Generate personalized offers based on customer value
async function generatePersonalizedOffer(userId) {
  const customer = await getCustomerRevenue(userId);
  
  if (customer.customer_segment === 'high_value') {
    return {
      offer_type: "exclusive_early_access",
      discount_percentage: 20,
      message: "As a valued customer, get 20% off our new premium features"
    };
  } else if (customer.customer_segment === 'medium_value') {
    return {
      offer_type: "loyalty_discount", 
      discount_percentage: 15,
      message: "Thank you for your loyalty! Enjoy 15% off your next purchase"
    };
  } else {
    return {
      offer_type: "first_time_buyer",
      discount_percentage: 10,
      message: "Welcome! Get 10% off to get started"
    };
  }
}
```

### 4. **Revenue Forecasting**

```javascript
// Predict future revenue based on customer patterns
async function predictCustomerRevenue(userId, months = 12) {
  const customer = await getCustomerRevenue(userId);
  const monthlyAverage = customer.total_revenue_cents / customer.customer_lifespan_days * 30;
  
  return {
    predicted_monthly_revenue: monthlyAverage,
    predicted_annual_revenue: monthlyAverage * 12,
    confidence_score: calculateConfidence(customer),
    factors: {
      purchase_frequency: customer.avg_days_between_purchases,
      trend: calculateTrend(customer.monthly_breakdown),
      seasonality: detectSeasonality(customer.monthly_breakdown)
    }
  };
}
```

## Advanced Analytics Queries

### 1. **Customer Cohort Revenue**

```sql
-- Revenue by customer acquisition cohort
WITH customer_cohorts AS (
  SELECT 
    user_id,
    DATE_TRUNC('month', first_purchase_date) as cohort_month
  FROM customer_revenue_analysis
),
cohort_revenue AS (
  SELECT 
    cc.cohort_month,
    COUNT(DISTINCT cc.user_id) as customers,
    SUM(cra.total_revenue_cents) / 100 as total_revenue,
    AVG(cra.total_revenue_cents) / 100 as avg_revenue_per_customer
  FROM customer_cohorts cc
  JOIN customer_revenue_analysis cra ON cc.user_id = cra.user_id
  GROUP BY cc.cohort_month
)
SELECT * FROM cohort_revenue ORDER BY cohort_month;
```

### 2. **Revenue Distribution Analysis**

```sql
-- Understand revenue distribution across customer base
SELECT 
  customer_segment,
  COUNT(*) as customer_count,
  SUM(total_revenue_cents) / 100 as total_revenue,
  AVG(total_revenue_cents) / 100 as avg_revenue_per_customer,
  ROUND(SUM(total_revenue_cents) * 100.0 / (
    SELECT SUM(total_revenue_cents) FROM customer_revenue_analysis
  ), 2) as percentage_of_total_revenue
FROM customer_revenue_analysis
GROUP BY customer_segment
ORDER BY total_revenue DESC;
```

### 3. **Purchase Frequency Analysis**

```sql
-- Analyze purchase patterns
SELECT 
  CASE 
    WHEN avg_days_between_purchases <= 30 THEN 'Monthly'
    WHEN avg_days_between_purchases <= 90 THEN 'Quarterly'
    WHEN avg_days_between_purchases <= 180 THEN 'Bi-Annual'
    ELSE 'Annual+'
  END as purchase_frequency,
  COUNT(*) as customer_count,
  AVG(total_revenue_cents) / 100 as avg_customer_value
FROM customer_revenue_analysis
WHERE avg_days_between_purchases IS NOT NULL
GROUP BY CASE 
  WHEN avg_days_between_purchases <= 30 THEN 'Monthly'
  WHEN avg_days_between_purchases <= 90 THEN 'Quarterly'
  WHEN avg_days_between_purchases <= 180 THEN 'Bi-Annual'
  ELSE 'Annual+'
END
ORDER BY avg_customer_value DESC;
```

## Dashboard Integration

### Customer Revenue Widget
```javascript
// Dashboard component for customer revenue
const CustomerRevenueWidget = {
  topCustomers: await getTopCustomers(10),
  revenueDistribution: await getRevenueDistribution(),
  atRiskCustomers: await getAtRiskCustomers(),
  monthlyTrends: await getMonthlyRevenueTrends(),
  
  metrics: {
    totalCustomers: 1250,
    avgCustomerValue: 450.75,
    topCustomerValue: 12500.00,
    customerGrowthRate: 15.2
  }
};
```

## Actionable Insights

### 1. **Customer Retention Strategies**
```javascript
const retentionStrategies = {
  high_value_at_risk: "Personal outreach, exclusive offers, dedicated support",
  medium_value_declining: "Email campaigns, loyalty rewards, product recommendations",
  low_value_new: "Onboarding sequences, educational content, first-purchase incentives"
};
```

### 2. **Upselling Opportunities**
```javascript
// Identify upselling opportunities
async function findUpsellOpportunities(userId) {
  const customer = await getCustomerRevenue(userId);
  const opportunities = [];
  
  if (customer.customer_segment === 'medium_value' && customer.total_orders > 5) {
    opportunities.push({
      type: "premium_upgrade",
      potential_revenue: 500,
      probability: 0.65
    });
  }
  
  return opportunities;
}
```

Customer Revenue Analysis gives you the detailed insights needed to maximize the value of each customer relationship and grow your business strategically.
