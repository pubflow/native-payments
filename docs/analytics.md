# Analytics System (Optional Feature)

The Native Payments Analytics System provides comprehensive insights into your payment data, revenue trends, customer behavior, and business performance. This is an **optional feature** that can be enabled to gain deep insights into your payment operations.

## Overview

The Analytics System works by:
1. **Smart Data Retrieval**: First checks if pre-calculated data exists (snapshots)
2. **On-Demand Calculation**: If no snapshot exists, calculates the data in real-time and saves it
3. **Future Speed**: Subsequent requests for the same data are lightning-fast

Think of it like a smart cache that builds itself as you use it!

## Key Features

- **Revenue Analytics**: Track daily, weekly, monthly revenue trends
- **Subscription Metrics**: Monitor MRR, churn rates, and subscription health
- **Customer Insights**: Understand customer lifetime value and behavior
- **Membership Analytics**: Track membership conversions and feature usage
- **Performance Optimization**: Automatic caching for frequently requested data
- **Real-time Flexibility**: Calculate any metric on-demand

## How It Works

### The Smart Snapshot System

When you request analytics data, the system follows this intelligent process:

```
1. API Request: "Show me revenue for December 15, 2023"
   ↓
2. Check: Does a snapshot exist for this date?
   ↓
3a. YES → Return snapshot data (⚡ Super fast - ~50ms)
   ↓
3b. NO → Calculate in real-time → Save snapshot → Return data (🔄 Slower first time - ~2-5s)
   ↓
4. Future requests for same data = ⚡ Super fast!
```

### Example Flow

```javascript
// First request (no snapshot exists)
GET /api/payment/analytics/revenue?date=2023-12-15
// Response time: ~3 seconds (calculates + saves snapshot)

// Second request (snapshot exists)
GET /api/payment/analytics/revenue?date=2023-12-15
// Response time: ~50ms (uses saved snapshot)
```

## Database Tables

The Analytics System adds these optional tables to your database:

### 1. Analytics Events (Optional)
Tracks detailed user interactions and events for advanced analytics.

```sql
CREATE TABLE analytics_events (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    session_id VARCHAR(255),
    event_type VARCHAR(50) NOT NULL, -- 'payment_completed', 'subscription_created', etc.
    event_category VARCHAR(50), -- 'revenue', 'conversion', 'engagement'
    entity_type VARCHAR(50), -- 'order', 'subscription', 'membership'
    entity_id VARCHAR(255),
    properties JSON, -- Event-specific data
    revenue_cents BIGINT DEFAULT 0,
    currency VARCHAR(3),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
```

### 2. Analytics Snapshots (Core)
Stores pre-calculated metrics for fast retrieval.

```sql
CREATE TABLE analytics_snapshots (
    id VARCHAR(255) PRIMARY KEY,
    snapshot_date DATE NOT NULL,
    metric_type VARCHAR(50) NOT NULL, -- 'daily_revenue', 'active_subscriptions', etc.
    metric_value DECIMAL(20, 2) NOT NULL,
    currency VARCHAR(3),
    breakdown JSON, -- Detailed breakdown of the metric
    calculation_method VARCHAR(50) DEFAULT 'scheduled', -- 'scheduled', 'on_demand', 'manual'
    calculation_duration_ms INTEGER, -- How long the calculation took
    data_freshness VARCHAR(50) DEFAULT 'historical', -- 'historical', 'recent', 'real_time'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_snapshot (snapshot_date, metric_type, currency)
);
```

### 3. User Cohorts (Optional)
For advanced cohort analysis and customer segmentation.

```sql
CREATE TABLE user_cohorts (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    cohort_month DATE NOT NULL, -- Month when user first made a purchase
    cohort_type VARCHAR(50) NOT NULL, -- 'first_purchase', 'first_subscription'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_cohort (user_id, cohort_type)
);
```

## API Endpoints

All analytics endpoints follow the smart snapshot pattern: they check for existing data first, then calculate if needed.

### Revenue Analytics

#### Get Daily Revenue
```
GET /api/payment/analytics/revenue
```

**Query Parameters:**
- `date` (optional): Date in YYYY-MM-DD format (default: today)
- `currency` (optional): Currency code (default: USD)
- `force_recalculate` (optional): Force recalculation even if snapshot exists (default: false)

**Example Request:**
```bash
curl "http://localhost:3000/api/payment/analytics/revenue?date=2023-12-15&currency=USD"
```

**Example Response:**
```json
{
  "success": true,
  "date": "2023-12-15",
  "currency": "USD",
  "revenue": 2450.75,
  "breakdown": {
    "transaction_count": 45,
    "unique_customers": 38,
    "avg_transaction_value": 54.46,
    "payment_methods": {
      "credit_card": 1890.25,
      "paypal": 560.50
    }
  },
  "meta": {
    "source": "snapshot", // or "calculated"
    "calculated_at": "2023-12-16T10:30:45.123Z",
    "is_real_time": false,
    "calculation_duration_ms": null // null for snapshots, number for calculated
  }
}
```

#### Get Revenue Range
```
GET /api/payment/analytics/revenue/range
```

**Query Parameters:**
- `start_date`: Start date (YYYY-MM-DD)
- `end_date`: End date (YYYY-MM-DD)
- `currency` (optional): Currency code (default: USD)

**Example Request:**
```bash
curl "http://localhost:3000/api/payment/analytics/revenue/range?start_date=2023-12-01&end_date=2023-12-15"
```

**Example Response:**
```json
{
  "success": true,
  "period": {
    "start_date": "2023-12-01",
    "end_date": "2023-12-15"
  },
  "currency": "USD",
  "summary": {
    "total_revenue": 36761.25,
    "total_transactions": 675,
    "avg_daily_revenue": 2450.75,
    "days_with_data": 15
  },
  "daily_data": [
    {
      "date": "2023-12-01",
      "revenue": 2100.50,
      "breakdown": { "transaction_count": 42 },
      "source": "snapshot"
    }
    // ... more daily data
  ],
  "meta": {
    "snapshots_used": 12,
    "calculated_on_demand": 3
  }
}
```

### Subscription Analytics

#### Get Subscription Metrics
```
GET /api/payment/analytics/subscriptions
```

**Query Parameters:**
- `date` (optional): Date for point-in-time metrics (default: today)
- `currency` (optional): Currency code (default: USD)
- `period` (optional): 'month', 'quarter', 'year' for period-based metrics

**Example Response:**
```json
{
  "success": true,
  "date": "2023-12-15",
  "currency": "USD",
  "metrics": {
    "active_subscriptions": 185,
    "mrr": 8750.00,
    "arr": 105000.00,
    "churn_rate": 4.2,
    "growth_rate": 12.5
  },
  "breakdown": {
    "by_plan": [
      {
        "product_id": "premium_monthly",
        "name": "Premium Monthly",
        "active_count": 120,
        "mrr": 6000.00
      }
    ],
    "new_this_month": 23,
    "cancelled_this_month": 8
  },
  "meta": {
    "source": "calculated",
    "calculated_at": "2023-12-16T10:30:45.123Z",
    "is_real_time": true
  }
}
```

### Customer Analytics

#### Get Customer Metrics
```
GET /api/payment/analytics/customers
```

**Query Parameters:**
- `segment` (optional): 'new', 'returning', 'high_value', 'at_risk'
- `date` (optional): Date for point-in-time metrics
- `period` (optional): Time period for analysis

**Example Response:**
```json
{
  "success": true,
  "date": "2023-12-15",
  "metrics": {
    "total_customers": 1250,
    "new_customers_this_month": 85,
    "avg_ltv": 125.50,
    "avg_order_value": 45.75,
    "repeat_purchase_rate": 68.5
  },
  "segments": [
    {
      "segment": "high_value",
      "customer_count": 125,
      "avg_ltv": 450.00,
      "contribution_to_revenue": 35.2
    }
  ]
}
```

### Membership Analytics

#### Get Membership Metrics
```
GET /api/payment/analytics/memberships
```

**Example Response:**
```json
{
  "success": true,
  "date": "2023-12-15",
  "metrics": {
    "total_active_memberships": 342,
    "new_memberships_this_month": 45,
    "conversion_rate": 12.8,
    "avg_membership_value": 89.99
  },
  "breakdown": {
    "by_type": [
      {
        "membership_type": "Premium Monthly",
        "active_count": 180,
        "revenue_contribution": 65.2
      }
    ],
    "feature_usage": {
      "hd_streaming": 89.5,
      "download": 67.3,
      "family_sharing": 34.8
    }
  }
}
```

### Individual Customer Revenue

#### Get Customer Revenue Analysis
```
GET /api/payment/analytics/customers/:userId/revenue
```

**Query Parameters:**
- `period` (optional): 'all_time', 'last_12_months', 'last_6_months', 'ytd'
- `include_predictions` (optional): true/false
- `breakdown` (optional): 'monthly', 'quarterly', 'by_product'

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
    "net_revenue_cents": 122500
  },
  "monthly_breakdown": [
    {
      "month": "2023-01",
      "revenue_cents": 15000,
      "orders": 2
    }
  ],
  "predictions": {
    "estimated_ltv_cents": 240000,
    "next_purchase_probability": 0.75,
    "churn_risk_score": 0.15
  },
  "customer_segment": "high_value"
}
```

## Smart Caching Behavior

### When Snapshots Are Created

1. **On-Demand**: When you request data that doesn't have a snapshot
2. **Scheduled**: Daily/monthly cron jobs for common metrics
3. **Manual**: Force recalculation with `force_recalculate=true`

### Cache Invalidation

- **Historical Data**: Never invalidated (data is final)
- **Recent Data**: Automatically recalculated if older than 1 hour
- **Today's Data**: Always calculated in real-time (not cached)

### Performance Examples

```javascript
// First time requesting December 15 revenue
// ⏱️ ~3 seconds (calculates + saves)
GET /api/payment/analytics/revenue?date=2023-12-15

// Second time requesting same data
// ⚡ ~50ms (uses snapshot)
GET /api/payment/analytics/revenue?date=2023-12-15

// Requesting today's revenue
// ⏱️ ~1 second (always real-time, not cached)
GET /api/payment/analytics/revenue?date=2023-12-16

// Force recalculation
// ⏱️ ~3 seconds (recalculates + updates snapshot)
GET /api/payment/analytics/revenue?date=2023-12-15&force_recalculate=true
```

## Implementation Benefits

### For Developers
- **Easy Integration**: Simple REST API endpoints
- **Flexible**: Calculate any metric on-demand
- **Transparent**: Know exactly where your data comes from
- **Debuggable**: See calculation times and data sources

### For Business
- **Fast Insights**: Get business metrics instantly
- **Cost Effective**: Only calculates what you actually need
- **Scalable**: Performance improves as you use it more
- **Reliable**: Consistent data for reporting and decision-making

### For Users
- **Responsive Dashboards**: Fast-loading analytics pages
- **Real-time Data**: Always get the most current information
- **Historical Analysis**: Access to any historical period

## Getting Started

1. **Enable Analytics**: Add the analytics tables to your database
2. **Start Querying**: Make API requests for the metrics you need
3. **Build Dashboards**: Use the API data in your frontend
4. **Optimize**: Frequently requested data becomes automatically faster

The Analytics System grows smarter and faster as you use it, making it perfect for both small applications and large-scale enterprise deployments.

## Next Steps

- [Database Schema Updates](./database-schema.md#analytics-tables)
- [API Implementation Examples](./examples/analytics-implementation.md)
- [Dashboard Integration Guide](./examples/dashboard-integration.md)
