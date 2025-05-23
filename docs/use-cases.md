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

## 🤔 **Still Not Sure?**

### Ask yourself:

**Do you sell physical/digital products?** → E-commerce tables
**Do you charge monthly/yearly?** → Subscription tables  
**Do you control access to features?** → Membership tables
**Do you serve businesses?** → Organization tables
**Do you want business insights?** → Analytics tables

### Start with the minimum and add tables as you need them!

**Remember:** You can always add more tables later. It's better to start simple and grow than to implement everything upfront.

### Need help deciding?

1. **Look at your current payment flow**
2. **Identify what data you actually need**
3. **Start with the minimum viable setup**
4. **Add features as your business grows**

The Native Payments system is designed to grow with you - start small, add what you need, when you need it!
