# 🎯 Optional Features Overview

This document provides an overview of all optional features available in Native-Payments. These features are modular and can be implemented independently based on your needs.

---

## 📊 1. Cost Tracking

**Track product costs and calculate profit margins**

### What it does:
- Track product costs (materials, labor, shipping, overhead)
- Calculate actual costs per order/subscription
- Generate profitability reports
- Support multiple cost types (fixed, per-unit, hourly, percentage)
- Historical cost tracking with effective dates

### When to use:
✅ Need to track product costs and profit margins  
✅ Want profitability analytics  
✅ Have costs that change over time  
✅ Need to understand business profitability  

### Documentation:
📖 [Cost Tracking Guide](./cost-tracking.md)

### Tables:
- `product_costs` - Define base costs for products
- `order_costs` - Track actual costs per transaction
- `order_profitability` (view) - Order profitability analysis
- `subscription_profitability` (view) - Subscription profitability analysis

### Example Use Case:
```javascript
// Track manufacturing cost
await createProductCost({
  product_id: 'prod_123',
  cost_per_unit_cents: 1200,  // $12 per unit
  overhead_percentage: 15,     // 15% overhead
  cost_category: 'production'
});

// Calculate order profitability
const profitability = await getOrderProfitability('order_456');
// Returns: { revenue_cents: 5000, cost_cents: 3300, profit_margin_percentage: 34 }
```

---

## 💰 2. Account Balance

**Customer wallets, credits, and prepayment systems**

### What it does:
- Customer wallet/credit systems
- Multiple balance types per customer (main wallet, promo credits, refunds)
- Promotional credits with expiration
- Prepaid subscriptions
- Complete transaction history
- Mixed payments (balance + payment method)

### When to use:
✅ Need customer wallet functionality  
✅ Want to offer promotional credits  
✅ Handle refunds as account credits  
✅ Offer prepaid services  
✅ Need multiple balance types per customer  

### Documentation:
📖 [Account Balance Guide](./account-balance.md)

### Tables:
- `account_balances` - Track customer balances
- `account_transactions` - Record all balance movements

### Example Use Case:
```javascript
// Create customer wallet
await createBalance({
  user_id: 'user_123',
  reference_code: 'main_wallet',
  balance_type: 'general'
});

// Add promotional credits
await createBalance({
  user_id: 'user_123',
  reference_code: 'promo_credits',
  balance_type: 'promotional',
  initial_balance_cents: 1000,
  expires_at: '2024-12-31'
});

// Pay with wallet
await payWithBalance({
  user_id: 'user_123',
  amount_cents: 2000,
  balance_reference_code: 'main_wallet'
});
```

---

## 📅 3. Billing Schedules

**Automated recurring billing with flexible payment sources**

### What it does:
- Automated recurring charges
- Flexible payment sources (balance first, then card)
- Installment plans
- Custom billing intervals (daily, weekly, monthly, yearly)
- Retry logic for failed payments
- Execution history tracking
- Pre-charge notifications

### When to use:
✅ Need automated recurring billing  
✅ Want flexible payment sources  
✅ Offer installment plans  
✅ Charge recurring fees  
✅ Need custom billing intervals  

### Documentation:
📖 [Billing Schedules Guide](./billing-schedules.md)

### Tables:
- `billing_schedules` - Configure recurring charges
- `billing_schedule_executions` - Track execution history

### Example Use Case:
```javascript
// Monthly membership with balance-first payment
await createBillingSchedule({
  user_id: 'user_123',
  schedule_type: 'recurring',
  amount_cents: 999,
  billing_interval: 'monthly',
  payment_priority: 'balance_first',  // Try wallet first
  account_balance_id: 'bal_123',
  payment_method_id: 'pm_456',        // Fallback to card
  notify_before_days: 3
});

// 6-month installment plan
await createBillingSchedule({
  amount_cents: 5000,
  billing_interval: 'monthly',
  start_date: '2024-01-01',
  end_date: '2024-06-01',
  category: 'installment'
});
```

---

## 🧾 4. Invoices & Receipts

**Universal billing system with pre-payment invoices and post-payment receipts**

### What it does:
- Pre-payment invoices with payment links
- Post-payment receipts (proof of payment)
- Guest invoice/receipt support
- Detailed line items and breakdowns
- PDF generation support
- Invoice status tracking (draft, sent, paid, overdue)
- Automatic receipt generation after payment

### When to use:
✅ Need to send invoices before payment  
✅ Want to generate receipts after payment  
✅ Handle guest payments with billing documents  
✅ Need professional billing documents  
✅ Track invoice status  

### Documentation:
📖 [Invoices & Receipts Guide](./invoices-receipts.md)

### Tables:
- `invoices` (already exists in core) - Pre-payment documents
- `receipts` (new) - Post-payment proof

### Example Use Case:
```javascript
// Create and send invoice
const invoice = await createInvoice({
  user_id: 'user_123',
  line_items: [
    { description: 'Web Development', quantity: 10, unit_price_cents: 5000 }
  ],
  total_cents: 54000,
  due_date: '2024-02-15'
});

await sendInvoice(invoice.id);
// Customer receives email with payment link

// After payment, automatically create receipt
await createReceipt({
  payment_id: 'pay_456',
  invoice_id: invoice.id,
  customer_name: 'John Doe',
  customer_email: 'john@example.com'
});
```

---

## 🔗 Feature Integration

These features work together seamlessly:

### Account Balance + Billing Schedules
Use account balances as payment source for recurring billing with card fallback.

### Billing Schedules + Invoices & Receipts
Automatically create invoices before charges and receipts after successful payments.

### Cost Tracking + All Features
Track costs for any transaction type (orders, subscriptions, invoices).

### All Features + Analytics (Optional)
Combine with Analytics feature for comprehensive business intelligence.

---

## 🚀 Getting Started

### 1. Choose Your Features
Review each feature guide and decide which ones you need.

### 2. Run Migrations
All features are included in the schema files with `IF NOT EXISTS`:

```sql
-- MySQL
SOURCE /path/to/native-payments/mysql/schema.sql;

-- PostgreSQL
\i /path/to/native-payments/postgresql/schema.sql;

-- SQLite
.read /path/to/native-payments/sqlite/schema.sql;
```

### 3. Implement API Endpoints
Refer to individual feature guides for API endpoint specifications.

### 4. Test Your Implementation
Use the examples in each guide to test your implementation.

---

## 📚 Additional Resources

- [Main Documentation](../README.md)
- [Database Schema](./database-schema.md)
- [API Routes](./api-routes.md)
- [Use Cases](./use-cases.md)

---

## ✅ Feature Comparison

| Feature | Tables | Views | Complexity | Dependencies |
|---------|--------|-------|------------|--------------|
| Cost Tracking | 2 | 2 | Low | None |
| Account Balance | 2 | 0 | Medium | None |
| Billing Schedules | 2 | 0 | High | Account Balance (optional) |
| Invoices & Receipts | 1* | 0 | Low | None |

*Invoices table already exists in core schema, only receipts table is added.

---

## 🎯 Quick Decision Guide

**I need to...**

- Track profit margins → **Cost Tracking**
- Offer customer wallets → **Account Balance**
- Automate recurring charges → **Billing Schedules**
- Send invoices and receipts → **Invoices & Receipts**
- All of the above → **Implement all 4 features!**

---

**Questions?** Check the individual feature guides or the main documentation.
