# Use Cases - Which Tables Do You Actually Need?

Native Payments includes many tables, but you don't need all of them! This guide helps you choose exactly what you need based on your business model.

## Quick Decision Tree

```
What's your business model?
├── 🛒 Simple E-commerce → Use: Core + Orders
├── 💳 Payment Processing Only → Use: Core + Payments
├── 🔄 SaaS/Subscriptions → Use: Core + Subscriptions + Invoices
├── 🎯 Membership Site → Use: Core + Memberships
├── 🏢 Marketplace → Use: Core + Organizations + Orders
└── 📊 Need Analytics? → Add: Analytics Tables
```

## Business Model Guides

### 🛒 **Simple E-commerce Store**

**Perfect for:** Online stores, digital downloads, physical products

**Tables you need:**
```sql
-- Core tables (required)
✅ users
✅ addresses
✅ payment_providers
✅ payment_methods
✅ products
✅ orders
✅ order_items
✅ payments

-- Optional but recommended
⚪ product_categories (if you have many products)
⚪ invoices (for receipts and accounting)
```

**What you DON'T need:**
```sql
❌ organizations (unless B2B)
❌ subscriptions (no recurring billing)
❌ membership_types (no memberships)
❌ user_memberships (no memberships)
❌ analytics_* (unless you want insights)
```

**Example flow:**
```
1. Customer browses products
2. Adds items to cart → order + order_items
3. Enters payment info → payment_methods (optional)
4. Completes purchase → payments
5. Gets receipt → invoices (optional)
```

**API endpoints you'll use:**
```
POST /api/payment/orders          # Create order
POST /api/payment/orders/:id/pay  # Process payment
GET  /api/payment/orders/:id      # Order status
```

---

### 💳 **Payment Processing Only**

**Perfect for:** Service businesses, consultants, simple payment collection

**Tables you need:**
```sql
-- Minimal setup
✅ users
✅ payment_providers
✅ payment_methods (optional)
✅ payments

-- Optional
⚪ addresses (for billing)
⚪ invoices (for records)
```

**What you DON'T need:**
```sql
❌ products (no product catalog)
❌ orders/order_items (no shopping cart)
❌ subscriptions (no recurring billing)
❌ memberships (no access control)
❌ organizations (unless B2B)
```

**Example flow:**
```
1. Customer needs to pay $500 for consulting
2. You create a payment intent
3. Customer pays → payments
4. You get notified → payment_webhooks
```

**API endpoints you'll use:**
```
POST /api/payment/intents         # Create payment intent
POST /api/payment/payments        # Process payment
GET  /api/payment/payments/:id    # Payment status
```

---

### 🔄 **SaaS/Subscription Business**

**Perfect for:** Software subscriptions, recurring services, membership sites

**Tables you need:**
```sql
-- Core subscription setup
✅ users
✅ payment_providers
✅ payment_methods
✅ products (your plans)
✅ subscriptions
✅ payments
✅ invoices

-- Optional but recommended
⚪ addresses (for billing)
⚪ organizations (for team accounts)
⚪ membership_types + user_memberships (for feature access)
```

**What you DON'T need:**
```sql
❌ orders/order_items (no shopping cart)
❌ product_categories (usually few plans)
```

**Example flow:**
```
1. Customer signs up for "Premium Plan"
2. Creates subscription → subscriptions
3. Monthly billing → payments + invoices
4. Access premium features → user_memberships
5. Cancels subscription → subscriptions.status = 'cancelled'
```

**API endpoints you'll use:**
```
POST /api/payment/subscriptions           # Create subscription
GET  /api/payment/subscriptions/:id       # Subscription status
POST /api/payment/subscriptions/:id/cancel # Cancel subscription
GET  /api/payment/invoices                # Billing history
```

---

### 🎯 **Membership/Course Site**

**Perfect for:** Online courses, premium content, feature-gated apps

**Tables you need:**
```sql
-- Membership-focused setup
✅ users
✅ payment_providers
✅ payment_methods
✅ membership_types
✅ user_memberships
✅ payments

-- For one-time purchases
⚪ orders + order_items (course purchases)

-- For recurring memberships
⚪ subscriptions (monthly memberships)
⚪ invoices (billing records)
```

**Example flow:**
```
1. User wants "Premium Membership"
2. Purchases membership → orders → payments
3. Gets access → user_memberships
4. Accesses premium features → check membership status
5. Membership expires → user_memberships.status = 'expired'
```

**API endpoints you'll use:**
```
POST /api/payment/users/:id/memberships   # Grant membership
GET  /api/payment/access/verify           # Check feature access
GET  /api/payment/membership-types        # Available memberships
```

---

### 🏢 **B2B/Marketplace**

**Perfect for:** Team accounts, multi-tenant SaaS, marketplaces

**Tables you need:**
```sql
-- Multi-organization setup
✅ users
✅ organizations
✅ organization_users
✅ payment_providers
✅ payment_methods
✅ orders/subscriptions (depending on model)
✅ payments
✅ invoices

-- Optional
⚪ addresses (company addresses)
⚪ memberships (organization-level features)
```

**Example flow:**
```
1. Company "Acme Corp" signs up
2. Creates organization → organizations
3. Adds team members → organization_users
4. Subscribes to "Team Plan" → subscriptions
5. Company gets billed → invoices
```

---

## 📊 **Analytics Add-on (Optional)**

**When to add analytics:**
- You want to understand customer behavior
- You need business intelligence dashboards
- You want to optimize conversion rates
- You need cohort analysis and retention metrics

**Analytics tables:**
```sql
-- Core analytics (recommended)
✅ analytics_snapshots  # Fast dashboard data

-- Advanced analytics (optional)
⚪ analytics_events     # Detailed user tracking
⚪ user_cohorts        # Retention analysis
```

**What analytics give you:**
```
📈 Revenue trends and forecasting
👥 Customer retention analysis  
🎯 Conversion funnel optimization
💰 Individual customer value
🔍 Churn prediction and prevention
```

**Performance benefit:**
```
Without analytics: Dashboard loads in 30+ seconds
With analytics: Dashboard loads in 2-3 seconds
```

---

## Implementation Recommendations

### 🚀 **Start Small, Grow Smart**

**Phase 1: MVP (Minimum Viable Product)**
```sql
-- Start with just these tables
users
payment_providers  
payment_methods
payments
-- Plus your business model tables (orders OR subscriptions)
```

**Phase 2: Growth**
```sql
-- Add when you need them
addresses (better UX)
invoices (accounting)
product_categories (organization)
```

**Phase 3: Scale**
```sql
-- Add when you're ready to optimize
analytics_snapshots (fast dashboards)
organizations (B2B expansion)
membership_types (feature gating)
```

### 🎯 **Common Combinations**

**E-commerce Starter Pack:**
```sql
users + addresses + payment_providers + payment_methods + 
products + orders + order_items + payments
```

**SaaS Starter Pack:**
```sql
users + payment_providers + payment_methods + products + 
subscriptions + payments + invoices
```

**Membership Starter Pack:**
```sql
users + payment_providers + payment_methods + membership_types + 
user_memberships + orders + payments
```

**Analytics Add-on:**
```sql
+ analytics_snapshots (always recommended)
+ analytics_events (if you want detailed tracking)
+ user_cohorts (if you want retention analysis)
```

### 🛠 **Database Setup Examples**

**For E-commerce:**
```bash
# Run only these schema sections
mysql < users.sql
mysql < addresses.sql  
mysql < payment_providers.sql
mysql < payment_methods.sql
mysql < products.sql
mysql < orders.sql
mysql < payments.sql
```

**For SaaS:**
```bash
# Run these schema sections
mysql < users.sql
mysql < payment_providers.sql
mysql < payment_methods.sql
mysql < products.sql
mysql < subscriptions.sql
mysql < payments.sql
mysql < invoices.sql
```

**Add Analytics Later:**
```bash
# Add when you're ready
mysql < analytics_snapshots.sql
mysql < analytics_events.sql    # optional
mysql < user_cohorts.sql       # optional
```

---

## 🎯 **Optional Features Use Cases**

The following features are optional and can be added independently based on your business needs.

### 📊 **Cost Tracking**

**Perfect for:** E-commerce, manufacturing, service businesses that need profit analysis

**When to use:**
- ✅ You need to track product costs and profit margins
- ✅ You want profitability analytics
- ✅ You have costs that change over time
- ✅ You need to understand business profitability

**Tables you need:**
```sql
✅ product_costs
✅ order_costs
✅ order_profitability (view)
✅ subscription_profitability (view)
```

**Example use cases:**

**1. E-commerce Store with Cost Tracking:**
```javascript
// Track manufacturing cost
await createProductCost({
  product_id: 'prod_tshirt',
  cost_per_unit_cents: 800,  // $8 per shirt
  overhead_percentage: 20,    // 20% overhead
  cost_category: 'production'
});

// Calculate profit for order
const profit = await getOrderProfitability('order_123');
// Returns: { revenue: $25, cost: $16, profit: $9, margin: 36% }
```

**2. Service Business with Hourly Costs:**
```javascript
// Track consultant hourly cost
await createProductCost({
  product_id: 'service_consulting',
  cost_per_hour_cents: 5000,  // $50/hour cost
  cost_category: 'labor'
});
```

**3. Profitability Reports:**
```javascript
// Get monthly profitability
const report = await getProfitabilityReport({
  start_date: '2024-01-01',
  end_date: '2024-01-31'
});
// Returns: total revenue, costs, profit, and margin
```

**Full Documentation:** [Cost Tracking Guide](./cost-tracking.md)

---

### 💰 **Account Balance**

**Perfect for:** Platforms with wallets, promotional credits, prepaid services

**When to use:**
- ✅ You need customer wallet functionality
- ✅ You want to offer promotional credits
- ✅ You handle refunds as account credits
- ✅ You offer prepaid services
- ✅ You need multiple balance types per customer

**Tables you need:**
```sql
✅ account_balances
✅ account_transactions
```

**Example use cases:**

**1. Customer Wallet System:**
```javascript
// Create main wallet
await createBalance({
  user_id: 'user_123',
  reference_code: 'main_wallet',
  balance_type: 'general'
});

// Customer adds $50 to wallet
await creditBalance('bal_123', {
  amount_cents: 5000,
  description: 'Wallet top-up'
});

// Pay with wallet
await payWithBalance({
  user_id: 'user_123',
  balance_reference_code: 'main_wallet',
  amount_cents: 2000
});
```

**2. Promotional Credits:**
```javascript
// Give $10 promo credit (expires in 30 days)
await createBalance({
  user_id: 'user_123',
  reference_code: 'promo_credits',
  balance_type: 'promotional',
  initial_balance_cents: 1000,
  expires_at: '2024-02-15'
});
```

**3. Refund Management:**
```javascript
// Issue refund to account balance
await createBalance({
  user_id: 'user_123',
  reference_code: 'refund_balance',
  balance_type: 'refund',
  initial_balance_cents: 3000
});
```

**4. Mixed Payments (Balance + Card):**
```javascript
// Pay $50 total: $20 from wallet, $30 from card
await mixedPayment({
  user_id: 'user_123',
  total_amount_cents: 5000,
  balance_amount_cents: 2000,
  balance_reference_code: 'main_wallet',
  payment_method_id: 'pm_123'
});
```

**Full Documentation:** [Account Balance Guide](./account-balance.md)

---

### 📅 **Billing Schedules**

**Perfect for:** Automated recurring billing, installment plans, subscription services

**When to use:**
- ✅ You need automated recurring billing
- ✅ You want flexible payment sources (balance first, then card)
- ✅ You offer installment plans
- ✅ You charge recurring fees
- ✅ You need custom billing intervals

**Tables you need:**
```sql
✅ billing_schedules
✅ billing_schedule_executions
```

**Example use cases:**

**1. Monthly Membership with Balance-First Payment:**
```javascript
// Charge $9.99/month, try wallet first, then card
await createBillingSchedule({
  user_id: 'user_123',
  schedule_type: 'recurring',
  amount_cents: 999,
  billing_interval: 'monthly',
  payment_priority: 'balance_first',
  account_balance_id: 'bal_123',
  payment_method_id: 'pm_456',
  description: 'Premium Membership'
});
```

**2. 6-Month Installment Plan:**
```javascript
// $300 total, paid in 6 monthly installments of $50
await createBillingSchedule({
  user_id: 'user_123',
  amount_cents: 5000,
  billing_interval: 'monthly',
  start_date: '2024-01-01',
  end_date: '2024-06-01',
  category: 'installment',
  description: 'Course payment plan'
});
```

**3. Quarterly Subscription:**
```javascript
// Charge every 3 months
await createBillingSchedule({
  user_id: 'user_123',
  amount_cents: 2999,
  billing_interval: 'monthly',
  interval_multiplier: 3,  // Every 3 months
  description: 'Quarterly subscription'
});
```

**4. Cron Job Processing:**
```javascript
// Run this daily via cron
await processDueBillingSchedules();
// Automatically charges all schedules that are due
```

**Full Documentation:** [Billing Schedules Guide](./billing-schedules.md)

---

### 🧾 **Invoices & Receipts**

**Perfect for:** B2B businesses, service providers, professional billing

**When to use:**
- ✅ You need to send invoices before payment
- ✅ You want to generate receipts after payment
- ✅ You handle guest payments with billing documents
- ✅ You need professional billing documents
- ✅ You track invoice status (paid, unpaid, overdue)

**Tables you need:**
```sql
✅ invoices (already exists in core)
✅ receipts (new)
```

**Example use cases:**

**1. Service Invoice with Payment Link:**
```javascript
// Create invoice for consulting services
const invoice = await createInvoice({
  user_id: 'user_123',
  line_items: [
    {
      description: 'Web Development - 10 hours',
      quantity: 10,
      unit_price_cents: 5000,
      total_cents: 50000
    }
  ],
  subtotal_cents: 50000,
  tax_cents: 4000,
  total_cents: 54000,
  due_date: '2024-02-15'
});

// Send invoice to customer
await sendInvoice(invoice.id);
// Customer receives email with payment link
```

**2. Automatic Receipt Generation:**
```javascript
// After payment succeeds, create receipt
await createReceipt({
  payment_id: 'pay_456',
  invoice_id: 'inv_123',
  user_id: 'user_123',
  customer_name: 'John Doe',
  customer_email: 'john@example.com',
  line_items: [...],
  total_cents: 54000
});
```

**3. Guest Invoice:**
```javascript
// Invoice for guest customer (no account)
await createGuestInvoice({
  guest_email: 'customer@example.com',
  guest_data: {
    name: 'Jane Smith',
    company: 'Acme Corp'
  },
  line_items: [...],
  total_cents: 150000,
  due_date: '2024-02-28'
});
```

**4. Invoice Status Tracking:**
```javascript
// Get overdue invoices
const overdueInvoices = await getInvoices({
  status: 'overdue'
});

// Send payment reminders
for (const invoice of overdueInvoices) {
  await sendPaymentReminder(invoice);
}
```

**Full Documentation:** [Invoices & Receipts Guide](./invoices-receipts.md)

---

### 🔗 **Combining Optional Features**

**E-commerce with Full Features:**
```sql
✅ Core tables (users, products, orders, payments)
✅ Cost Tracking (profit analysis)
✅ Account Balance (customer wallets)
✅ Receipts (professional documentation)
```

**SaaS Platform:**
```sql
✅ Core tables (users, subscriptions, payments)
✅ Account Balance (credits system)
✅ Billing Schedules (automated billing)
✅ Invoices & Receipts (B2B invoicing)
```

**Service Business:**
```sql
✅ Core tables (users, payments)
✅ Cost Tracking (service costs)
✅ Invoices & Receipts (client billing)
```

**Marketplace:**
```sql
✅ Core tables (users, organizations, orders, payments)
✅ Cost Tracking (seller costs)
✅ Account Balance (seller payouts)
✅ Receipts (transaction records)
```

---

## 🤔 **Still Not Sure?**

### Ask yourself:

**Do you sell physical/digital products?** → E-commerce tables
**Do you charge monthly/yearly?** → Subscription tables
**Do you control access to features?** → Membership tables
**Do you serve businesses?** → Organization tables
**Do you want business insights?** → Analytics tables

**Optional Features:**
**Do you need profit analysis?** → Cost Tracking
**Do you want customer wallets?** → Account Balance
**Do you need automated billing?** → Billing Schedules
**Do you send invoices/receipts?** → Invoices & Receipts

### Start with the minimum and add tables as you need them!

**Remember:** You can always add more tables later. It's better to start simple and grow than to implement everything upfront.

### Need help deciding?

1. **Look at your current payment flow**
2. **Identify what data you actually need**
3. **Start with the minimum viable setup**
4. **Add features as your business grows**

The Native Payments system is designed to grow with you - start small, add what you need, when you need it!
