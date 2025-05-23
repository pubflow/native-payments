# Analytics Events - Practical Guide

Analytics Events are like a detailed diary of everything your customers do in your payment system. They help you understand the complete customer journey from first visit to final purchase.

## What are Analytics Events?

Think of Analytics Events as breadcrumbs that track every important action your customers take:

```
User visits checkout page → Event: "checkout_started"
User enters payment info → Event: "payment_info_entered"
Payment succeeds → Event: "payment_completed"
User subscribes → Event: "subscription_created"
```

## Why Track Events?

### 1. **Understand Customer Journey**
```
Where do customers drop off?
What's the conversion rate at each step?
Which payment methods work best?
```

### 2. **Optimize Conversion Funnels**
```
Checkout Started: 1000 users
Payment Info Entered: 800 users (80% conversion)
Payment Completed: 720 users (90% conversion)
→ Focus on improving the first step!
```

### 3. **Measure Feature Impact**
```
Before new checkout: 65% conversion
After new checkout: 78% conversion
→ Your improvement worked!
```

## Event Structure in Native Payments

### Database Table
```sql
CREATE TABLE analytics_events (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    session_id VARCHAR(255),
    event_type VARCHAR(50) NOT NULL,
    event_category VARCHAR(50),
    entity_type VARCHAR(50),
    entity_id VARCHAR(255),
    properties JSON,
    revenue_cents BIGINT DEFAULT 0,
    currency VARCHAR(3),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Event Example
```json
{
  "id": "evt_123456",
  "user_id": "user_789",
  "session_id": "sess_abc123",
  "event_type": "payment_completed",
  "event_category": "revenue",
  "entity_type": "order",
  "entity_id": "order_456",
  "properties": {
    "payment_method": "credit_card",
    "amount_cents": 2500,
    "currency": "USD",
    "plan_type": "premium_monthly",
    "is_first_purchase": true,
    "checkout_duration_seconds": 45
  },
  "revenue_cents": 2500,
  "currency": "USD",
  "created_at": "2023-12-15T10:30:45Z"
}
```

## Common Event Types

### 1. **Conversion Events**
```javascript
const conversionEvents = {
  "checkout_started": "User began checkout process",
  "payment_info_entered": "User entered payment details",
  "payment_method_selected": "User chose payment method",
  "payment_completed": "Payment was successful",
  "payment_failed": "Payment failed",
  "subscription_created": "New subscription started",
  "membership_purchased": "User bought membership"
};
```

### 2. **Engagement Events**
```javascript
const engagementEvents = {
  "page_viewed": "User viewed a page",
  "feature_accessed": "User used a premium feature",
  "plan_compared": "User compared pricing plans",
  "trial_started": "User started free trial",
  "support_contacted": "User contacted support"
};
```

### 3. **Revenue Events**
```javascript
const revenueEvents = {
  "purchase_completed": "One-time purchase made",
  "subscription_renewed": "Recurring payment processed",
  "upgrade_purchased": "User upgraded plan",
  "addon_purchased": "User bought add-on feature",
  "refund_processed": "Payment was refunded"
};
```

## Practical Examples

### 1. **E-commerce Funnel Tracking**

```javascript
// Track the complete purchase journey
async function trackPurchaseJourney(userId, sessionId) {
  
  // Step 1: User starts checkout
  await createEvent({
    user_id: userId,
    session_id: sessionId,
    event_type: "checkout_started",
    event_category: "conversion",
    entity_type: "cart",
    entity_id: "cart_123",
    properties: {
      cart_value_cents: 5000,
      item_count: 3,
      source: "product_page"
    }
  });
  
  // Step 2: User enters payment info
  await createEvent({
    user_id: userId,
    session_id: sessionId,
    event_type: "payment_info_entered",
    event_category: "conversion",
    properties: {
      payment_method: "credit_card",
      time_to_enter_seconds: 120
    }
  });
  
  // Step 3: Payment completed
  await createEvent({
    user_id: userId,
    session_id: sessionId,
    event_type: "payment_completed",
    event_category: "revenue",
    entity_type: "order",
    entity_id: "order_456",
    properties: {
      payment_method: "credit_card",
      total_amount_cents: 5000,
      discount_applied: false,
      checkout_duration_seconds: 180
    },
    revenue_cents: 5000,
    currency: "USD"
  });
}
```

### 2. **Subscription Lifecycle Tracking**

```javascript
// Track subscription events
const subscriptionEvents = {
  
  // New subscription
  subscription_created: {
    event_type: "subscription_created",
    event_category: "revenue",
    properties: {
      plan_id: "premium_monthly",
      plan_name: "Premium Monthly",
      price_cents: 1999,
      trial_days: 7,
      billing_cycle: "monthly"
    },
    revenue_cents: 1999
  },
  
  // Subscription renewal
  subscription_renewed: {
    event_type: "subscription_renewed",
    event_category: "revenue",
    properties: {
      plan_id: "premium_monthly",
      cycle_number: 3,
      auto_renewed: true,
      price_cents: 1999
    },
    revenue_cents: 1999
  },
  
  // Subscription cancelled
  subscription_cancelled: {
    event_type: "subscription_cancelled",
    event_category: "churn",
    properties: {
      plan_id: "premium_monthly",
      cancellation_reason: "too_expensive",
      days_active: 45,
      total_payments: 2
    },
    revenue_cents: -1999 // Negative for lost revenue
  }
};
```

### 3. **Feature Usage Tracking**

```javascript
// Track premium feature usage
async function trackFeatureUsage(userId, featureId) {
  await createEvent({
    user_id: userId,
    event_type: "feature_accessed",
    event_category: "engagement",
    entity_type: "feature",
    entity_id: featureId,
    properties: {
      feature_name: "HD Streaming",
      user_plan: "premium_monthly",
      access_granted: true,
      usage_count_this_month: 15
    }
  });
}
```

## Analytics Queries

### 1. **Conversion Funnel Analysis**

```sql
-- Calculate conversion rates through the funnel
WITH funnel_steps AS (
  SELECT 
    event_type,
    COUNT(DISTINCT user_id) as users,
    COUNT(DISTINCT session_id) as sessions
  FROM analytics_events 
  WHERE event_type IN ('checkout_started', 'payment_info_entered', 'payment_completed')
  AND created_at >= '2023-12-01'
  GROUP BY event_type
)
SELECT 
  event_type,
  users,
  LAG(users) OVER (ORDER BY 
    CASE event_type 
      WHEN 'checkout_started' THEN 1
      WHEN 'payment_info_entered' THEN 2  
      WHEN 'payment_completed' THEN 3
    END
  ) as previous_step_users,
  ROUND(users * 100.0 / LAG(users) OVER (ORDER BY 
    CASE event_type 
      WHEN 'checkout_started' THEN 1
      WHEN 'payment_info_entered' THEN 2
      WHEN 'payment_completed' THEN 3
    END
  ), 2) as conversion_rate
FROM funnel_steps;
```

**Result:**
```
checkout_started      | 1000 |      null | null
payment_info_entered  |  800 |      1000 | 80.00%
payment_completed     |  720 |       800 | 90.00%
```

### 2. **Revenue Attribution**

```sql
-- Track revenue by event source
SELECT 
  JSON_EXTRACT(properties, '$.source') as traffic_source,
  COUNT(*) as conversions,
  SUM(revenue_cents) / 100 as total_revenue,
  AVG(revenue_cents) / 100 as avg_order_value
FROM analytics_events 
WHERE event_type = 'payment_completed'
AND created_at >= '2023-12-01'
GROUP BY JSON_EXTRACT(properties, '$.source')
ORDER BY total_revenue DESC;
```

**Result:**
```
google_ads    | 150 | $15,750 | $105.00
organic       | 200 | $18,400 | $92.00
facebook_ads  | 100 | $12,500 | $125.00
```

### 3. **Feature Impact Analysis**

```sql
-- Measure feature usage impact on retention
WITH feature_users AS (
  SELECT DISTINCT user_id
  FROM analytics_events 
  WHERE event_type = 'feature_accessed'
  AND JSON_EXTRACT(properties, '$.feature_name') = 'HD Streaming'
),
retention_comparison AS (
  SELECT 
    CASE WHEN fu.user_id IS NOT NULL THEN 'Used Feature' ELSE 'No Feature' END as user_type,
    COUNT(DISTINCT ae.user_id) as users_with_activity
  FROM analytics_events ae
  LEFT JOIN feature_users fu ON ae.user_id = fu.user_id
  WHERE ae.event_type = 'subscription_renewed'
  AND ae.created_at >= '2023-12-01'
  GROUP BY CASE WHEN fu.user_id IS NOT NULL THEN 'Used Feature' ELSE 'No Feature' END
)
SELECT * FROM retention_comparison;
```

## API Endpoints for Events

### 1. **Create Event**
```
POST /api/payment/analytics/events
```

**Request:**
```json
{
  "user_id": "user_123",
  "session_id": "sess_abc",
  "event_type": "payment_completed",
  "event_category": "revenue",
  "entity_type": "order",
  "entity_id": "order_456",
  "properties": {
    "payment_method": "credit_card",
    "amount_cents": 2500
  },
  "revenue_cents": 2500,
  "currency": "USD"
}
```

### 2. **Query Events**
```
GET /api/payment/analytics/events
```

**Query Parameters:**
- `user_id`: Filter by user
- `event_type`: Filter by event type
- `start_date`: Start date
- `end_date`: End date
- `limit`: Number of results

### 3. **Funnel Analysis**
```
GET /api/payment/analytics/funnel
```

**Query Parameters:**
- `events`: Comma-separated list of events
- `start_date`: Analysis start date
- `end_date`: Analysis end date

**Response:**
```json
{
  "funnel_steps": [
    {
      "event_type": "checkout_started",
      "users": 1000,
      "conversion_rate": 100.0
    },
    {
      "event_type": "payment_completed", 
      "users": 720,
      "conversion_rate": 72.0
    }
  ],
  "overall_conversion": 72.0
}
```

## Best Practices

### 1. **Event Naming Convention**
```javascript
// Use clear, consistent naming
const goodEventNames = {
  "payment_completed": "✅ Clear action",
  "subscription_created": "✅ Clear action", 
  "feature_accessed": "✅ Clear action"
};

const badEventNames = {
  "click": "❌ Too vague",
  "user_action": "❌ Not specific",
  "event_123": "❌ Not descriptive"
};
```

### 2. **Consistent Properties**
```javascript
// Always include these properties when relevant
const standardProperties = {
  payment_method: "credit_card",
  amount_cents: 2500,
  currency: "USD",
  plan_type: "premium_monthly",
  is_first_purchase: true,
  user_segment: "high_value"
};
```

### 3. **Revenue Attribution**
```javascript
// Always include revenue for revenue events
const revenueEvent = {
  event_type: "payment_completed",
  revenue_cents: 2500, // Always in cents
  currency: "USD",
  properties: {
    // Additional context
  }
};
```

## Common Use Cases

### 1. **A/B Testing**
Track which version performs better:
```javascript
await createEvent({
  event_type: "checkout_completed",
  properties: {
    ab_test_variant: "new_checkout_v2",
    conversion_time_seconds: 45
  }
});
```

### 2. **Customer Segmentation**
Identify high-value customers:
```javascript
await createEvent({
  event_type: "high_value_purchase",
  properties: {
    customer_segment: "enterprise",
    purchase_value_cents: 50000,
    is_repeat_customer: true
  }
});
```

### 3. **Performance Monitoring**
Track system performance impact:
```javascript
await createEvent({
  event_type: "payment_processed",
  properties: {
    processing_time_ms: 1200,
    payment_provider: "stripe",
    success: true
  }
});
```

Analytics Events give you the detailed insights needed to optimize every step of your customer journey and maximize revenue growth.
