# Payment Providers Integration

Native Payments supports multiple payment providers to give you flexibility in how you process payments. This documentation provides integration guides for each supported provider.

## Supported Providers

| Provider | Features | Best For |
|----------|----------|----------|
| [Stripe](./stripe/integration-guide.md) | Credit cards, ACH, wallets, subscriptions | Global reach, modern checkout experiences |
| [Authorize.Net](./authorize-net/integration-guide.md) | Credit cards, eChecks, subscriptions | US merchants, established businesses |
| [PayPal](./paypal/integration-guide.md) | PayPal accounts, credit cards, subscriptions | Consumer-focused businesses, international sales |

## Adding a Payment Provider

To add a payment provider to your Native Payments system:

```
POST /api/payment/providers
```

Request:
```json
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

Response:
```json
{
  "id": "stripe",
  "display_name": "Stripe",
  "picture": "https://your-domain.com/images/payment-providers/stripe-logo.png",
  "is_active": true,
  "supports_subscriptions": true,
  "supports_saved_methods": true,
  "created_at": "2023-06-01T00:00:00Z",
  "updated_at": "2023-06-01T00:00:00Z"
}
```

## Common Integration Patterns

While each provider has its own specific implementation details, there are common patterns across all integrations:

### 1. Frontend Token Generation

For PCI compliance, sensitive payment information should never touch your servers. Instead:

1. The frontend collects payment information
2. The provider's JavaScript library converts it to a secure token
3. Your backend uses this token to process the payment

### 2. One-Time vs. Saved Payments

All supported providers allow for both:

- **One-time payments**: Process a payment without saving the payment method
- **Saved payments**: Save a payment method for future use

### 3. Webhook Processing

Providers send webhooks to notify your application about payment events:

1. Configure webhook endpoints in your provider dashboard
2. Verify webhook signatures to ensure they're legitimate
3. Process the events to update your database

## Provider-Specific Features

### Stripe

- Strong support for international payments
- Advanced fraud prevention
- Support for Apple Pay, Google Pay, and other wallets
- Detailed reporting and analytics

### Authorize.Net

- Established US payment processor
- Advanced fraud filters
- Support for eCheck payments
- Detailed transaction reporting

### PayPal

- Widely recognized consumer brand
- No credit card required for customers with PayPal accounts
- PayPal Credit options for customers
- Strong international presence

## Best Practices for All Providers

1. **Always use the provider's frontend libraries** for collecting payment information
2. **Verify webhook signatures** to prevent fraudulent requests
3. **Implement proper error handling** with user-friendly messages
4. **Test thoroughly** in sandbox environments before going live
5. **Store transaction IDs** for future reference and dispute resolution
6. **Implement proper logging** for debugging payment issues

## Choosing the Right Provider

Consider these factors when choosing a payment provider:

1. **Geographic coverage**: Where are your customers located?
2. **Fees**: What are the transaction fees and monthly costs?
3. **Features**: Do you need subscriptions, saved cards, or specific payment methods?
4. **Integration complexity**: How easy is it to integrate with your stack?
5. **Reporting**: What kind of reporting and analytics do you need?

## Using Multiple Providers

Native Payments supports using multiple providers simultaneously. This can be useful for:

1. **Redundancy**: If one provider has an outage, you can fall back to another
2. **Geographic optimization**: Use different providers in different regions
3. **Cost optimization**: Route transactions to the provider with the lowest fees
4. **Feature access**: Use specific providers for specific features

To implement multiple providers:

1. Configure each provider in your Native Payments system
2. When creating a payment intent or processing a payment, specify the provider_id
3. Implement provider-specific UI for each supported provider

## Testing Providers

Each provider offers a sandbox/test environment:

- **Stripe**: Use test API keys and [test card numbers](https://stripe.com/docs/testing)
- **Authorize.Net**: Use the sandbox environment and [test card numbers](https://developer.authorize.net/hello_world/testing_guide.html)
- **PayPal**: Use sandbox accounts and the [sandbox environment](https://developer.paypal.com/docs/api-basics/sandbox/)

## Troubleshooting Common Issues

### Payment Declined

- Check the error message from the provider
- Verify the card information is correct
- Check if the card has sufficient funds
- Verify the billing address matches the card

### Webhook Not Received

- Ensure your webhook endpoint is publicly accessible
- Verify the webhook URL is correctly configured in the provider dashboard
- Check your server logs for any errors processing the webhook

### Subscription Creation Fails

- Verify the payment method is valid and not expired
- Check that the customer has sufficient funds
- Ensure the subscription plan is correctly configured

### 3D Secure Authentication Fails

- Ensure you're correctly handling the authentication flow
- Check if the card issuer supports 3D Secure
- Verify the customer completed the authentication process

## Additional Resources

- [PCI Compliance Guide](https://www.pcisecuritystandards.org/pci_security/)
- [Strong Customer Authentication (SCA) Guide](https://stripe.com/docs/strong-customer-authentication)
- [Payment Processing Best Practices](https://www.authorize.net/content/dam/authorize/documents/best-practices-guide.pdf)
