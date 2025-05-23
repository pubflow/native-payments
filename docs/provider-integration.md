# Payment Provider Integration Guide

This guide provides detailed instructions for integrating specific payment providers with the multi-provider payment system. Each provider has unique features, APIs, and requirements, but our system abstracts these differences behind a consistent interface.

## Provider Architecture

Each payment provider is implemented as a separate module that conforms to a common interface. This allows the system to interact with any provider in a consistent way while leveraging provider-specific features.

```
┌─────────────────────────────────────────────────────────┐
│                   Payment System                        │
└───────────────────────────┬─────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
┌───────────────────────┐   ┌───────────────────────┐
│  Provider Interface   │   │  Database Interface   │
└───────────┬───────────┘   └───────────────────────┘
            │
┌───────────┼───────────┬───────────────┬───────────────┐
▼           ▼           ▼               ▼               ▼
┌───────────────┐ ┌───────────┐ ┌───────────────┐ ┌───────────────┐
│Stripe Provider│ │PayPal     │ │Authorize.net  │ │Square         │
└───────────────┘ └───────────┘ └───────────────┘ └───────────────┘
```

## Common Provider Interface

All providers implement this common interface:

```typescript
interface PaymentProvider {
  // Provider information
  getId(): string;
  getName(): string;
  getFeatures(): ProviderFeatures;

  // Customer management
  createCustomer(data: CustomerCreateData): Promise<CustomerResponse>;
  getCustomer(customerId: string): Promise<CustomerResponse>;
  updateCustomer(customerId: string, data: CustomerUpdateData): Promise<CustomerResponse>;
  deleteCustomer(customerId: string): Promise<void>;

  // Payment methods
  createPaymentMethod(data: PaymentMethodCreateData): Promise<PaymentMethodResponse>;
  getPaymentMethod(paymentMethodId: string): Promise<PaymentMethodResponse>;
  updatePaymentMethod(paymentMethodId: string, data: PaymentMethodUpdateData): Promise<PaymentMethodResponse>;
  deletePaymentMethod(paymentMethodId: string): Promise<void>;

  // Payment Intents
  createPaymentIntent(data: PaymentIntentCreateData): Promise<PaymentIntentResponse>;
  getPaymentIntent(paymentIntentId: string): Promise<PaymentIntentResponse>;
  refundPaymentIntent(paymentIntentId: string, data: RefundData): Promise<RefundResponse>;

  // Subscriptions
  createSubscription(data: SubscriptionCreateData): Promise<SubscriptionResponse>;
  getSubscription(subscriptionId: string): Promise<SubscriptionResponse>;
  updateSubscription(subscriptionId: string, data: SubscriptionUpdateData): Promise<SubscriptionResponse>;
  cancelSubscription(subscriptionId: string, atPeriodEnd: boolean): Promise<SubscriptionResponse>;

  // Webhooks
  registerWebhook(url: string, events: string[]): Promise<WebhookResponse>;
  processWebhookEvent(payload: any, signature: string): Promise<WebhookEvent>;
}
```

## Stripe Integration

### Setup

1. **Install Dependencies**:
   ```bash
   npm install stripe
   ```

2. **Initialize Provider**:
   ```typescript
   import Stripe from 'stripe';

   class StripeProvider implements PaymentProvider {
     private stripe: Stripe;

     constructor(apiKey: string) {
       this.stripe = new Stripe(apiKey, {
         apiVersion: '2023-10-16', // Use the latest API version
       });
     }

     // Implement interface methods...
   }
   ```

### Customer Management

```typescript
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
    email: customer.email,
    name: customer.name,
    created_at: new Date(customer.created * 1000).toISOString()
  };
}
```

### Payment Methods

```typescript
async createPaymentMethod(data: PaymentMethodCreateData): Promise<PaymentMethodResponse> {
  // Attach payment method to customer
  const paymentMethod = await this.stripe.paymentMethods.attach(
    data.token, // This should be a payment method ID from Stripe.js
    { customer: data.provider_customer_id }
  );

  // Set as default if requested
  if (data.is_default) {
    await this.stripe.customers.update(data.provider_customer_id, {
      invoice_settings: {
        default_payment_method: paymentMethod.id
      }
    });
  }

  return {
    provider_id: 'stripe',
    provider_payment_method_id: paymentMethod.id,
    payment_type: paymentMethod.type,
    last_four: paymentMethod.card?.last4,
    expiry_month: paymentMethod.card?.exp_month.toString(),
    expiry_year: paymentMethod.card?.exp_year.toString(),
    card_brand: paymentMethod.card?.brand,
    is_default: data.is_default
  };
}
```

### Payment Intents

```typescript
async createPaymentIntent(data: PaymentIntentCreateData): Promise<PaymentIntentResponse> {
  // Create a payment intent
  const paymentIntent = await this.stripe.paymentIntents.create({
    amount: data.amount_cents,
    currency: data.currency.toLowerCase(),
    customer: data.provider_customer_id,
    payment_method: data.provider_payment_method_id,
    confirm: true,
    metadata: data.metadata
  });

  return {
    provider_id: 'stripe',
    provider_payment_id: paymentIntent.id,
    amount_cents: paymentIntent.amount,
    currency: paymentIntent.currency.toUpperCase(),
    status: this.mapPaymentIntentStatus(paymentIntent.status),
    created_at: new Date(paymentIntent.created * 1000).toISOString()
  };
}

private mapPaymentIntentStatus(stripeStatus: string): string {
  const statusMap: Record<string, string> = {
    'succeeded': 'completed',
    'processing': 'pending',
    'requires_payment_method': 'failed',
    'requires_action': 'pending',
    'requires_confirmation': 'pending',
    'canceled': 'cancelled'
  };

  return statusMap[stripeStatus] || 'pending';
}
```

### Subscriptions

```typescript
async createSubscription(data: SubscriptionCreateData): Promise<SubscriptionResponse> {
  // Get the price ID from the product
  const priceId = await this.getPriceIdFromProduct(data.product_id);

  // Create the subscription
  const subscription = await this.stripe.subscriptions.create({
    customer: data.provider_customer_id,
    items: [{ price: priceId }],
    default_payment_method: data.provider_payment_method_id,
    trial_end: data.trial_end ? Math.floor(new Date(data.trial_end).getTime() / 1000) : undefined,
    metadata: data.metadata
  });

  return {
    provider_id: 'stripe',
    provider_subscription_id: subscription.id,
    status: this.mapSubscriptionStatus(subscription.status),
    current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
    current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
    cancel_at_period_end: subscription.cancel_at_period_end,
    trial_end: subscription.trial_end ? new Date(subscription.trial_end * 1000).toISOString() : null,
    price_cents: subscription.items.data[0].price.unit_amount,
    currency: subscription.currency.toUpperCase()
  };
}
```

### Webhooks

```typescript
async processWebhookEvent(payload: any, signature: string): Promise<WebhookEvent> {
  // Verify the webhook signature
  const event = this.stripe.webhooks.constructEvent(
    payload,
    signature,
    process.env.STRIPE_WEBHOOK_SECRET
  );

  // Map to a standard event format
  return {
    provider_id: 'stripe',
    event_type: this.mapEventType(event.type),
    entity_type: this.getEntityType(event.type),
    entity_id: this.getEntityId(event),
    data: event.data.object,
    created_at: new Date(event.created * 1000).toISOString()
  };
}

private mapEventType(stripeEventType: string): string {
  const eventMap: Record<string, string> = {
    'payment_intent.succeeded': 'payment.succeeded',
    'payment_intent.payment_failed': 'payment.failed',
    'customer.subscription.created': 'subscription.created',
    'customer.subscription.updated': 'subscription.updated',
    'customer.subscription.deleted': 'subscription.cancelled',
    'invoice.payment_succeeded': 'invoice.paid',
    'invoice.payment_failed': 'invoice.payment_failed'
  };

  return eventMap[stripeEventType] || stripeEventType;
}
```

## PayPal Integration

### Setup

1. **Install Dependencies**:
   ```bash
   npm install @paypal/checkout-server-sdk
   ```

2. **Initialize Provider**:
   ```typescript
   import checkoutNodeJssdk from '@paypal/checkout-server-sdk';

   class PayPalProvider implements PaymentProvider {
     private client: any;

     constructor(clientId: string, clientSecret: string, environment: 'sandbox' | 'production') {
       let paypalEnvironment;
       if (environment === 'production') {
         paypalEnvironment = new checkoutNodeJssdk.core.LiveEnvironment(clientId, clientSecret);
       } else {
         paypalEnvironment = new checkoutNodeJssdk.core.SandboxEnvironment(clientId, clientSecret);
       }

       this.client = new checkoutNodeJssdk.core.PayPalHttpClient(paypalEnvironment);
     }

     // Implement interface methods...
   }
   ```

### Payment Intents

```typescript
async createPaymentIntent(data: PaymentIntentCreateData): Promise<PaymentIntentResponse> {
  const request = new checkoutNodeJssdk.orders.OrdersCreateRequest();
  request.prefer('return=representation');
  request.requestBody({
    intent: 'CAPTURE',
    purchase_units: [{
      amount: {
        currency_code: data.currency,
        value: (data.amount_cents / 100).toFixed(2)
      }
    }]
  });

  const response = await this.client.execute(request);

  // For PayPal, we need to return the approval URL for the user to complete the payment
  return {
    provider_id: 'paypal',
    provider_payment_id: response.result.id,
    amount_cents: Math.round(parseFloat(response.result.purchase_units[0].amount.value) * 100),
    currency: response.result.purchase_units[0].amount.currency_code,
    status: 'pending',
    approval_url: this.getApprovalUrl(response.result.links),
    created_at: new Date().toISOString()
  };
}

private getApprovalUrl(links: any[]): string {
  for (const link of links) {
    if (link.rel === 'approve') {
      return link.href;
    }
  }
  return '';
}
```

## Authorize.net Integration

### Setup

1. **Install Dependencies**:
   ```bash
   npm install authorizenet
   ```

2. **Initialize Provider**:
   ```typescript
   import ApiContracts from 'authorizenet/lib/apicontracts';
   import ApiControllers from 'authorizenet/lib/apicontrollers';

   class AuthorizeNetProvider implements PaymentProvider {
     private apiLoginKey: string;
     private transactionKey: string;
     private environment: string;

     constructor(apiLoginKey: string, transactionKey: string, environment: 'sandbox' | 'production') {
       this.apiLoginKey = apiLoginKey;
       this.transactionKey = transactionKey;
       this.environment = environment;
     }

     // Implement interface methods...
   }
   ```

### Customer Management

```typescript
async createCustomer(data: CustomerCreateData): Promise<CustomerResponse> {
  const merchantAuthenticationType = new ApiContracts.MerchantAuthenticationType();
  merchantAuthenticationType.setName(this.apiLoginKey);
  merchantAuthenticationType.setTransactionKey(this.transactionKey);

  const customer = new ApiContracts.CustomerTypeEnum.INDIVIDUAL;
  const customerData = new ApiContracts.CustomerDataType();
  customerData.setType(customer);
  customerData.setEmail(data.email);

  const createRequest = new ApiContracts.CreateCustomerProfileRequest();
  createRequest.setMerchantAuthentication(merchantAuthenticationType);
  createRequest.setProfile(new ApiContracts.CustomerProfileType());
  createRequest.getProfile().setEmail(data.email);
  createRequest.getProfile().setDescription(data.name);

  const controller = new ApiControllers.CreateCustomerProfileController(createRequest.getJSON());

  // Set environment
  if (this.environment === 'production') {
    controller.setEnvironment(ApiControllers.Constants.endpoint.production);
  }

  return new Promise((resolve, reject) => {
    controller.execute(() => {
      const apiResponse = controller.getResponse();
      const response = new ApiContracts.CreateCustomerProfileResponse(apiResponse);

      if (response.getMessages().getResultCode() === ApiContracts.MessageTypeEnum.OK) {
        resolve({
          provider_id: 'authorize_net',
          provider_customer_id: response.getCustomerProfileId(),
          email: data.email,
          name: data.name,
          created_at: new Date().toISOString()
        });
      } else {
        reject(new Error(response.getMessages().getMessage()[0].getText()));
      }
    });
  });
}
```

## Provider Selection Strategy

When implementing multiple payment providers, you need a strategy to select the appropriate provider for each transaction:

### 1. Configuration-Based Selection

Allow administrators to configure which provider to use as the default:

```typescript
// Example configuration
const config = {
  defaultProvider: 'stripe',
  providers: {
    stripe: {
      enabled: true,
      apiKey: 'sk_test_...'
    },
    paypal: {
      enabled: true,
      clientId: '...',
      clientSecret: '...'
    },
    authorize_net: {
      enabled: false,
      apiLoginKey: '...',
      transactionKey: '...'
    }
  }
};
```

### 2. Feature-Based Selection

Select providers based on the features needed for a specific transaction:

```typescript
function selectProvider(requirements: ProviderRequirements): PaymentProvider {
  // Check which providers support the required features
  const eligibleProviders = providers.filter(provider => {
    const features = provider.getFeatures();

    if (requirements.subscriptions && !features.subscriptions) {
      return false;
    }

    if (requirements.savedPaymentMethods && !features.savedPaymentMethods) {
      return false;
    }

    if (requirements.currency && !features.supportedCurrencies.includes(requirements.currency)) {
      return false;
    }

    return true;
  });

  // Return the first eligible provider or the default
  return eligibleProviders[0] || providers.find(p => p.getId() === config.defaultProvider);
}
```

### 3. User/Organization Preference

Allow users or organizations to select their preferred payment provider:

```typescript
async function getUserPreferredProvider(userId: string): Promise<PaymentProvider> {
  // Get user preferences from database
  const user = await getUserById(userId);

  if (user.preferred_payment_provider && isProviderEnabled(user.preferred_payment_provider)) {
    return providers.find(p => p.getId() === user.preferred_payment_provider);
  }

  // Fall back to default
  return providers.find(p => p.getId() === config.defaultProvider);
}
```

## Conclusion

This guide provides a framework for integrating multiple payment providers with your system. By implementing a common interface for all providers, you can offer flexibility to your users while maintaining a consistent codebase.

Remember to:

1. Keep provider-specific code isolated in provider implementations
2. Handle provider-specific error cases appropriately
3. Test each provider integration thoroughly
4. Monitor provider API changes and update your implementations accordingly

For detailed API documentation for each provider, refer to their official documentation:

- [Stripe API Documentation](https://stripe.com/docs/api)
- [PayPal API Documentation](https://developer.paypal.com/docs/api/overview/)
- [Authorize.net API Documentation](https://developer.authorize.net/api/reference/)
