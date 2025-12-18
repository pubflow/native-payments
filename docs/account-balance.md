# 💰 Account Balance Feature (Optional)

## Overview

The **Account Balance** feature enables customer wallets, credits, and prepayment systems. This optional feature allows customers to maintain account balances that can be used for payments, receive promotional credits, handle refunds, and manage prepaid subscriptions.

## When to Use This Feature

✅ **Use Account Balance if you:**
- Need customer wallet/credit systems
- Want to offer promotional credits or gift cards
- Handle refunds as account credits
- Offer prepaid subscriptions or services
- Need to track multiple balance types per customer (e.g., main wallet + promo credits)
- Want customers to pay using account balance instead of payment methods

❌ **Skip this feature if you:**
- Only accept direct payments (credit card, bank transfer)
- Don't offer credits or prepayments
- Don't need wallet functionality

---

## Database Tables

### `account_balances`
Tracks customer balances (wallets, credits, prepayments).

**Key Fields:**
- `user_id` / `organization_id` / `customer_id` - Owner of the balance
- `reference_code` - Segment balances by purpose: `'main_wallet'`, `'promo_credits'`, `'refund_balance'`, `'subscription_prepaid'`
- `balance_type` - Type: `'general'`, `'promotional'`, `'refund'`, `'prepaid'`
- `current_balance_cents` - Current balance amount
- `currency` - Currency code (USD, EUR, etc.)
- `credit_limit_cents` - Allowed credit limit (can go negative)
- `minimum_balance_cents` - Required minimum balance
- `expires_at` - Expiration date (for promotional credits)
- `status` - Status: `'active'`, `'frozen'`, `'suspended'`

**Unique Constraint:** One balance per `(user_id, organization_id, customer_id, currency, reference_code)`

### `account_transactions`
Records all balance movements.

**Key Fields:**
- `account_balance_id` - Reference to the balance
- `transaction_type` - Type: `'credit'`, `'debit'`, `'refund'`, `'adjustment'`, `'fee'`
- `amount_cents` - Transaction amount
- `balance_before_cents` - Balance before transaction
- `balance_after_cents` - Balance after transaction
- `invoice_id` / `payment_id` / `subscription_id` / `order_id` - Related entities
- `description` - Human-readable description
- `reference_code` - Unique reference code
- `status` - Status: `'pending'`, `'completed'`, `'failed'`, `'reversed'`

---

## API Endpoints

### Account Balances

#### `POST /api/v1/balances`
Create a new account balance.

**Request Body:**
```json
{
  "user_id": "user_123",
  "reference_code": "main_wallet",
  "balance_type": "general",
  "currency": "USD",
  "initial_balance_cents": 0
}
```

#### `GET /api/v1/balances/:user_id`
Get all balances for a user.

**Response:**
```json
{
  "balances": [
    {
      "id": "bal_123",
      "reference_code": "main_wallet",
      "balance_type": "general",
      "current_balance_cents": 5000,
      "currency": "USD",
      "status": "active"
    },
    {
      "id": "bal_456",
      "reference_code": "promo_credits",
      "balance_type": "promotional",
      "current_balance_cents": 1000,
      "currency": "USD",
      "expires_at": "2024-12-31T23:59:59Z",
      "status": "active"
    }
  ]
}
```

#### `GET /api/v1/balances/:user_id/:reference_code`
Get a specific balance by reference code.

### Transactions

#### `POST /api/v1/balances/:balance_id/credit`
Add funds to a balance.

**Request Body:**
```json
{
  "amount_cents": 5000,
  "description": "Added $50 to wallet",
  "reference_code": "deposit_789"
}
```

#### `POST /api/v1/balances/:balance_id/debit`
Deduct funds from a balance.

**Request Body:**
```json
{
  "amount_cents": 2000,
  "description": "Payment for Order #123",
  "order_id": "order_123",
  "reference_code": "payment_456"
}
```

#### `GET /api/v1/balances/:balance_id/transactions`
Get transaction history for a balance.

**Query Parameters:**
- `start_date` - Filter by start date
- `end_date` - Filter by end date
- `transaction_type` - Filter by type
- `limit` - Number of results (default: 50)
- `offset` - Pagination offset

**Response:**
```json
{
  "transactions": [
    {
      "id": "txn_123",
      "transaction_type": "credit",
      "amount_cents": 5000,
      "balance_before_cents": 0,
      "balance_after_cents": 5000,
      "description": "Added $50 to wallet",
      "status": "completed",
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "total": 1,
  "limit": 50,
  "offset": 0
}
```

### Payment Integration

#### `POST /api/v1/payments/with-balance`
Create a payment using account balance.

**Request Body:**
```json
{
  "user_id": "user_123",
  "amount_cents": 2000,
  "balance_reference_code": "main_wallet",
  "description": "Payment for Order #456",
  "order_id": "order_456"
}
```

#### `POST /api/v1/payments/mixed`
Create a payment using balance + payment method.

**Request Body:**
```json
{
  "user_id": "user_123",
  "total_amount_cents": 5000,
  "balance_amount_cents": 2000,
  "balance_reference_code": "main_wallet",
  "payment_method_id": "pm_789",
  "payment_method_amount_cents": 3000,
  "description": "Mixed payment for Order #789"
}
```

---

## Usage Examples

### Example 1: Create Customer Wallet

```javascript
// Create main wallet for a user
const response = await fetch('/api/v1/balances', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    reference_code: 'main_wallet',
    balance_type: 'general',
    currency: 'USD'
  })
});

const balance = await response.json();
console.log(`Wallet created: ${balance.id}`);
```

### Example 2: Add Promotional Credits

```javascript
// Create promotional credits that expire
await fetch('/api/v1/balances', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    reference_code: 'promo_credits',
    balance_type: 'promotional',
    currency: 'USD',
    initial_balance_cents: 1000,  // $10 promo credit
    expires_at: '2024-12-31T23:59:59Z'
  })
});
```

### Example 3: Process Refund as Account Credit

```javascript
// Add refund to customer's refund balance
const balanceId = 'bal_refund_123';

await fetch(`/api/v1/balances/${balanceId}/credit`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    amount_cents: 3500,  // $35 refund
    description: 'Refund for Order #456',
    order_id: 'order_456',
    reference_code: 'refund_order_456'
  })
});
```

### Example 4: Pay with Account Balance

```javascript
// Pay for an order using wallet balance
const response = await fetch('/api/v1/payments/with-balance', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    amount_cents: 2000,  // $20
    balance_reference_code: 'main_wallet',
    description: 'Payment for Order #789',
    order_id: 'order_789'
  })
});

const payment = await response.json();
console.log(`Payment completed: ${payment.id}`);
```

### Example 5: Mixed Payment (Balance + Card)

```javascript
// Customer has $20 in wallet, order total is $50
// Use $20 from wallet + $30 from credit card
await fetch('/api/v1/payments/mixed', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    total_amount_cents: 5000,
    balance_amount_cents: 2000,
    balance_reference_code: 'main_wallet',
    payment_method_id: 'pm_card_456',
    payment_method_amount_cents: 3000,
    description: 'Mixed payment for Order #999'
  })
});
```

### Example 6: Get Balance and Transaction History

```javascript
// Get all balances for a user
const balancesResponse = await fetch('/api/v1/balances/user_123');
const { balances } = await balancesResponse.json();

// Get transaction history for main wallet
const mainWallet = balances.find(b => b.reference_code === 'main_wallet');
const txResponse = await fetch(`/api/v1/balances/${mainWallet.id}/transactions?limit=10`);
const { transactions } = await txResponse.json();

console.log(`Current Balance: $${mainWallet.current_balance_cents / 100}`);
console.log(`Recent Transactions:`, transactions);
```

---

## Best Practices

### 1. **Use Multiple Balance Types**
Separate different types of credits for better tracking:

```javascript
// Main wallet - general purpose
{ reference_code: 'main_wallet', balance_type: 'general' }

// Promotional credits - marketing campaigns
{ reference_code: 'promo_credits', balance_type: 'promotional', expires_at: '...' }

// Refund balance - customer refunds
{ reference_code: 'refund_balance', balance_type: 'refund' }

// Prepaid subscription - subscription credits
{ reference_code: 'subscription_prepaid', balance_type: 'prepaid' }
```

### 2. **Set Expiration for Promotional Credits**
Always set expiration dates for promotional credits:

```javascript
{
  balance_type: 'promotional',
  expires_at: '2024-12-31T23:59:59Z',  // Expires end of year
  description: 'Holiday promotion credits'
}
```

### 3. **Use Reference Codes for Tracking**
Always include reference codes in transactions for audit trails:

```javascript
{
  amount_cents: 1000,
  description: 'Payment for Order #123',
  reference_code: 'payment_order_123',  // Unique reference
  order_id: 'order_123'
}
```

### 4. **Check Balance Before Debit**
Always verify sufficient balance before deducting:

```javascript
async function payWithBalance(userId, amountCents) {
  // Get current balance
  const balance = await fetch(`/api/v1/balances/${userId}/main_wallet`).then(r => r.json());

  if (balance.current_balance_cents < amountCents) {
    throw new Error('Insufficient balance');
  }

  // Proceed with debit
  return await fetch(`/api/v1/balances/${balance.id}/debit`, {
    method: 'POST',
    body: JSON.stringify({ amount_cents: amountCents, ... })
  });
}
```

### 5. **Handle Failed Transactions**
Implement proper error handling and transaction reversal:

```javascript
try {
  const debit = await debitBalance(balanceId, amount);
  const payment = await processPayment(debit);

  if (!payment.success) {
    // Reverse the debit
    await creditBalance(balanceId, amount, 'Reversal for failed payment');
  }
} catch (error) {
  // Handle error and reverse if needed
}
```

---

## Integration with Other Features

### With Billing Schedules (Optional)
Use account balances as payment source for recurring billing:

```javascript
{
  billing_schedule: {
    payment_priority: 'balance_first',  // Try balance first
    account_balance_id: 'bal_123',
    payment_method_id: 'pm_456'  // Fallback to card
  }
}
```

### With Invoices & Receipts (Optional)
Link balance transactions to invoices and receipts for complete audit trail.

### With Payments
Account balances can be used as a payment method alongside credit cards, bank transfers, etc.

---

## Common Use Cases

### 1. **Customer Wallet System**
Allow customers to add funds and use them for purchases.

### 2. **Promotional Credits**
Give customers time-limited promotional credits for marketing campaigns.

### 3. **Refund Management**
Issue refunds as account credits instead of reversing payments.

### 4. **Prepaid Subscriptions**
Let customers prepay for subscriptions and deduct from balance each billing cycle.

### 5. **Gift Cards**
Implement gift card functionality using promotional balances.

### 6. **Loyalty Points**
Track loyalty points as a separate balance type (convert points to cents).

---

## Migration Guide

To enable this feature in your existing database:

### MySQL
```sql
SOURCE /path/to/native-payments/mysql/schema.sql;
```

### PostgreSQL
```sql
\i /path/to/native-payments/postgresql/schema.sql
```

### SQLite
```sql
.read /path/to/native-payments/sqlite/schema.sql
```

---

## Support

For questions or issues with the Account Balance feature:
- Check the main [Native-Payments Documentation](../README.md)
- Review [API Routes](./api-routes.md)
- See [Use Cases](./use-cases.md) for more examples


