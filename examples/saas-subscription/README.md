# SaaS Subscription Implementation

This example demonstrates how to implement a subscription-based payment flow for a SaaS (Software as a Service) product using the Native Payments system.

## Use Case

A SaaS company offers a product with multiple subscription tiers:
- **Basic**: $9.99/month
- **Pro**: $29.99/month
- **Enterprise**: $99.99/month

Each tier includes different features and usage limits. Customers can upgrade, downgrade, or cancel their subscription at any time.

## Implementation Flow

### 1. Customer Registration

When a user signs up for your SaaS product:

```javascript
// 1. Create a user in your system
const user = await db.users.create({
  name: 'John Doe',
  email: 'john@example.com',
  // other user details
});

// First, let's set up the payment providers
const paymentProviders = [
  {
    id: 'stripe',
    display_name: 'Stripe',
    picture: 'https://example.com/images/payment-providers/stripe-logo.png',
    is_active: true,
    supports_subscriptions: true,
    supports_saved_methods: true
  },
  {
    id: 'paypal',
    display_name: 'PayPal',
    picture: 'https://example.com/images/payment-providers/paypal-logo.png',
    is_active: true,
    supports_subscriptions: true,
    supports_saved_methods: true
  }
];

// Create payment providers in your database
for (const provider of paymentProviders) {
  await db.payment_providers.create(provider);
}

// 2. Create a customer in the payment system
const customerResponse = await fetch('/api/payment/customers', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: user.id,
    provider_id: 'stripe', // or your preferred payment provider
    email: user.email,
    name: user.name
  })
});

const customer = await customerResponse.json();
```

### 2. Subscription Plan Setup

Define your subscription plans in the payment system:

```javascript
// Create product categories
const categories = [
  {
    id: 'cat_subscription_plans',
    name: 'Subscription Plans',
    description: 'Available subscription plans',
    image: 'https://example.com/images/categories/subscription-plans.jpg',
    is_active: true,
    sort_order: 1
  }
];

// Create categories in your database
for (const category of categories) {
  await db.product_categories.create(category);
}

// Create subscription plans (typically done once during system setup)
const plans = [
  {
    id: 'basic_monthly',
    name: 'Basic Plan',
    description: 'Basic features for small teams',
    product_type: 'subscription',
    is_recurring: true,
    price_cents: 999, // $9.99
    currency: 'USD',
    billing_interval: 'monthly',
    trial_days: 14,
    category_id: 'cat_subscription_plans',
    image: 'https://example.com/images/products/basic-plan.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/products/basic-features-1.jpg',
      'https://example.com/images/products/basic-features-2.jpg'
    ])
  },
  {
    id: 'pro_monthly',
    name: 'Pro Plan',
    description: 'Advanced features for growing teams',
    product_type: 'subscription',
    is_recurring: true,
    price_cents: 2999, // $29.99
    currency: 'USD',
    billing_interval: 'monthly',
    trial_days: 14,
    category_id: 'cat_subscription_plans',
    image: 'https://example.com/images/products/pro-plan.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/products/pro-features-1.jpg',
      'https://example.com/images/products/pro-features-2.jpg',
      'https://example.com/images/products/pro-features-3.jpg'
    ])
  },
  // Enterprise plan...
];

// Create each plan in your payment system
for (const plan of plans) {
  await fetch('/api/payment/products', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(plan)
  });
}
```

### 3. Payment Method Collection

When a user wants to subscribe to a plan, collect their payment method:

```javascript
// Frontend code using Stripe Elements (example)
const stripe = Stripe('your_publishable_key');
const elements = stripe.elements();
const cardElement = elements.create('card');
cardElement.mount('#card-element');

// When the user submits the form
const { paymentMethod, error } = await stripe.createPaymentMethod({
  type: 'card',
  card: cardElement,
});

if (error) {
  // Handle error
  console.error(error);
} else {
  // Send the payment method to your server
  const response = await fetch('/api/payment/methods', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_id: userId,
      provider_id: 'stripe',
      payment_type: 'credit_card',
      token: paymentMethod.id,
      is_default: true
    })
  });

  const savedPaymentMethod = await response.json();
}
```

### 4. Creating a Subscription

When the user selects a plan and provides a payment method:

```javascript
// Create a subscription
const subscriptionResponse = await fetch('/api/payment/subscriptions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: userId,
    product_id: 'pro_monthly', // The selected plan
    payment_method_id: paymentMethodId,
    // Optional: Override the default trial period
    trial_end: '2023-07-15T00:00:00Z'
  })
});

const subscription = await subscriptionResponse.json();

// Update user's subscription status in your application
await db.users.update(userId, {
  subscription_status: 'active',
  subscription_id: subscription.id,
  subscription_plan: 'pro',
  subscription_end_date: new Date(subscription.current_period_end)
});
```

### 5. Handling Subscription Lifecycle

#### Upgrading or Downgrading

When a user wants to change their subscription plan:

```javascript
// Update subscription
const updateResponse = await fetch(`/api/payment/subscriptions/${subscriptionId}`, {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    product_id: 'enterprise_monthly', // New plan
    // Optional: Whether to prorate the charges
    prorate: true
  })
});

const updatedSubscription = await updateResponse.json();

// Update user's subscription details in your application
await db.users.update(userId, {
  subscription_plan: 'enterprise',
  subscription_end_date: new Date(updatedSubscription.current_period_end)
});
```

#### Cancellation

When a user wants to cancel their subscription:

```javascript
// Cancel subscription
const cancelResponse = await fetch(`/api/payment/subscriptions/${subscriptionId}/cancel`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    at_period_end: true // Cancel at the end of the current billing period
  })
});

const cancelledSubscription = await cancelResponse.json();

// Update user's subscription status in your application
await db.users.update(userId, {
  subscription_status: 'cancelled',
  cancellation_date: new Date(),
  access_until: new Date(cancelledSubscription.current_period_end)
});
```

### 6. Webhook Handling

Set up webhook handlers to process subscription events:

```javascript
// Example Express route for handling webhooks
app.post('/api/payment/webhooks/stripe', async (req, res) => {
  const signature = req.headers['stripe-signature'];

  try {
    // Verify and process the webhook
    const event = stripe.webhooks.constructEvent(
      req.body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET
    );

    // Handle different event types
    switch (event.type) {
      case 'customer.subscription.created':
        await handleSubscriptionCreated(event.data.object);
        break;
      case 'customer.subscription.updated':
        await handleSubscriptionUpdated(event.data.object);
        break;
      case 'customer.subscription.deleted':
        await handleSubscriptionCancelled(event.data.object);
        break;
      case 'invoice.payment_succeeded':
        await handleInvoicePaid(event.data.object);
        break;
      case 'invoice.payment_failed':
        await handleInvoicePaymentFailed(event.data.object);
        break;
    }

    res.status(200).json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(400).json({ error: error.message });
  }
});

// Example handler for subscription updates
async function handleSubscriptionUpdated(subscription) {
  // Find the user associated with this subscription
  const providerCustomer = await db.providerCustomers.findOne({
    provider_id: 'stripe',
    provider_customer_id: subscription.customer
  });

  if (!providerCustomer) return;

  // Update the user's subscription status
  await db.users.update(providerCustomer.user_id, {
    subscription_status: mapSubscriptionStatus(subscription.status),
    subscription_end_date: new Date(subscription.current_period_end * 1000)
  });
}

// Map provider-specific status to your application status
function mapSubscriptionStatus(providerStatus) {
  const statusMap = {
    'active': 'active',
    'past_due': 'past_due',
    'unpaid': 'inactive',
    'canceled': 'cancelled',
    'trialing': 'trial'
  };

  return statusMap[providerStatus] || 'inactive';
}
```

## Sequence Diagram

```
┌─────┐          ┌─────────┐          ┌───────────────┐          ┌─────────────────┐
│User │          │Your App │          │Native Payments│          │Payment Provider │
└──┬──┘          └────┬────┘          └───────┬───────┘          └────────┬────────┘
   │  Register      │                         │                           │
   │─────────────────>                        │                           │
   │                │                         │                           │
   │                │  Create Customer        │                           │
   │                │────────────────────────>│                           │
   │                │                         │  Create Customer          │
   │                │                         │─────────────────────────>│
   │                │                         │                           │
   │                │                         │<─────────────────────────│
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │  Select Plan   │                         │                           │
   │─────────────────>                        │                           │
   │                │                         │                           │
   │  Enter Payment │                         │                           │
   │─────────────────>                        │                           │
   │                │                         │                           │
   │                │  Create Payment Method  │                           │
   │                │────────────────────────>│                           │
   │                │                         │  Create Payment Method    │
   │                │                         │─────────────────────────>│
   │                │                         │                           │
   │                │                         │<─────────────────────────│
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │                │  Create Subscription    │                           │
   │                │────────────────────────>│                           │
   │                │                         │  Create Subscription      │
   │                │                         │─────────────────────────>│
   │                │                         │                           │
   │                │                         │<─────────────────────────│
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │  Subscription  │                         │                           │
   │  Confirmation  │                         │                           │
   │<─────────────────                        │                           │
   │                │                         │                           │
   │                │                         │                           │
   │                │                         │  Webhook: Subscription    │
   │                │                         │<─────────────────────────│
   │                │                         │                           │
   │                │  Webhook: Subscription  │                           │
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │                │  Update User Status     │                           │
   │                │───────────┐             │                           │
   │                │           │             │                           │
   │                │<──────────┘             │                           │
   │                │                         │                           │
```

## Best Practices

1. **Trial Periods**: Offer a trial period to let users try your service before being charged.
2. **Upgrade/Downgrade**: Make it easy for users to change their subscription plan.
3. **Prorations**: Consider prorating charges when users upgrade or downgrade mid-billing cycle.
4. **Dunning Management**: Implement retry logic for failed payments to reduce churn.
5. **Cancellation Flow**: Make cancellation straightforward but consider offering incentives to stay.
6. **Subscription Metrics**: Track key metrics like MRR, churn rate, and lifetime value.

## Common Issues and Solutions

1. **Failed Payments**: Implement automatic retries and notify users to update their payment method.
2. **Subscription Synchronization**: Use webhooks to keep your database in sync with the payment provider.
3. **Plan Changes**: Handle proration and immediate vs. next-billing-cycle changes correctly.
4. **Cancellations**: Distinguish between immediate cancellations and end-of-period cancellations.
5. **Reactivations**: Allow users to easily reactivate cancelled subscriptions.
