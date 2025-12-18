# 📊 Cost Tracking Feature (Optional)

## Overview

The **Cost Tracking** feature enables you to track product costs and calculate profit margins for your orders and subscriptions. This optional feature helps you understand the profitability of your business by comparing revenue against actual costs.

## When to Use This Feature

✅ **Use Cost Tracking if you:**
- Need to track product costs (materials, labor, shipping, etc.)
- Want to calculate profit margins on orders and subscriptions
- Need profitability reports and analytics
- Track costs that change over time
- Have different cost structures (fixed, per-unit, hourly, percentage-based)

❌ **Skip this feature if you:**
- Only need basic payment processing
- Don't track product costs
- Don't need profitability analysis

---

## Database Tables

### `product_costs`
Defines base costs for products/services.

**Key Fields:**
- `product_id` - Reference to the product
- `cost_type` - Type of cost: `'fixed'`, `'per_unit'`, `'per_hour'`, `'percentage'`
- `cost_per_unit_cents` - Cost per unit (for physical products)
- `cost_per_hour_cents` - Cost per hour (for services)
- `cost_percentage` - Percentage-based cost (e.g., commissions)
- `fixed_cost_cents` - Fixed costs (e.g., setup fees)
- `overhead_percentage` - General overhead expenses
- `effective_from` / `effective_until` - Cost validity period (for historical tracking)
- `cost_category` - Category: `'production'`, `'shipping'`, `'labor'`, `'materials'`, `'overhead'`

### `order_costs`
Tracks actual costs per order/transaction.

**Key Fields:**
- `order_id` / `subscription_id` - Reference to order or subscription
- `base_cost_cents` - Base cost amount
- `overhead_cost_cents` - Overhead cost amount
- `total_cost_cents` - Total cost (base + overhead)
- `quantity` - Quantity (units, hours, etc.)
- `unit_type` - Type: `'units'`, `'hours'`, `'percentage'`
- `product_cost_id` - Reference to the product cost used
- `cost_breakdown` - JSON with detailed breakdown

### Views

#### `order_profitability`
Calculates profitability for each order.

**Fields:**
- `order_id`, `order_number`, `user_id`
- `revenue_cents` - Total order revenue
- `cost_cents` - Total order costs
- `profit_cents` - Profit (revenue - costs)
- `profit_margin_percentage` - Profit margin %

#### `subscription_profitability`
Calculates profitability for each subscription.

**Fields:**
- `subscription_id`, `user_id`, `product_id`
- `revenue_cents` - Subscription revenue
- `cost_cents` - Subscription costs
- `profit_cents` - Profit (revenue - costs)
- `profit_margin_percentage` - Profit margin %
- `billing_interval` - Billing frequency

---

## API Endpoints

### Product Costs

#### `POST /api/v1/costs/products/:product_id/costs`
Create a new cost entry for a product.

**Request Body:**
```json
{
  "cost_type": "per_unit",
  "cost_per_unit_cents": 1500,
  "overhead_percentage": 10,
  "currency": "USD",
  "effective_from": "2024-01-01T00:00:00Z",
  "cost_category": "production",
  "description": "Manufacturing cost for Product X"
}
```

#### `GET /api/v1/costs/products/:product_id/costs`
Get all cost entries for a product.

**Query Parameters:**
- `effective_date` - Get costs effective on a specific date
- `cost_category` - Filter by category

#### `GET /api/v1/costs/products/:product_id/costs/current`
Get the current active cost for a product.

### Order Costs

#### `POST /api/v1/costs/orders/:order_id/calculate`
Calculate and record costs for an order.

**Request Body:**
```json
{
  "order_items": [
    {
      "product_id": "prod_123",
      "quantity": 2
    }
  ]
}
```

**Response:**
```json
{
  "order_id": "order_456",
  "total_cost_cents": 3300,
  "breakdown": [
    {
      "product_id": "prod_123",
      "quantity": 2,
      "base_cost_cents": 3000,
      "overhead_cost_cents": 300,
      "total_cost_cents": 3300
    }
  ]
}
```

#### `GET /api/v1/costs/orders/:order_id`
Get cost details for an order.

### Reports & Analytics

#### `GET /api/v1/costs/reports/profitability`
Get profitability report.

**Query Parameters:**
- `start_date` - Start date for report
- `end_date` - End date for report
- `group_by` - Group by: `'product'`, `'category'`, `'day'`, `'month'`

**Response:**
```json
{
  "total_revenue_cents": 100000,
  "total_cost_cents": 65000,
  "total_profit_cents": 35000,
  "profit_margin_percentage": 35.0,
  "breakdown": [...]
}
```

---

## Usage Examples

### Example 1: Track Product Manufacturing Cost

```javascript
// Create a cost entry for a product
await fetch('/api/v1/costs/products/prod_123/costs', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    cost_type: 'per_unit',
    cost_per_unit_cents: 1200,  // $12.00 per unit
    overhead_percentage: 15,     // 15% overhead
    currency: 'USD',
    effective_from: '2024-01-01T00:00:00Z',
    cost_category: 'production'
  })
});
```

### Example 2: Calculate Order Costs

```javascript
// Calculate costs for an order
const response = await fetch('/api/v1/costs/orders/order_456/calculate', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    order_items: [
      { product_id: 'prod_123', quantity: 5 },
      { product_id: 'prod_789', quantity: 2 }
    ]
  })
});

const costData = await response.json();
console.log(`Total Cost: $${costData.total_cost_cents / 100}`);
```

### Example 3: Get Profitability Report

```javascript
// Get monthly profitability report
const response = await fetch('/api/v1/costs/reports/profitability?start_date=2024-01-01&end_date=2024-01-31&group_by=product');
const report = await response.json();

console.log(`Profit Margin: ${report.profit_margin_percentage}%`);
```

### Example 4: Query Profitability Views

```sql
-- Get top 10 most profitable orders
SELECT
  order_id,
  order_number,
  revenue_cents / 100.0 as revenue,
  profit_cents / 100.0 as profit,
  profit_margin_percentage
FROM order_profitability
ORDER BY profit_cents DESC
LIMIT 10;

-- Get subscription profitability by product
SELECT
  product_id,
  COUNT(*) as subscription_count,
  AVG(profit_margin_percentage) as avg_margin,
  SUM(profit_cents) / 100.0 as total_profit
FROM subscription_profitability
GROUP BY product_id
ORDER BY total_profit DESC;
```

---

## Best Practices

### 1. **Track Historical Costs**
Use `effective_from` and `effective_until` to track cost changes over time:

```javascript
// Old cost (expired)
{
  cost_per_unit_cents: 1000,
  effective_from: '2023-01-01',
  effective_until: '2023-12-31'
}

// New cost (current)
{
  cost_per_unit_cents: 1200,
  effective_from: '2024-01-01',
  effective_until: null  // Currently active
}
```

### 2. **Use Cost Categories**
Organize costs by category for better reporting:
- `production` - Manufacturing/creation costs
- `shipping` - Delivery and logistics
- `labor` - Employee time and wages
- `materials` - Raw materials and supplies
- `overhead` - General business expenses

### 3. **Include Overhead**
Always include overhead percentage to get accurate total costs:

```javascript
{
  cost_per_unit_cents: 1000,  // Direct cost
  overhead_percentage: 20      // 20% overhead = $2.00
  // Total cost per unit: $12.00
}
```

### 4. **Automate Cost Calculation**
Calculate costs automatically when orders are created:

```javascript
// In your order creation flow
async function createOrder(orderData) {
  const order = await createOrderInDatabase(orderData);

  // Automatically calculate and record costs
  await fetch(`/api/v1/costs/orders/${order.id}/calculate`, {
    method: 'POST',
    body: JSON.stringify({ order_items: orderData.items })
  });

  return order;
}
```

---

## Integration with Other Features

### With Orders
Cost tracking automatically links to orders to calculate profitability.

### With Subscriptions
Track recurring costs for subscription products to understand long-term profitability.

### With Analytics (Optional)
Combine with the Analytics feature for advanced profitability dashboards.

---

## Migration Guide

To enable this feature in your existing database:

### MySQL
```sql
SOURCE /path/to/native-payments/mysql/schema.sql;
-- Tables will be created with IF NOT EXISTS
```

### PostgreSQL
```sql
\i /path/to/native-payments/postgresql/schema.sql
-- Tables will be created with IF NOT EXISTS
```

### SQLite
```sql
.read /path/to/native-payments/sqlite/schema.sql
-- Tables will be created with IF NOT EXISTS
```

---

## Performance Considerations

- **Indexes**: All cost tables have optimized indexes for fast queries
- **Views**: Profitability views are pre-calculated for instant reporting
- **Historical Data**: Use `effective_from`/`effective_until` for time-based queries

---

## Support

For questions or issues with the Cost Tracking feature:
- Check the main [Native-Payments Documentation](../README.md)
- Review [API Routes](./api-routes.md)
- See [Use Cases](./use-cases.md) for more examples


