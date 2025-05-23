# PayPal Integration Guide

This guide explains how to integrate PayPal with the Native Payments system. It covers common scenarios like processing payments with PayPal Checkout, saving payment methods, and handling subscriptions.

## Setup

Before you begin, you'll need:

1. A PayPal Business account (sandbox for testing)
2. Client ID and Secret from your PayPal Developer Dashboard
3. PayPal JavaScript SDK in your frontend

## Configuration

Add PayPal as a payment provider in your Native Payments configuration:

```json
// Example provider configuration
{
  "id": "paypal",
  "display_name": "PayPal",
  "picture": "https://your-domain.com/images/payment-providers/paypal-logo.png",
  "is_active": true,
  "supports_subscriptions": true,
  "supports_saved_methods": true,
  "config": {
    "client_id": "your_client_id",
    "client_secret": "your_client_secret",
    "webhook_id": "your_webhook_id",
    "environment": "sandbox" // or "production"
  }
}
```

## Common Scenarios

### 1. PayPal Checkout (One-Time Payment)

#### Frontend Implementation

```javascript
// Include the PayPal JavaScript SDK
// <script src="https://www.paypal.com/sdk/js?client-id=your_client_id&currency=USD"></script>

function initPayPalButton(orderId, amount) {
  paypal.Buttons({
    // Set up the transaction
    createOrder: function() {
      // Call your backend to create the PayPal order
      return fetch(`/api/payment/orders/${orderId}/paypal-create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        return data.paypal_order_id;
      });
    },
    
    // Finalize the transaction
    onApprove: function(data, actions) {
      // Call your backend to capture the PayPal order
      return fetch(`/api/payment/orders/${orderId}/paypal-capture`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          paypal_order_id: data.orderID
        })
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        // Show a success message to the buyer
        if (data.status === 'completed') {
          window.location.href = `/orders/${orderId}/confirmation`;
        } else {
          console.error('Payment capture failed:', data);
        }
      });
    },
    
    onError: function(err) {
      console.error('PayPal error:', err);
    }
  }).render('#paypal-button-container');
}
```

#### Backend Flow

1. Create a PayPal order when the user clicks the PayPal button:

```
POST /api/payment/orders/:orderId/paypal-create
```

Response:
```json
{
  "paypal_order_id": "5O190127TN364715T"
}
```

2. Capture the payment when the user approves the payment:

```
POST /api/payment/orders/:orderId/paypal-capture
```

Request:
```json
{
  "paypal_order_id": "5O190127TN364715T"
}
```

Response:
```json
{
  "id": "payment_123456",
  "order_id": "order_123456",
  "status": "completed",
  "amount_cents": 2500,
  "currency": "USD",
  "provider_id": "paypal",
  "provider_payment_id": "5O190127TN364715T",
  "completed_at": "2023-06-01T00:00:00Z"
}
```

### 2. PayPal Vault (Saving Payment Methods)

PayPal Vault allows you to save a customer's PayPal account for future payments.

#### Frontend Implementation

```javascript
// Include the PayPal JavaScript SDK with vault=true
// <script src="https://www.paypal.com/sdk/js?client-id=your_client_id&vault=true"></script>

function setupVaultButton() {
  paypal.Buttons({
    // Set up the transaction
    createOrder: function() {
      // Call your backend to create a setup intent
      return fetch('/api/payment/setup-intents', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          provider_id: 'paypal',
          user_id: 'current_user_id'
        })
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        return data.paypal_order_id;
      });
    },
    
    // Finalize the setup
    onApprove: function(data, actions) {
      // Call your backend to save the payment method
      return fetch('/api/payment/methods', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          user_id: 'current_user_id',
          provider_id: 'paypal',
          payment_type: 'paypal',
          token: data.orderID,
          is_default: true
        })
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        console.log('Saved payment method:', data);
        // Show success message
      });
    }
  }).render('#paypal-vault-button-container');
}
```

#### Expected Response

```json
{
  "id": "pm_123456",
  "user_id": "user_789",
  "provider_id": "paypal",
  "provider_payment_method_id": "PAYPAL-ACCOUNT-ID",
  "payment_type": "paypal",
  "is_default": true,
  "created_at": "2023-06-01T00:00:00Z"
}
```

### 3. Processing a Payment with Saved Method

```javascript
async function payWithSavedPayPal(orderId, paymentMethodId) {
  try {
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
    } else if (result.status === 'requires_approval') {
      // PayPal requires customer approval
      window.location.href = result.approval_url;
    } else {
      // Payment failed
      console.error('Payment failed:', result);
    }
  } catch (error) {
    console.error('Error processing payment:', error);
  }
}
```

### 4. PayPal Subscriptions

PayPal supports recurring billing through their Subscriptions API.

#### Frontend Implementation

```javascript
// Include the PayPal JavaScript SDK with vault=true and intent=subscription
// <script src="https://www.paypal.com/sdk/js?client-id=your_client_id&vault=true&intent=subscription"></script>

function setupSubscriptionButton(planId) {
  paypal.Buttons({
    // Set up the subscription
    createSubscription: function() {
      // Call your backend to create a subscription
      return fetch('/api/payment/subscriptions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          user_id: 'current_user_id',
          product_id: planId,
          provider_id: 'paypal'
        })
      })
      .then(function(response) {
        return response.json();
      })
      .then(function(data) {
        return data.paypal_subscription_id;
      });
    },
    
    // Finalize the subscription
    onApprove: function(data, actions) {
      // Show a success message
      window.location.href = '/subscriptions/confirmation';
    }
  }).render('#paypal-subscription-button-container');
}
```

## Webhook Handling

PayPal sends webhooks to notify your application about events like successful payments, failed payments, and subscription changes.

### Important Webhook Events

1. `PAYMENT.CAPTURE.COMPLETED`: Payment was successful
2. `PAYMENT.CAPTURE.DENIED`: Payment was denied
3. `BILLING.SUBSCRIPTION.CREATED`: Subscription was created
4. `BILLING.SUBSCRIPTION.ACTIVATED`: Subscription was activated
5. `BILLING.SUBSCRIPTION.UPDATED`: Subscription was updated
6. `BILLING.SUBSCRIPTION.CANCELLED`: Subscription was cancelled
7. `BILLING.SUBSCRIPTION.PAYMENT.FAILED`: Subscription payment failed

### Webhook Verification

Always verify webhook signatures to ensure they come from PayPal:

```javascript
const paypal = require('@paypal/checkout-server-sdk');
const webhookId = process.env.PAYPAL_WEBHOOK_ID;

app.post('/api/payment/webhooks/paypal', async (req, res) => {
  // Get PayPal-transmitted headers
  const transmissionId = req.headers['paypal-transmission-id'];
  const timestamp = req.headers['paypal-transmission-time'];
  const signature = req.headers['paypal-transmission-sig'];
  const certUrl = req.headers['paypal-cert-url'];
  
  try {
    // Verify the webhook signature
    const isVerified = await verifyPayPalWebhook(
      webhookId,
      transmissionId,
      timestamp,
      req.body,
      signature,
      certUrl
    );
    
    if (isVerified) {
      // Process the webhook event
      await processPayPalWebhook(req.body);
      res.status(200).send('OK');
    } else {
      console.error('Invalid PayPal webhook signature');
      res.status(400).send('Invalid signature');
    }
  } catch (err) {
    console.error('Error processing PayPal webhook:', err);
    res.status(500).send('Error processing webhook');
  }
});
```

## Testing

PayPal provides a sandbox environment for testing:

1. Create a sandbox account at [developer.paypal.com](https://developer.paypal.com)
2. Use the sandbox credentials in your integration
3. Create test buyer and seller accounts in the sandbox

## Best Practices

1. **Always verify webhook signatures** to prevent fraudulent requests
2. **Handle PayPal approval redirects** gracefully in your application
3. **Implement proper error handling** to provide clear feedback to users
4. **Test thoroughly** with PayPal's sandbox before going live
5. **Store PayPal transaction IDs** for future reference and dispute resolution
6. **Use PayPal's shipping address validation** to ensure accurate delivery

## Common Issues and Solutions

### Issue: PayPal button not appearing
**Solution**: Check that the PayPal JavaScript SDK is loaded correctly and the container element exists.

### Issue: "Correlation ID" errors
**Solution**: Each request to PayPal must have a unique ID. Ensure you're not reusing IDs across requests.

### Issue: Webhook events not being received
**Solution**: Verify your webhook endpoint is publicly accessible and the webhook ID is correct.

### Issue: Payment approved but order not updated
**Solution**: Ensure your capture endpoint is correctly processing the PayPal order ID and updating your database.

### Issue: Subscription creation fails
**Solution**: Verify the plan ID is correct and active in your PayPal dashboard.

## Additional Resources

- [PayPal Developer Documentation](https://developer.paypal.com/docs/api/overview/)
- [PayPal Checkout Integration](https://developer.paypal.com/docs/checkout/)
- [PayPal Subscriptions API](https://developer.paypal.com/docs/subscriptions/)
- [PayPal Webhooks](https://developer.paypal.com/docs/api/webhooks/v1/)
