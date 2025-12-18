# 📅 Billing Schedules Feature (Optional)

## Overview

The **Billing Schedules** feature enables automated recurring billing with flexible payment sources. This optional feature allows you to set up recurring charges that can pull from account balances, payment methods, or a combination of both.

## When to Use This Feature

✅ **Use Billing Schedules if you:**
- Need automated recurring billing (beyond standard subscriptions)
- Want flexible payment sources (balance first, then card)
- Need installment plans
- Charge recurring fees (membership fees, service fees, etc.)
- Want retry logic for failed payments
- Need custom billing intervals

❌ **Skip this feature if you:**
- Only use standard subscription billing
- Don't need automated recurring charges
- Handle billing manually

---

## Database Tables

### `billing_schedules`
Configures recurring charges.

**Key Fields:**
- `user_id` / `organization_id` / `customer_id` - Who gets charged
- `schedule_type` - Type: `'recurring'`, `'one_time'`, `'metered'`
- `amount_cents` - Charge amount
- `billing_interval` - Interval: `'daily'`, `'weekly'`, `'monthly'`, `'yearly'`
- `interval_multiplier` - Charge every X intervals (e.g., every 2 months)
- `start_date` - When to start billing
- `end_date` - When to stop (NULL = indefinite)
- `next_billing_date` - Next scheduled charge date
- `payment_method_id` - Payment method to charge
- `account_balance_id` - Account balance to charge from
- `payment_priority` - Priority: `'balance_first'`, `'payment_method_first'`, `'balance_only'`, `'payment_method_only'`
- `status` - Status: `'active'`, `'paused'`, `'cancelled'`, `'completed'`, `'failed'`
- `retry_count` / `max_retries` - Retry logic
- `reference_code` - Identifier for charge type
- `category` - Category: `'subscription'`, `'installment'`, `'fee'`, `'custom'`
- `notify_before_days` - Send notification X days before charge

### `billing_schedule_executions`
Tracks execution history.

**Key Fields:**
- `billing_schedule_id` - Reference to schedule
- `execution_status` - Status: `'success'`, `'failed'`, `'partial'`
- `attempted_amount_cents` - Amount attempted
- `charged_amount_cents` - Amount actually charged
- `payment_id` / `invoice_id` / `account_transaction_id` - Created references
- `payment_source` - Source: `'account_balance'`, `'payment_method'`, `'mixed'`
- `error_message` - Error details if failed
- `executed_at` - Execution timestamp

---

## API Endpoints

### Billing Schedules

#### `POST /api/v1/billing-schedules`
Create a new billing schedule.

**Request Body:**
```json
{
  "user_id": "user_123",
  "schedule_type": "recurring",
  "amount_cents": 2999,
  "currency": "USD",
  "billing_interval": "monthly",
  "interval_multiplier": 1,
  "start_date": "2024-02-01T00:00:00Z",
  "payment_method_id": "pm_456",
  "account_balance_id": "bal_789",
  "payment_priority": "balance_first",
  "description": "Monthly membership fee",
  "reference_code": "membership_monthly",
  "category": "subscription",
  "notify_before_days": 3
}
```

**Response:**
```json
{
  "id": "sched_123",
  "status": "active",
  "next_billing_date": "2024-02-01T00:00:00Z",
  "created_at": "2024-01-15T10:00:00Z"
}
```

#### `GET /api/v1/billing-schedules/:id`
Get a billing schedule by ID.

#### `GET /api/v1/billing-schedules/user/:user_id`
Get all billing schedules for a user.

**Query Parameters:**
- `status` - Filter by status
- `category` - Filter by category
- `active_only` - Only active schedules (default: false)

#### `PATCH /api/v1/billing-schedules/:id`
Update a billing schedule.

**Request Body:**
```json
{
  "status": "paused",
  "amount_cents": 3499
}
```

#### `DELETE /api/v1/billing-schedules/:id`
Cancel a billing schedule (sets status to 'cancelled').

### Executions

#### `GET /api/v1/billing-schedules/:id/executions`
Get execution history for a schedule.

**Query Parameters:**
- `start_date` - Filter by start date
- `end_date` - Filter by end date
- `status` - Filter by execution status
- `limit` - Number of results (default: 50)

**Response:**
```json
{
  "executions": [
    {
      "id": "exec_123",
      "execution_status": "success",
      "attempted_amount_cents": 2999,
      "charged_amount_cents": 2999,
      "payment_source": "account_balance",
      "payment_id": "pay_456",
      "executed_at": "2024-02-01T00:00:00Z"
    }
  ]
}
```

#### `POST /api/v1/billing-schedules/:id/execute`
Manually trigger a billing schedule execution.

### Batch Operations

#### `POST /api/v1/billing-schedules/process-due`
Process all due billing schedules (typically called by cron job).

**Request Body:**
```json
{
  "dry_run": false,
  "max_schedules": 100
}
```

**Response:**
```json
{
  "processed": 45,
  "successful": 42,
  "failed": 3,
  "executions": [...]
}
```

---

## Usage Examples

### Example 1: Monthly Membership Fee

```javascript
// Create monthly membership billing
const response = await fetch('/api/v1/billing-schedules', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    schedule_type: 'recurring',
    amount_cents: 999,  // $9.99/month
    billing_interval: 'monthly',
    start_date: '2024-02-01T00:00:00Z',
    payment_method_id: 'pm_card_456',
    description: 'Premium membership',
    category: 'subscription'
  })
});
```

### Example 2: Installment Plan (6 Monthly Payments)

```javascript
// Create 6-month installment plan
await fetch('/api/v1/billing-schedules', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    schedule_type: 'recurring',
    amount_cents: 5000,  // $50/month
    billing_interval: 'monthly',
    start_date: '2024-02-01T00:00:00Z',
    end_date: '2024-07-01T00:00:00Z',  // 6 months
    payment_method_id: 'pm_card_456',
    description: 'Installment plan for Order #789',
    reference_code: 'installment_order_789',
    category: 'installment',
    notify_before_days: 5
  })
});
```

### Example 3: Balance-First Payment (Wallet + Card Fallback)

```javascript
// Try to charge from wallet first, fallback to card
await fetch('/api/v1/billing-schedules', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    schedule_type: 'recurring',
    amount_cents: 1999,
    billing_interval: 'monthly',
    start_date: '2024-02-01T00:00:00Z',
    account_balance_id: 'bal_wallet_123',
    payment_method_id: 'pm_card_456',
    payment_priority: 'balance_first',  // Try wallet first
    description: 'Monthly service fee',
    category: 'fee'
  })
});
```

### Example 4: Quarterly Billing (Every 3 Months)

```javascript
// Charge every 3 months
await fetch('/api/v1/billing-schedules', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    schedule_type: 'recurring',
    amount_cents: 8999,  // $89.99 every 3 months
    billing_interval: 'monthly',
    interval_multiplier: 3,  // Every 3 months
    start_date: '2024-02-01T00:00:00Z',
    payment_method_id: 'pm_card_456',
    description: 'Quarterly subscription',
    category: 'subscription'
  })
});
```

### Example 5: Pause and Resume Schedule

```javascript
// Pause a billing schedule
await fetch('/api/v1/billing-schedules/sched_123', {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    status: 'paused'
  })
});

// Resume later
await fetch('/api/v1/billing-schedules/sched_123', {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    status: 'active',
    next_billing_date: '2024-03-01T00:00:00Z'  // Set new billing date
  })
});
```

### Example 6: Process Due Schedules (Cron Job)

```javascript
// Run this in a cron job (e.g., every hour)
const response = await fetch('/api/v1/billing-schedules/process-due', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    dry_run: false,
    max_schedules: 100
  })
});

const result = await response.json();
console.log(`Processed: ${result.successful} successful, ${result.failed} failed`);
```

---

## Best Practices

### 1. **Set Up Retry Logic**
Configure appropriate retry settings for failed payments:

```javascript
{
  max_retries: 3,  // Try up to 3 times
  // Retry logic handled automatically by the system
}
```

### 2. **Use Payment Priority Wisely**
Choose the right payment priority for your use case:

- **`balance_first`** - Try account balance first, fallback to payment method
- **`payment_method_first`** - Try payment method first, fallback to balance
- **`balance_only`** - Only use account balance (fail if insufficient)
- **`payment_method_only`** - Only use payment method

```javascript
{
  payment_priority: 'balance_first',  // Most common for wallet systems
  account_balance_id: 'bal_123',
  payment_method_id: 'pm_456'
}
```

### 3. **Send Notifications Before Charging**
Always notify customers before charging:

```javascript
{
  notify_before_days: 3,  // Notify 3 days before charge
  description: 'Monthly subscription - $9.99'
}
```

### 4. **Use Reference Codes for Tracking**
Include reference codes for easy identification:

```javascript
{
  reference_code: 'membership_premium_monthly',
  category: 'subscription'
}
```

### 5. **Monitor Execution History**
Regularly check execution history for failed payments:

```javascript
const executions = await fetch('/api/v1/billing-schedules/sched_123/executions?status=failed');
const failed = await executions.json();

// Handle failed payments
for (const exec of failed.executions) {
  console.log(`Failed: ${exec.error_message}`);
  // Send notification, update payment method, etc.
}
```

### 6. **Set End Dates for Installments**
Always set end dates for installment plans:

```javascript
{
  schedule_type: 'recurring',
  start_date: '2024-01-01',
  end_date: '2024-06-01',  // 6 months
  description: '6-month installment plan'
}
```

---

## Cron Job Setup

### Using Croner (Recommended)

```javascript
import { Cron } from 'croner';

// Process billing schedules every hour
const job = new Cron('0 * * * *', async () => {
  console.log('Processing due billing schedules...');

  const response = await fetch('http://localhost:3000/api/v1/billing-schedules/process-due', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dry_run: false, max_schedules: 100 })
  });

  const result = await response.json();
  console.log(`Processed: ${result.successful} successful, ${result.failed} failed`);
});
```

### Using Node-Cron

```javascript
import cron from 'node-cron';

// Process billing schedules every hour
cron.schedule('0 * * * *', async () => {
  // Same implementation as above
});
```

---

## Integration with Other Features

### With Account Balance (Optional)
Use account balances as primary payment source with card fallback.

### With Invoices & Receipts (Optional)
Automatically create invoices before charging and receipts after successful payment.

### With Subscriptions
Billing schedules can complement or replace standard subscription billing for more flexibility.

---

## Common Use Cases

### 1. **Membership Fees**
Recurring monthly/yearly membership charges.

### 2. **Installment Plans**
Split large purchases into multiple payments.

### 3. **Service Fees**
Recurring service or platform fees.

### 4. **Prepaid Subscriptions**
Charge from prepaid balance each billing cycle.

### 5. **Custom Billing Intervals**
Charge every 2 weeks, every 3 months, etc.

### 6. **Metered Billing**
Variable charges based on usage (set `schedule_type: 'metered'`).

---

## Error Handling

### Failed Payment Scenarios

1. **Insufficient Balance** - If using `balance_only` and balance is insufficient
2. **Payment Method Declined** - Card declined or expired
3. **Network Error** - Temporary connection issues

### Automatic Retry Logic

The system automatically retries failed payments based on `max_retries`:

```javascript
{
  retry_count: 0,      // Current retry count
  max_retries: 3,      // Maximum retries
  last_failure_reason: 'Insufficient funds'
}
```

After max retries, the schedule status changes to `'failed'`.

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

For questions or issues with the Billing Schedules feature:
- Check the main [Native-Payments Documentation](../README.md)
- Review [API Routes](./api-routes.md)
- See [Use Cases](./use-cases.md) for more examples


