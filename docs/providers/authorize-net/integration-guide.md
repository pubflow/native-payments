# Authorize.Net Integration Guide

This guide explains how to integrate Authorize.Net with the Native Payments system. It covers common scenarios like adding payment methods, processing payments, and handling recurring billing.

## Setup

Before you begin, you'll need:

1. An Authorize.Net account (sandbox for testing)
2. API Login ID and Transaction Key from your Authorize.Net dashboard
3. Authorize.Net Accept.js library in your frontend

## Configuration

Add Authorize.Net as a payment provider in your Native Payments configuration:

```json
// Example provider configuration
{
  "id": "authorize_net",
  "display_name": "Authorize.Net",
  "picture": "https://your-domain.com/images/payment-providers/authorize-net-logo.png",
  "is_active": true,
  "supports_subscriptions": true,
  "supports_saved_methods": true,
  "config": {
    "api_login_id": "your_api_login_id",
    "transaction_key": "your_transaction_key",
    "public_client_key": "your_public_client_key",
    "environment": "sandbox" // or "production"
  }
}
```

## Common Scenarios

### 1. Adding a Payment Method

#### Frontend Implementation

```javascript
// Include the Accept.js library
// <script type="text/javascript" src="https://jstest.authorize.net/v1/Accept.js" charset="utf-8"></script>

function addPaymentMethod() {
  // Collect card information from your form
  const secureData = {
    authData: {
      clientKey: "your_public_client_key",
      apiLoginID: "your_api_login_id"
    },
    cardData: {
      cardNumber: document.getElementById('cardNumber').value,
      month: document.getElementById('expiryMonth').value,
      year: document.getElementById('expiryYear').value,
      cardCode: document.getElementById('cvv').value,
      fullName: document.getElementById('cardholderName').value
    }
  };

  // Send the card data to Authorize.Net to get a payment nonce
  Accept.dispatchData(secureData, responseHandler);

  function responseHandler(response) {
    if (response.messages.resultCode === "Error") {
      // Show error to customer
      console.error(response.messages.message);
    } else {
      // Get the payment nonce (data value)
      const dataValue = response.opaqueData.dataValue;
      
      // Send the payment nonce to your server
      fetch('/api/payment/methods', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user_id: 'current_user_id',
          provider_id: 'authorize_net',
          payment_type: 'credit_card',
          token: dataValue,
          is_default: true,
          // Include billing address if needed
          billing_address_id: 'address_123'
        })
      })
      .then(response => response.json())
      .then(data => {
        console.log('Saved payment method:', data);
      })
      .catch(error => {
        console.error('Error saving payment method:', error);
      });
    }
  }
}
```

#### Expected Response

```json
{
  "id": "pm_123456",
  "user_id": "user_789",
  "provider_id": "authorize_net",
  "provider_payment_method_id": "1234567890",
  "payment_type": "credit_card",
  "last_four": "1234",
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
function processPayment() {
  // Collect card information from your form
  const secureData = {
    authData: {
      clientKey: "your_public_client_key",
      apiLoginID: "your_api_login_id"
    },
    cardData: {
      cardNumber: document.getElementById('cardNumber').value,
      month: document.getElementById('expiryMonth').value,
      year: document.getElementById('expiryYear').value,
      cardCode: document.getElementById('cvv').value,
      fullName: document.getElementById('cardholderName').value
    }
  };

  // Send the card data to Authorize.Net to get a payment nonce
  Accept.dispatchData(secureData, responseHandler);

  function responseHandler(response) {
    if (response.messages.resultCode === "Error") {
      // Show error to customer
      console.error(response.messages.message);
    } else {
      // Get the payment nonce (data value)
      const dataValue = response.opaqueData.dataValue;
      
      // Process the payment with the nonce
      fetch(`/api/payment/orders/${orderId}/pay`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: 'authorize_net',
          token: dataValue,
          save_payment_method: false // Set to true if you want to save the card
        })
      })
      .then(response => response.json())
      .then(data => {
        if (data.status === 'completed') {
          // Payment successful
          window.location.href = `/orders/${orderId}/confirmation`;
        } else {
          // Payment failed
          console.error('Payment failed:', data);
        }
      })
      .catch(error => {
        console.error('Error processing payment:', error);
      });
    }
  }
}
```

#### Backend Flow

1. Create an order:

```
POST /api/payment/orders
```

Request:
```json
{
  "user_id": "user_123",
  "items": [
    {
      "product_id": "product_456",
      "quantity": 1,
      "unit_price_cents": 2500
    }
  ],
  "currency": "USD",
  "billing_address_id": "address_789"
}
```

Response:
```json
{
  "id": "order_123456",
  "order_number": "ORD-123456",
  "user_id": "user_123",
  "status": "pending",
  "subtotal_cents": 2500,
  "tax_cents": 0,
  "discount_cents": 0,
  "total_cents": 2500,
  "currency": "USD",
  "items": [
    {
      "product_id": "product_456",
      "quantity": 1,
      "unit_price_cents": 2500,
      "total_cents": 2500
    }
  ],
  "created_at": "2023-06-01T00:00:00Z"
}
```

2. Process the payment:

```
POST /api/payment/orders/order_123456/pay
```

Request:
```json
{
  "provider_id": "authorize_net",
  "token": "payment_nonce_from_accept_js",
  "save_payment_method": false
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
  "provider_id": "authorize_net",
  "provider_payment_id": "2345678901",
  "completed_at": "2023-06-01T00:00:00Z"
}
```

### 3. Processing a Payment with Saved Method

```javascript
async function payWithSavedMethod(orderId, paymentMethodId) {
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
    } else {
      // Payment failed
      console.error('Payment failed:', result);
    }
  } catch (error) {
    console.error('Error processing payment:', error);
  }
}
```

### 4. Setting Up Recurring Billing

Authorize.Net supports recurring billing through their Automated Recurring Billing (ARB) system, which is integrated with Native Payments.

```javascript
async function createSubscription(planId, paymentMethodId) {
  try {
    const response = await fetch('/api/payment/subscriptions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: 'current_user_id',
        product_id: planId,
        payment_method_id: paymentMethodId,
        start_date: '2023-06-01' // Optional start date
      })
    });
    
    const subscription = await response.json();
    
    if (subscription.status === 'active') {
      // Subscription created successfully
      window.location.href = '/subscriptions/confirmation';
    } else {
      // Subscription creation failed
      console.error('Subscription failed:', subscription);
    }
  } catch (error) {
    console.error('Error creating subscription:', error);
  }
}
```

## Silent Post (Webhooks)

Authorize.Net uses "Silent Post" to send notifications about transaction events. Configure your Silent Post URL in your Authorize.Net dashboard.

### Important Silent Post Parameters

- `x_response_code`: Transaction status (1 = approved, 2 = declined, 3 = error)
- `x_trans_id`: Transaction ID
- `x_subscription_id`: Subscription ID (for recurring billing)
- `x_subscription_paynum`: Payment number in the subscription series

### Silent Post Verification

Verify Silent Post requests by checking the hash value:

```javascript
app.post('/api/payment/webhooks/authorize-net', (req, res) => {
  const { x_trans_id, x_amount, x_MD5_Hash } = req.body;
  
  // Generate the hash using your API Login ID, Transaction Key, and transaction details
  const calculatedHash = generateAuthNetHash(x_trans_id, x_amount);
  
  if (calculatedHash === x_MD5_Hash) {
    // Process the webhook
    processAuthorizeNetWebhook(req.body);
    res.status(200).send('OK');
  } else {
    console.error('Invalid Silent Post hash');
    res.status(400).send('Invalid hash');
  }
});
```

## Testing

Authorize.Net provides test card numbers for different scenarios:

- `370000000000002`: American Express Test Card
- `6011000000000012`: Discover Test Card
- `5424000000000015`: Mastercard Test Card
- `4007000000027`: Visa Test Card (approved)
- `4222222222222`: Visa Test Card (declined)

## Best Practices

1. **Always use Accept.js** for collecting card information to ensure PCI compliance
2. **Verify Silent Post requests** to prevent fraudulent notifications
3. **Implement proper error handling** to provide clear feedback to users
4. **Test thoroughly** with Authorize.Net's sandbox before going live
5. **Store transaction IDs** for future reference and dispute resolution
6. **Implement AVS and CVV verification** to reduce fraud

## Common Issues and Solutions

### Issue: Payment is declined
**Solution**: Check the response code and reason. Common reasons include insufficient funds, AVS mismatch, or CVV mismatch.

### Issue: Silent Post notifications not being received
**Solution**: Verify your Silent Post URL is correctly configured and publicly accessible.

### Issue: Recurring billing failures
**Solution**: Check that the payment method is valid and has not expired. Authorize.Net will automatically retry failed recurring payments.

### Issue: Accept.js not loading
**Solution**: Ensure you're using the correct URL for the environment (sandbox vs. production).

## Additional Resources

- [Authorize.Net API Documentation](https://developer.authorize.net/api/reference/index.html)
- [Accept.js Integration Guide](https://developer.authorize.net/api/reference/features/acceptjs.html)
- [Authorize.Net Testing Guide](https://developer.authorize.net/hello_world/testing_guide.html)
- [Silent Post Integration Guide](https://developer.authorize.net/api/reference/features/webhooks.html)
