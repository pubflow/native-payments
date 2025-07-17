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
