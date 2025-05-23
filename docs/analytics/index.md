# Analytics Documentation

Welcome to the Native Payments Analytics system! This comprehensive analytics suite helps you understand your customers, optimize your revenue, and make data-driven decisions.

## Overview

The Native Payments Analytics system provides three powerful tools:

1. **Smart Snapshots** - Pre-calculated metrics for lightning-fast dashboards
2. **Event Tracking** - Detailed customer journey analysis
3. **Customer Insights** - Individual customer revenue and behavior analysis

## Getting Started

### Quick Setup
1. Add the analytics tables to your database (optional feature)
2. Start making API requests for the metrics you need
3. The system automatically creates snapshots for faster future requests
4. Build dashboards using the fast-loading analytics data

### Core Concept: Smart Caching
```
First Request: Calculate + Save Snapshot (3 seconds)
Future Requests: Use Snapshot (50ms)
```

## Analytics Features

### 📊 [Cohort Analysis](./cohort-analysis.md)
Understand customer behavior by grouping them into "generations" based on when they first purchased.

**What you'll learn:**
- Which months brought the best customers
- How customer retention changes over time
- Impact of product changes on customer loyalty
- Seasonal patterns in customer behavior

**Key Metrics:**
- Month 1 retention rates
- Customer lifetime value by cohort
- Revenue trends by acquisition period

**Example Use Case:**
```
January Cohort: 85% retention after 3 months
March Cohort: 65% retention after 3 months
→ Something changed between January and March that hurt retention
```

### 📈 [Analytics Events](./analytics-events.md)
Track every important action your customers take to understand the complete customer journey.

**What you'll learn:**
- Where customers drop off in your funnel
- Which features drive the most engagement
- How different traffic sources convert
- Impact of A/B tests and product changes

**Key Events:**
- `checkout_started` → `payment_completed`
- `trial_started` → `subscription_created`
- `feature_accessed` → `upgrade_purchased`

**Example Use Case:**
```
Checkout Started: 1000 users
Payment Completed: 720 users
→ 72% conversion rate, focus on improving checkout flow
```

### 💰 [Customer Revenue Analysis](./customer-revenue-analysis.md)
Deep dive into individual customer value and identify your most important customers.

**What you'll learn:**
- Who are your highest-value customers
- Which customers are at risk of churning
- Lifetime value predictions
- Personalization opportunities

**Key Insights:**
- Total revenue per customer
- Purchase frequency patterns
- Customer segment classification
- Churn risk scoring

**Example Use Case:**
```
Customer #123: $2,500 total value, purchases every 2 months
→ VIP treatment, dedicated support, exclusive offers
```

## API Endpoints Overview

### Revenue Analytics
```
GET /api/payment/analytics/revenue
GET /api/payment/analytics/revenue/range
```
Track daily, weekly, monthly revenue with automatic caching.

### Subscription Metrics
```
GET /api/payment/analytics/subscriptions
```
Monitor MRR, churn rates, and subscription health.

### Customer Analytics
```
GET /api/payment/analytics/customers
GET /api/payment/analytics/customers/:userId/revenue
```
Understand customer behavior and individual value.

### Cohort Analysis
```
GET /api/payment/analytics/cohorts
```
Analyze customer retention by acquisition period.

### Event Tracking
```
POST /api/payment/analytics/events
GET /api/payment/analytics/events
GET /api/payment/analytics/funnel
```
Track customer journey and conversion funnels.

## Common Use Cases

### 1. **Executive Dashboard**
```javascript
const dashboardData = {
  yesterdayRevenue: await getRevenue('2023-12-14'),     // Uses snapshot (fast)
  monthlyMRR: await getSubscriptionMetrics(),          // Uses snapshot (fast)
  topCustomers: await getTopCustomers(10),             // Uses view (fast)
  conversionFunnel: await getFunnelAnalysis()          // Uses events (fast)
};
// Total load time: ~2 seconds instead of 30+ seconds
```

### 2. **Marketing Campaign Analysis**
```javascript
// Compare before/after campaign performance
const beforeCampaign = await getCohortRetention('2023-01');
const afterCampaign = await getCohortRetention('2023-03');

if (afterCampaign.retention > beforeCampaign.retention) {
  console.log('Campaign improved customer quality!');
}
```

### 3. **Customer Success Automation**
```javascript
// Identify at-risk high-value customers
const atRiskCustomers = await getCustomers({
  segment: 'high_value',
  activity_status: 'at_risk'
});

// Trigger retention campaigns
atRiskCustomers.forEach(customer => {
  sendRetentionEmail(customer.id);
});
```

### 4. **Product Optimization**
```javascript
// Track feature usage impact
const featureUsers = await getEventUsers('feature_accessed', 'hd_streaming');
const retentionRate = await getCohortRetention(featureUsers);

if (retentionRate > averageRetention) {
  console.log('HD Streaming improves retention!');
}
```

## Performance Benefits

### Without Analytics System
```
Dashboard Load Time: 30-60 seconds
Database Load: High (complex queries every time)
User Experience: Slow, frustrating
Scalability: Poor (gets slower with more data)
```

### With Analytics System
```
Dashboard Load Time: 2-5 seconds
Database Load: Low (uses pre-calculated snapshots)
User Experience: Fast, responsive
Scalability: Excellent (performance improves over time)
```

## Data Freshness

### Historical Data (Snapshots)
- **Speed**: ⚡ Lightning fast (50ms)
- **Accuracy**: 🎯 Exact (never changes)
- **Use Case**: Reports, trends, historical analysis

### Recent Data (Real-time)
- **Speed**: 🔄 Moderate (1-3 seconds)
- **Accuracy**: 📊 Current (always up-to-date)
- **Use Case**: Today's metrics, live monitoring

### Smart Refresh
- **Historical**: Never recalculated (data is final)
- **Recent**: Auto-refresh if older than 1 hour
- **Today**: Always calculated real-time

## Implementation Examples

### 1. **React Dashboard Component**
```jsx
function AnalyticsDashboard() {
  const [metrics, setMetrics] = useState({});
  
  useEffect(() => {
    async function loadMetrics() {
      const [revenue, cohorts, customers] = await Promise.all([
        fetch('/api/payment/analytics/revenue?date=yesterday'),
        fetch('/api/payment/analytics/cohorts?start_cohort=2023-01'),
        fetch('/api/payment/analytics/customers?segment=high_value')
      ]);
      
      setMetrics({ revenue, cohorts, customers });
    }
    
    loadMetrics();
  }, []);
  
  return (
    <div>
      <RevenueChart data={metrics.revenue} />
      <CohortTable data={metrics.cohorts} />
      <CustomerList data={metrics.customers} />
    </div>
  );
}
```

### 2. **Automated Reporting**
```javascript
// Daily automated report
async function generateDailyReport() {
  const yesterday = getYesterday();
  
  const report = {
    revenue: await getRevenue(yesterday),
    newCustomers: await getNewCustomers(yesterday),
    churnedCustomers: await getChurnedCustomers(yesterday),
    topPerformingCohort: await getBestCohort()
  };
  
  await sendReportEmail(report);
}

// Run daily at 9 AM
cron.schedule('0 9 * * *', generateDailyReport);
```

### 3. **Real-time Alerts**
```javascript
// Monitor key metrics and alert on anomalies
async function checkMetricAlerts() {
  const todayRevenue = await getRevenue('today');
  const averageRevenue = await getAverageRevenue(30); // Last 30 days
  
  if (todayRevenue < averageRevenue * 0.7) {
    await sendAlert({
      type: 'revenue_drop',
      message: `Revenue is 30% below average: $${todayRevenue} vs $${averageRevenue}`,
      severity: 'high'
    });
  }
}
```

## Best Practices

### 1. **Start Simple**
- Begin with basic revenue and customer metrics
- Add more complex analytics as you grow
- Focus on actionable insights over vanity metrics

### 2. **Use the Right Tool**
- **Snapshots**: For historical data and trends
- **Events**: For funnel analysis and user journey
- **Customer Analysis**: For personalization and retention

### 3. **Monitor Performance**
- Check which metrics are requested most often
- Those will automatically become faster over time
- Use `force_recalculate=true` sparingly

### 4. **Automate Insights**
- Set up alerts for important metric changes
- Generate automated reports for stakeholders
- Use analytics to trigger customer success actions

## Next Steps

1. **Choose Your Analytics**: Start with the analytics that matter most to your business
2. **Implement Tracking**: Add event tracking to understand customer behavior
3. **Build Dashboards**: Create fast-loading dashboards using the analytics APIs
4. **Optimize**: Use insights to improve your product and customer experience
5. **Scale**: The system gets smarter and faster as you use it more

The Native Payments Analytics system grows with your business, providing the insights you need to make data-driven decisions and maximize revenue growth.
