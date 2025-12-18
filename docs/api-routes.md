# Payment System API Routes

This document outlines the standard API routes for the multi-provider payment system. These routes provide a consistent interface regardless of the underlying payment provider (Stripe, PayPal, Authorize.net, etc.).

## Customer Management

### Create Customer

Creates a customer record with the payment provider.

```
POST /api/payment/customers
```

**Request Body:**
```json
{
  "user_id": "user_123",                // Required if organization_id not provided
  "organization_id": "org_456",         // Required if user_id not provided
  "provider_id": "stripe",              // Required - payment provider to use
  "email": "customer@example.com",      // Optional - can use user's email
  "name": "John Doe",                   // Optional - can use user's name
  "phone": "+1234567890",               // Optional
  "metadata": {                         // Optional
    "custom_field": "custom_value"
  }
}
```

**Response (201 Created):**
```json
{
  "id": "cust_internal_123",
  "provider_id": "stripe",
  "provider_customer_id": "cus_abc123def456",
  "user_id": "user_123",
  "created_at": "2023-06-15T10:30:00Z"
}
```

### Get Customer

Retrieves a customer record.

```
GET /api/payment/customers/:id
```

**Response (200 OK):**
```json
{
  "id": "cust_internal_123",
  "provider_id": "stripe",
  "provider_customer_id": "cus_abc123def456",
  "user_id": "user_123",
  "created_at": "2023-06-15T10:30:00Z",
  "updated_at": "2023-06-15T10:30:00Z"
}
```

### List Customers

Lists all customers for a user or organization.

```
GET /api/payment/customers?user_id=user_123
GET /api/payment/customers?organization_id=org_456
```

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "cust_internal_123",
      "provider_id": "stripe",
      "provider_customer_id": "cus_abc123def456",
      "user_id": "user_123",
      "created_at": "2023-06-15T10:30:00Z"
    }
  ],
  "total": 1
}
```

## Payment Methods

### Add Payment Method

Adds a new payment method for a customer.

```
POST /api/payment/methods
```

**Request Body:**
```json
{
  "user_id": "user_123",                // Required if organization_id not provided
  "organization_id": "org_456",         // Required if user_id not provided
  "provider_id": "stripe",              // Required
  "payment_type": "credit_card",        // Required: credit_card, bank_account, etc.
  "token": "tok_visa",                  // Provider-specific token from frontend
  "alias": "My primary card",           // Optional: User-friendly name for the payment method
  "is_default": true,                   // Optional
  "billing_address": {                  // Optional
    "line1": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "postal_code": "94103",
    "country": "US"
  }
}
```

**Response (201 Created):**
```json
{
  "id": "pm_internal_123",
  "provider_id": "stripe",
  "provider_payment_method_id": "pm_abc123def456",
  "payment_type": "credit_card",
  "last_four": "4242",
  "expiry_month": "12",
  "expiry_year": "2025",
  "card_brand": "visa",
  "alias": "My primary card",
  "is_default": true,
  "created_at": "2023-06-15T10:35:00Z"
}
```

### List Payment Methods

Lists all payment methods for a user or organization.

```
GET /api/payment/methods?user_id=user_123
GET /api/payment/methods?organization_id=org_456
```

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "pm_internal_123",
      "provider_id": "stripe",
      "payment_type": "credit_card",
      "last_four": "4242",
      "expiry_month": "12",
      "expiry_year": "2025",
      "card_brand": "visa",
      "alias": "My primary card",
      "is_default": true,
      "created_at": "2023-06-15T10:35:00Z"
    }
  ],
  "total": 1
}
```

### Update Payment Method

Updates a payment method's local fields (nickname, default status, etc.).

```
PUT /api/payment/methods/:id
```

**Request Body:**
```json
{
  "alias": "Updated card name",         // Optional: User-friendly name
  "is_default": true                    // Optional: Set as default payment method
}
```

**Response (200 OK):**
```json
{
  "id": "pm_internal_123",
  "provider_id": "stripe",
  "payment_type": "credit_card",
  "last_four": "4242",
  "expiry_month": "12",
  "expiry_year": "2025",
  "card_brand": "visa",
  "alias": "Updated card name",
  "is_default": true,
  "updated_at": "2023-06-15T11:00:00Z"
}
```

### Delete Payment Method

Deletes a payment method.

```
DELETE /api/payment/methods/:id
```

**Response (204 No Content)**

## Payment Intents

### Create Payment Intent

Creates a new payment intent.

```
POST /api/payment/intents
```

**Request Body:**
```json
{
  "user_id": "user_123",                // Required if organization_id not provided
  "organization_id": "org_456",         // Required if user_id not provided
  "order_id": "order_123",              // Required if subscription_id not provided
  "subscription_id": "sub_123",         // Required if order_id not provided
  "payment_method_id": "pm_internal_123", // Required
  "amount_cents": 2000,                 // Required (20.00 in the specified currency)
  "currency": "USD",                    // Optional, defaults to USD
  "metadata": {                         // Optional
    "invoice_id": "inv_123"
  }
}
```

**Response (201 Created):**
```json
{
  "id": "pi_internal_123",
  "provider_id": "stripe",
  "provider_payment_id": "pi_abc123def456",
  "order_id": "order_123",
  "amount_cents": 2000,
  "currency": "USD",
  "status": "completed",
  "created_at": "2023-06-15T10:40:00Z",
  "completed_at": "2023-06-15T10:40:05Z"
}
```

### Get Payment Intent

Retrieves a payment intent record.

```
GET /api/payment/intents/:id
```

**Response (200 OK):**
```json
{
  "id": "pi_internal_123",
  "provider_id": "stripe",
  "provider_payment_id": "pi_abc123def456",
  "order_id": "order_123",
  "amount_cents": 2000,
  "currency": "USD",
  "status": "completed",
  "created_at": "2023-06-15T10:40:00Z",
  "completed_at": "2023-06-15T10:40:05Z"
}
```

### List Payment Intents

Lists payment intents for a user, organization, order, or subscription.

```
GET /api/payment/intents?user_id=user_123
GET /api/payment/intents?organization_id=org_456
GET /api/payment/intents?order_id=order_123
GET /api/payment/intents?subscription_id=sub_123
```

**Response (200 OK):**
```json
{
  "data": [
    {
      "id": "pi_internal_123",
      "provider_id": "stripe",
      "order_id": "order_123",
      "amount_cents": 2000,
      "currency": "USD",
      "status": "completed",
      "created_at": "2023-06-15T10:40:00Z"
    }
  ],
  "total": 1
}
```

### Refund Payment Intent

Refunds a payment intent, either partially or fully.

```
POST /api/payment/intents/:id/refund
```

**Request Body:**
```json
{
  "amount_cents": 1000,  // Optional, if not provided, full refund is processed
  "reason": "customer_requested"  // Optional
}
```

**Response (200 OK):**
```json
{
  "id": "refund_internal_123",
  "payment_id": "pay_internal_123",
  "amount_cents": 1000,
  "currency": "USD",
  "status": "completed",
  "created_at": "2023-06-15T11:00:00Z"
}
```

## Subscriptions

### Create Subscription

Creates a new subscription.

```
POST /api/payment/subscriptions
```

**Request Body:**
```json
{
  "user_id": "user_123",                // Required if organization_id not provided
  "organization_id": "org_456",         // Required if user_id not provided
  "product_id": "prod_123",             // Required
  "payment_method_id": "pm_internal_123", // Required
  "trial_end": "2023-07-15T00:00:00Z",  // Optional
  "metadata": {                         // Optional
    "custom_field": "custom_value"
  }
}
```

**Response (201 Created):**
```json
{
  "id": "sub_internal_123",
  "provider_id": "stripe",
  "provider_subscription_id": "sub_abc123def456",
  "user_id": "user_123",
  "product_id": "prod_123",
  "status": "active",
  "current_period_start": "2023-06-15T00:00:00Z",
  "current_period_end": "2023-07-15T00:00:00Z",
  "price_cents": 1999,
  "currency": "USD",
  "created_at": "2023-06-15T10:45:00Z"
}
```

### Get Subscription

Retrieves a subscription record.

```
GET /api/payment/subscriptions/:id
```

**Response (200 OK):**
```json
{
  "id": "sub_internal_123",
  "provider_id": "stripe",
  "provider_subscription_id": "sub_abc123def456",
  "user_id": "user_123",
  "product_id": "prod_123",
  "status": "active",
  "current_period_start": "2023-06-15T00:00:00Z",
  "current_period_end": "2023-07-15T00:00:00Z",
  "cancel_at_period_end": false,
  "price_cents": 1999,
  "currency": "USD",
  "created_at": "2023-06-15T10:45:00Z",
  "updated_at": "2023-06-15T10:45:00Z"
}
```

### Cancel Subscription

Cancels a subscription.

```
POST /api/payment/subscriptions/:id/cancel
```

**Request Body:**
```json
{
  "at_period_end": true  // Optional, defaults to true
}
```

**Response (200 OK):**
```json
{
  "id": "sub_internal_123",
  "status": "active",
  "cancel_at_period_end": true,
  "current_period_end": "2023-07-15T00:00:00Z"
}
```

## Orders

### Create Order

Creates a new order.

```
POST /api/payment/orders
```

**Request Body:**
```json
{
  "user_id": "user_123",                // Required if organization_id not provided
  "organization_id": "org_456",         // Required if user_id not provided
  "items": [                            // Required
    {
      "product_id": "prod_123",
      "quantity": 2
    },
    {
      "product_id": "prod_456",
      "quantity": 1
    }
  ],
  "billing_address": {                  // Optional
    "line1": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "postal_code": "94103",
    "country": "US"
  },
  "shipping_address": {                 // Optional
    "line1": "123 Main St",
    "city": "San Francisco",
    "state": "CA",
    "postal_code": "94103",
    "country": "US"
  },
  "metadata": {                         // Optional
    "source": "web"
  }
}
```

**Response (201 Created):**
```json
{
  "id": "order_internal_123",
  "order_number": "ORD-12345",
  "user_id": "user_123",
  "status": "pending",
  "subtotal_cents": 3998,
  "tax_cents": 320,
  "total_cents": 4318,
  "currency": "USD",
  "items": [
    {
      "product_id": "prod_123",
      "quantity": 2,
      "unit_price_cents": 1499,
      "total_cents": 2998
    },
    {
      "product_id": "prod_456",
      "quantity": 1,
      "unit_price_cents": 1000,
      "total_cents": 1000
    }
  ],
  "created_at": "2023-06-15T10:50:00Z"
}
```

### Get Order

Retrieves an order record.

```
GET /api/payment/orders/:id
```

**Response (200 OK):**
```json
{
  "id": "order_internal_123",
  "order_number": "ORD-12345",
  "user_id": "user_123",
  "status": "pending",
  "subtotal_cents": 3998,
  "tax_cents": 320,
  "total_cents": 4318,
  "currency": "USD",
  "items": [
    {
      "product_id": "prod_123",
      "quantity": 2,
      "unit_price_cents": 1499,
      "total_cents": 2998
    },
    {
      "product_id": "prod_456",
      "quantity": 1,
      "unit_price_cents": 1000,
      "total_cents": 1000
    }
  ],
  "created_at": "2023-06-15T10:50:00Z",
  "updated_at": "2023-06-15T10:50:00Z"
}
```

### Pay Order

Processes payment for an order.

```
POST /api/payment/orders/:id/pay
```

**Request Body:**
```json
{
  "payment_method_id": "pm_internal_123"  // Required
}
```

**Response (200 OK):**
```json
{
  "order_id": "order_internal_123",
  "payment_id": "pay_internal_123",
  "status": "completed",
  "amount_cents": 4318,
  "currency": "USD"
}
```

## Webhooks

### Register Webhook Endpoint

Registers the webhook endpoint with the payment provider.

```
POST /api/payment/webhooks/register
```

**Request Body:**
```json
{
  "provider_id": "stripe",  // Required
  "url": "https://example.com/api/payment/webhooks/stripe"  // Optional, defaults to configured URL
}
```

**Response (200 OK):**
```json
{
  "provider_id": "stripe",
  "webhook_id": "whsec_abc123def456",
  "url": "https://example.com/api/payment/webhooks/stripe",
  "enabled_events": ["payment.succeeded", "subscription.created", "subscription.updated"]
}
```

### Webhook Endpoint

Endpoint that receives webhook events from payment providers.

```
POST /api/payment/webhooks/:provider_id
```

This endpoint is called by the payment provider and processes events asynchronously.

**Response (200 OK):**
```json
{
  "received": true
}
```

---

## Optional Features

The following API routes are for optional features. Each feature can be implemented independently.

### Cost Tracking (Optional Feature)

Track product costs and calculate profit margins.

**Full Documentation:** [Cost Tracking Guide](./cost-tracking.md)

#### Create Product Cost

```
POST /api/v1/costs/products/:product_id/costs
```

**Request Body:**
```json
{
  "cost_type": "per_unit",
  "cost_per_unit_cents": 1200,
  "overhead_percentage": 15,
  "cost_category": "production",
  "effective_from": "2024-01-01T00:00:00Z"
}
```

#### Calculate Order Cost

```
POST /api/v1/costs/orders/:order_id/calculate
```

**Response:**
```json
{
  "order_id": "order_123",
  "total_cost_cents": 3300,
  "base_cost_cents": 2870,
  "overhead_cost_cents": 430
}
```

#### Get Profitability Report

```
GET /api/v1/costs/reports/profitability?start_date=2024-01-01&end_date=2024-01-31
```

**Response:**
```json
{
  "total_revenue_cents": 50000,
  "total_cost_cents": 33000,
  "total_profit_cents": 17000,
  "profit_margin_percentage": 34
}
```

---

### Account Balance (Optional Feature)

Customer wallets, credits, and prepayment systems.

**Full Documentation:** [Account Balance Guide](./account-balance.md)

#### Create Balance

```
POST /api/v1/balances
```

**Request Body:**
```json
{
  "user_id": "user_123",
  "reference_code": "main_wallet",
  "balance_type": "general",
  "currency": "USD"
}
```

#### Credit Balance

```
POST /api/v1/balances/:balance_id/credit
```

**Request Body:**
```json
{
  "amount_cents": 1000,
  "description": "Promotional credit",
  "reference_code": "promo_jan2024"
}
```

#### Debit Balance

```
POST /api/v1/balances/:balance_id/debit
```

**Request Body:**
```json
{
  "amount_cents": 500,
  "description": "Payment for order #123",
  "order_id": "order_123"
}
```

#### Get Balance

```
GET /api/v1/balances/:balance_id
```

**Response:**
```json
{
  "id": "bal_123",
  "user_id": "user_123",
  "reference_code": "main_wallet",
  "current_balance_cents": 5000,
  "currency": "USD",
  "status": "active"
}
```

#### Get User Balances

```
GET /api/v1/balances/user/:user_id
```

#### Pay with Balance

```
POST /api/v1/payments/with-balance
```

**Request Body:**
```json
{
  "user_id": "user_123",
  "balance_reference_code": "main_wallet",
  "amount_cents": 2000,
  "order_id": "order_456"
}
```

#### Mixed Payment (Balance + Card)

```
POST /api/v1/payments/mixed
```

**Request Body:**
```json
{
  "user_id": "user_123",
  "total_amount_cents": 5000,
  "balance_amount_cents": 2000,
  "balance_reference_code": "main_wallet",
  "payment_method_id": "pm_123",
  "order_id": "order_789"
}
```

---

### Billing Schedules (Optional Feature)

Automated recurring billing with flexible payment sources.

**Full Documentation:** [Billing Schedules Guide](./billing-schedules.md)

#### Create Billing Schedule

```
POST /api/v1/billing-schedules
```

**Request Body:**
```json
{
  "user_id": "user_123",
  "schedule_type": "recurring",
  "amount_cents": 999,
  "billing_interval": "monthly",
  "start_date": "2024-01-01T00:00:00Z",
  "payment_method_id": "pm_123",
  "description": "Monthly membership"
}
```

#### Get Billing Schedule

```
GET /api/v1/billing-schedules/:id
```

#### Update Billing Schedule

```
PATCH /api/v1/billing-schedules/:id
```

**Request Body:**
```json
{
  "status": "paused",
  "amount_cents": 1499
}
```

#### Execute Billing Schedule

```
POST /api/v1/billing-schedules/:id/execute
```

**Response:**
```json
{
  "execution_id": "exec_123",
  "status": "success",
  "amount_charged_cents": 999,
  "payment_id": "pay_456"
}
```

#### Process Due Schedules (Cron Job)

```
POST /api/v1/billing-schedules/process-due
```

**Response:**
```json
{
  "processed": 15,
  "successful": 12,
  "failed": 3
}
```

#### Get User Billing Schedules

```
GET /api/v1/billing-schedules/user/:user_id
```

#### Cancel Billing Schedule

```
POST /api/v1/billing-schedules/:id/cancel
```

---

### Invoices & Receipts (Optional Feature)

Universal billing system with pre-payment invoices and post-payment receipts.

**Full Documentation:** [Invoices & Receipts Guide](./invoices-receipts.md)

#### Create Invoice

```
POST /api/v1/invoices
```

**Request Body:**
```json
{
  "user_id": "user_123",
  "line_items": [
    {
      "description": "Premium Subscription",
      "quantity": 1,
      "unit_price_cents": 2999,
      "total_cents": 2999
    }
  ],
  "subtotal_cents": 2999,
  "tax_cents": 240,
  "total_cents": 3239,
  "currency": "USD",
  "due_date": "2024-02-15T23:59:59Z"
}
```

#### Get Invoice

```
GET /api/v1/invoices/:id
```

#### Get User Invoices

```
GET /api/v1/invoices/user/:user_id?status=paid&limit=10
```

#### Update Invoice

```
PATCH /api/v1/invoices/:id
```

**Request Body:**
```json
{
  "status": "sent",
  "notes": "Payment due within 30 days"
}
```

#### Send Invoice

```
POST /api/v1/invoices/:id/send
```

#### Mark Invoice as Paid

```
POST /api/v1/invoices/:id/mark-paid
```

**Request Body:**
```json
{
  "payment_id": "pay_456",
  "payment_method_type": "credit_card"
}
```

#### Void Invoice

```
POST /api/v1/invoices/:id/void
```

#### Create Guest Invoice

```
POST /api/v1/invoices/guest
```

**Request Body:**
```json
{
  "guest_email": "customer@example.com",
  "guest_data": {
    "name": "Jane Smith",
    "company": "Acme Corp"
  },
  "line_items": [...],
  "total_cents": 5000
}
```

#### Create Receipt

```
POST /api/v1/receipts
```

**Request Body:**
```json
{
  "payment_id": "pay_456",
  "invoice_id": "inv_123",
  "user_id": "user_123",
  "subtotal_cents": 2999,
  "tax_cents": 240,
  "total_cents": 3239,
  "customer_name": "John Doe",
  "customer_email": "john@example.com"
}
```

#### Get Receipt

```
GET /api/v1/receipts/:id
```

#### Get Receipt by Payment

```
GET /api/v1/receipts/payment/:payment_id
```

#### Get User Receipts

```
GET /api/v1/receipts/user/:user_id?limit=10
```

#### Void Receipt

```
POST /api/v1/receipts/:id/void
```

---

## API Versioning

All optional feature endpoints use `/api/v1/` prefix for versioning. Core payment endpoints use `/api/payment/` prefix.

## Authentication

All endpoints require authentication via session token or API key. See main documentation for authentication details.

## Rate Limiting

API endpoints are rate-limited to prevent abuse. Default limits:
- 100 requests per minute for read operations
- 30 requests per minute for write operations
- 10 requests per minute for billing schedule processing

## Error Responses

All endpoints follow standard error response format:

```json
{
  "error": {
    "code": "INSUFFICIENT_BALANCE",
    "message": "Account balance is insufficient for this transaction",
    "details": {
      "required_cents": 5000,
      "available_cents": 2000
    }
  }
}
```
