# Payment System Implementation Guide

This guide provides detailed instructions for implementing the multi-provider payment system. The system is designed to be modular, allowing you to support various payment providers (Stripe, PayPal, Authorize.net, etc.) with a consistent API interface.

## System Architecture

The payment system follows a layered architecture:

1. **API Layer**: Standardized REST endpoints for client applications
2. **Service Layer**: Business logic and provider-agnostic operations
3. **Provider Layer**: Provider-specific implementations
4. **Data Layer**: Database operations for storing payment information

```
┌─────────────────┐
│   API Layer     │ ← REST endpoints (/api/payment/*)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Service Layer  │ ← Business logic, validation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Provider Layer  │ ← Provider-specific implementations
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Data Layer    │ ← Database operations
└─────────────────┘
```

## Implementation Steps

### 1. Database Setup

First, create the database tables as defined in the [database schema](./database-schema.md). This includes:

- Enhanced user tables
- Organization tables
- Payment provider tables
- Customer management tables
- Payment method tables
- Transaction tables (orders, payments, subscriptions)

### 2. Provider Integration

Create provider-specific implementations for each payment provider you want to support. Each provider should implement a common interface:

```typescript
// Example interface for payment providers
interface PaymentProvider {
  // Customer management
  createCustomer(data: CustomerCreateData): Promise<CustomerResponse>;
  getCustomer(customerId: string): Promise<CustomerResponse>;

  // Payment methods
  createPaymentMethod(data: PaymentMethodCreateData): Promise<PaymentMethodResponse>;
  deletePaymentMethod(paymentMethodId: string): Promise<void>;

  // Payments
  createPayment(data: PaymentCreateData): Promise<PaymentResponse>;
  refundPayment(paymentId: string, data: RefundData): Promise<RefundResponse>;

  // Subscriptions
  createSubscription(data: SubscriptionCreateData): Promise<SubscriptionResponse>;
  cancelSubscription(subscriptionId: string, atPeriodEnd: boolean): Promise<SubscriptionResponse>;

  // Webhooks
  registerWebhook(url: string): Promise<WebhookResponse>;
  processWebhookEvent(payload: any, signature: string): Promise<WebhookEvent>;
}
```

Implement this interface for each provider:

```typescript
// Example Stripe implementation
class StripeProvider implements PaymentProvider {
  private stripe: Stripe;

  constructor(apiKey: string) {
    this.stripe = new Stripe(apiKey);
  }

  async createCustomer(data: CustomerCreateData): Promise<CustomerResponse> {
    const customer = await this.stripe.customers.create({
      email: data.email,
      name: data.name,
      phone: data.phone,
      metadata: data.metadata
    });

    return {
      provider_id: 'stripe',
      provider_customer_id: customer.id,
      // Map other fields
    };
  }

  // Implement other methods...
}
```

### 3. Service Layer

Create service classes that use the provider implementations but present a unified interface:

```typescript
// Example payment service
class PaymentService {
  private providers: Map<string, PaymentProvider>;

  constructor(providers: Map<string, PaymentProvider>) {
    this.providers = providers;
  }

  async createPaymentIntent(data: PaymentIntentCreateData): Promise<PaymentIntentResponse> {
    // Validate input
    this.validatePaymentIntentData(data);

    // Get the appropriate provider
    const provider = this.providers.get(data.provider_id);
    if (!provider) {
      throw new Error(`Provider ${data.provider_id} not supported`);
    }

    // Create payment intent with provider
    const providerResponse = await provider.createPaymentIntent(data);

    // Save to database
    const paymentIntent = await this.savePaymentIntentToDatabase({
      ...data,
      provider_payment_id: providerResponse.provider_payment_id,
      status: providerResponse.status
    });

    // Return response
    return paymentIntent;
  }

  // Implement other methods...
}
```

### 4. API Layer

Implement the REST API endpoints as defined in the [API routes documentation](./api-routes.md):

```typescript
// Example Express route handler
app.post('/api/payment/intents', async (req, res) => {
  try {
    const paymentService = new PaymentService(providers);
    const paymentIntent = await paymentService.createPaymentIntent(req.body);
    res.status(201).json(paymentIntent);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});
```

### 5. Webhook Handling

Implement webhook handling for each provider:

```typescript
// Example webhook handler
app.post('/api/payment/webhooks/:providerId', async (req, res) => {
  const { providerId } = req.params;
  const provider = providers.get(providerId);

  if (!provider) {
    return res.status(404).json({ error: 'Provider not found' });
  }

  try {
    // Get signature from headers (provider-specific)
    const signature = req.headers['stripe-signature'];

    // Process the webhook event
    const event = await provider.processWebhookEvent(req.body, signature);

    // Save the event to database
    await saveWebhookEvent(event);

    // Process the event asynchronously
    processEventAsync(event);

    // Acknowledge receipt
    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(400).json({ error: error.message });
  }
});
```

## Business Logic Implementation

### Order Processing

When creating an order:

1. Validate the products and calculate totals
2. Create the order record
3. Create order items
4. Return the order details

When paying for an order:

1. Validate the order status (must be 'pending')
2. Get the payment method
3. Create a payment through the provider
4. Update the order status to 'paid' if successful
5. Create an invoice if needed

### Subscription Management

When creating a subscription:

1. Validate the product (must be recurring)
2. Get the payment method
3. Create a subscription through the provider
4. Save the subscription details
5. Schedule renewal handling

When canceling a subscription:

1. Cancel the subscription through the provider
2. Update the subscription status in the database
3. Handle prorations if needed

## Provider-Specific Considerations

### Stripe

- Use Stripe.js on the frontend to collect payment information securely
- Implement webhook handling for events like `payment_intent.succeeded`, `subscription.created`, etc.
- Use Stripe Customer Portal for subscription management

### PayPal

- Implement PayPal Checkout for one-time payments
- Use PayPal Subscriptions API for recurring payments
- Handle IPN (Instant Payment Notification) for webhooks

### Authorize.net

- Use Accept.js for secure payment collection
- Implement Customer Information Manager (CIM) for saved payment methods
- Set up webhooks for transaction notifications

## Testing

Test each payment provider integration thoroughly:

1. Use test/sandbox credentials for each provider
2. Test the full payment flow (create customer → add payment method → make payment)
3. Test subscription creation and cancellation
4. Test webhook handling with provider's webhook testing tools
5. Test error scenarios (declined cards, insufficient funds, etc.)

## Security Considerations

1. **PCI Compliance**: Never store raw credit card data. Use provider tokens instead.
2. **API Keys**: Store provider API keys securely (environment variables, secrets manager).
3. **Webhook Signatures**: Always validate webhook signatures to prevent fraud.
4. **HTTPS**: Ensure all payment endpoints use HTTPS.
5. **Input Validation**: Validate all input data before processing.
6. **Logging**: Log payment events but exclude sensitive information.

## Deployment Considerations

1. **Database Migrations**: Create proper migrations for the payment tables.
2. **Environment Configuration**: Set up different configurations for development, testing, and production.
3. **Monitoring**: Implement monitoring for payment processing and webhook handling.
4. **Error Handling**: Set up proper error handling and alerting for payment failures.

## Extending the System

The payment system is designed to be extensible:

1. **New Providers**: Implement the `PaymentProvider` interface for any new provider.
2. **New Payment Methods**: Update the database schema and provider implementations.
3. **Additional Features**: Add support for features like recurring billing, metered billing, etc.

## Conclusion

This implementation guide provides a framework for building a robust, multi-provider payment system. By following this architecture, you can create a payment system that is:

- **Flexible**: Support multiple payment providers
- **Consistent**: Provide a unified API regardless of the provider
- **Scalable**: Add new providers and features as needed
- **Secure**: Follow best practices for payment processing

For specific implementation details, refer to the provider's documentation and API references.
