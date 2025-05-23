# Stripe Integration Guide

This guide explains how to integrate Stripe with the Native Payments system. It covers common scenarios like adding payment methods, processing payments, and handling subscriptions.

## Setup

Before you begin, you'll need:

1. A Stripe account (sandbox for testing)
2. API keys from your Stripe dashboard
3. Stripe.js and Stripe Elements in your frontend

## Configuration

Add Stripe as a payment provider in your Native Payments configuration:

```json
// Example provider configuration
{
  "id": "stripe",
  "display_name": "Stripe",
  "picture": "https://your-domain.com/images/payment-providers/stripe-logo.png",
  "is_active": true,
  "supports_subscriptions": true,
  "supports_saved_methods": true,
  "config": {
    "public_key": "pk_test_your_public_key",
    "secret_key": "sk_test_your_secret_key",
    "webhook_secret": "whsec_your_webhook_secret"
  }
}
```

## Common Scenarios

### 1. Adding a Payment Method

#### Frontend Implementation

```javascript
import { CardElement, useStripe, useElements } from '@stripe/react-stripe-js';

function AddPaymentMethodForm() {
  const stripe = useStripe();
  const elements = useElements();

  const handleSubmit = async (event) => {
    event.preventDefault();
    
    // Create a payment method in Stripe
    const result = await stripe.createPaymentMethod({
      type: 'card',
      card: elements.getElement(CardElement),
      billing_details: {
        name: 'Customer Name',
      },
    });
    
    if (result.error) {
      console.error(result.error);
    } else {
      // Send the payment method ID to your server
      const response = await fetch('/api/payment/methods', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user_id: 'current_user_id',
          provider_id: 'stripe',
          payment_type: 'credit_card',
          token: result.paymentMethod.id,
          is_default: true
        })
      });
      
      const data = await response.json();
      console.log('Saved payment method:', data);
    }
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <CardElement />
      <button type="submit">Add Payment Method</button>
    </form>
  );
}
```

#### Expected Response

```json
{
  "id": "pm_123456",
  "user_id": "user_789",
  "provider_id": "stripe",
  "provider_payment_method_id": "pm_1234567890",
  "payment_type": "credit_card",
  "last_four": "4242",
  "expiry_month": "12",
  "expiry_year": "2025",
  "card_brand": "visa",
  "is_default": true,
  "created_at": "2023-06-01T00:00:00Z"
}
```

### 2. Processing a One-Time Payment

#### Frontend Implementation

```javascript
import { CardElement, useStripe, useElements } from '@stripe/react-stripe-js';

function CheckoutForm({ orderId, clientSecret }) {
  const stripe = useStripe();
  const elements = useElements();

  const handleSubmit = async (event) => {
    event.preventDefault();
    
    // Process the payment without saving the card
    const result = await stripe.confirmCardPayment(clientSecret, {
      payment_method: {
        card: elements.getElement(CardElement),
        billing_details: {
          name: 'Customer Name',
        },
      }
    });
    
    if (result.error) {
      console.error(result.error);
    } else {
      console.log('Payment successful:', result.paymentIntent);
      // Redirect to success page or show confirmation
      window.location.href = `/orders/${orderId}/confirmation`;
    }
  };
  
  return (
    <form onSubmit={handleSubmit}>
      <CardElement />
      <button type="submit">Pay Now</button>
    </form>
  );
}
```

#### Backend Flow

1. Create a payment intent when the order is created:

```
POST /api/payment/intents
```

Request:
```json
{
  "provider_id": "stripe",
  "amount_cents": 2500,
  "currency": "USD",
  "metadata": {
    "order_id": "order_123456"
  }
}
```

Response:
```json
{
  "id": "intent_123456",
  "provider_id": "stripe",
  "provider_intent_id": "pi_1234567890",
  "client_secret": "pi_1234567890_secret_1234567890",
  "amount_cents": 2500,
  "currency": "USD",
  "status": "requires_payment_method"
}
```

2. After payment confirmation, the webhook will update the order status.

### 3. Processing a Payment with Saved Method

```javascript
async function payWithSavedMethod(orderId, paymentMethodId) {
  const response = await fetch(`/api/payment/orders/${orderId}/pay`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      payment_method_id: paymentMethodId
    })
  });
  
  const result = await response.json();
  
  if (result.status === 'completed') {
    // Payment successful
    window.location.href = `/orders/${orderId}/confirmation`;
  } else if (result.status === 'requires_action') {
    // 3D Secure authentication required
    const stripe = Stripe('your_publishable_key');
    const { error, paymentIntent } = await stripe.confirmCardPayment(
      result.client_secret
    );
    
    if (error) {
      console.error(error);
    } else {
      // Payment successful after 3D Secure
      window.location.href = `/orders/${orderId}/confirmation`;
    }
  } else {
    // Payment failed
    console.error('Payment failed:', result);
  }
}
```

### 4. Creating a Subscription

```javascript
async function createSubscription(planId, paymentMethodId) {
  const response = await fetch('/api/payment/subscriptions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_id: 'current_user_id',
      product_id: planId,
      payment_method_id: paymentMethodId
    })
  });
  
  const subscription = await response.json();
  
  if (subscription.status === 'active') {
    // Subscription created successfully
    window.location.href = '/subscriptions/confirmation';
  } else if (subscription.status === 'incomplete') {
    // Additional action required
    const stripe = Stripe('your_publishable_key');
    const { error, paymentIntent } = await stripe.confirmCardPayment(
      subscription.latest_invoice.payment_intent.client_secret
    );
    
    if (error) {
      console.error(error);
    } else {
      // Subscription activated after confirmation
      window.location.href = '/subscriptions/confirmation';
    }
  }
}
```

## Webhook Handling

Stripe sends webhooks to notify your application about events like successful payments, failed payments, and subscription renewals.

### Important Webhook Events

1. `payment_intent.succeeded`: Payment was successful
2. `payment_intent.payment_failed`: Payment failed
3. `invoice.payment_succeeded`: Subscription payment succeeded
4. `invoice.payment_failed`: Subscription payment failed
5. `customer.subscription.updated`: Subscription was updated
6. `customer.subscription.deleted`: Subscription was cancelled

### Webhook Verification

Always verify webhook signatures to ensure they come from Stripe:

```javascript
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

app.post('/api/payment/webhooks', async (req, res) => {
  const signature = req.headers['stripe-signature'];
  
  try {
    const event = stripe.webhooks.constructEvent(
      req.rawBody, // Raw request body
      signature,
      webhookSecret
    );
    
    // Process the event
    await processStripeWebhook(event);
    
    res.json({ received: true });
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    res.status(400).send(`Webhook Error: ${err.message}`);
  }
});
```

## Testing

Stripe provides test card numbers for different scenarios:

- `4242 4242 4242 4242`: Successful payment
- `4000 0000 0000 3220`: 3D Secure authentication required
- `4000 0000 0000 9995`: Payment declined

## Best Practices

1. **Always use Stripe Elements** for collecting card information to ensure PCI compliance
2. **Verify webhook signatures** to prevent fraudulent requests
3. **Handle 3D Secure authentication** for European cards (SCA compliance)
4. **Use idempotency keys** for API requests to prevent duplicate charges
5. **Implement proper error handling** to provide clear feedback to users
6. **Test thoroughly** with Stripe's test mode before going live

## Common Issues and Solutions

### Issue: Payment is declined
**Solution**: Check the error message from Stripe. Common reasons include insufficient funds, expired card, or fraud detection.

### Issue: Webhook events not being received
**Solution**: Verify your webhook endpoint is publicly accessible and the webhook secret is correct.

### Issue: 3D Secure authentication fails
**Solution**: Ensure you're correctly handling the `requires_action` status and calling `confirmCardPayment` with the client secret.

### Issue: Subscription creation fails
**Solution**: Verify the payment method belongs to the customer and is capable of recurring payments.

## Additional Resources

- [Stripe API Documentation](https://stripe.com/docs/api)
- [Stripe.js and Elements](https://stripe.com/docs/js)
- [Stripe Testing](https://stripe.com/docs/testing)
- [Stripe Webhooks](https://stripe.com/docs/webhooks)
