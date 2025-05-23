# Native Payments

A modular, multi-provider payment system that supports various business models including SaaS, eCommerce, and digital stores. This system provides a consistent API interface regardless of the underlying payment provider (Stripe, PayPal, Authorize.net, etc.).

**Developed and maintained by the Pubflow team. Licensed under MIT. Contributions welcome!**

## Why Native Payments?

Native Payments is designed to be both powerful and adaptable to your needs:

- **Start Simple, Scale Big**: Begin with basic payment processing and easily expand to complex subscription models as your business grows.

- **Provider Independence**: Never be locked into a single payment provider. Switch between Stripe, PayPal, or Authorize.Net without changing your application code.

- **Global Ready**: Accept payments in multiple currencies and through regional payment methods to reach customers worldwide.

- **Business Model Flexibility**: Whether you're running a SaaS platform, e-commerce store, marketplace, or content subscription service, Native Payments adapts to your business model.

- **Developer Friendly**: Clean, consistent API that makes sense. Extensive documentation and examples get you up and running quickly.

- **Production Tested**: Built on battle-tested patterns used by companies processing millions in transactions.

Native Payments gives you the robustness of enterprise payment infrastructure with the flexibility to implement exactly what your business needs.

## Features

- **Multi-Provider Support**: Integrate with multiple payment providers through a unified API
- **Flexible Business Models**: Support for one-time payments, subscriptions, and more
- **Customer Management**: Create and manage customers across payment providers
- **Payment Method Management**: Securely store and manage payment methods
- **Order Processing**: Create and process orders with multiple items
- **Subscription Management**: Create, update, and cancel subscriptions
- **Membership System**: Control access to features based on payment status
  - Feature-based access control
  - Lifetime access options
  - Free/premium tiers
  - Trial periods with automatic conversion
- **Webhook Handling**: Process provider webhooks for real-time updates
- **Extensible Architecture**: Easily add new payment providers or features

## Coming Soon

- **Analytics & Reporting Dashboard** (Coming Soon)
  - Revenue metrics and financial reporting
  - Subscription analytics (MRR, churn, LTV)
  - Membership insights and feature usage
  - Customer segmentation and behavior analysis
  - Customizable dashboards and export options

## Documentation

- [Database Schema](./docs/database-schema.md): Database tables and relationships
- [API Routes](./docs/api-routes.md): REST API endpoints and request/response formats
- [Implementation Guide](./docs/implementation-guide.md): Step-by-step guide for implementing the payment system
- [Provider Integration](./docs/providers/index.md): Detailed instructions for integrating specific payment providers
- [Membership System](./docs/membership-api.md): Guide to implementing feature-based access control
- [Examples](./docs/examples/index.md): Example implementations for different business models

## Database Structure

The payment system uses the following core tables:

- **Users & Organizations**: Enhanced user tables with organization support
- **Payment Providers**: Configuration for different payment providers
- **Provider Customers**: Customer records in payment providers
- **Payment Methods**: Saved payment methods for users/organizations
- **Products**: Products or subscription plans
- **Orders & Order Items**: Order management
- **Payments**: Payment processing and tracking
- **Subscriptions**: Subscription management
- **Invoices**: Invoice generation and tracking
- **Webhooks & Events**: Webhook processing and event tracking
- **Membership Types**: Defines different membership plans and their included features
- **User Memberships**: Tracks user memberships and purchased add-ons
- **Addresses**: Stores billing and shipping addresses

## API Overview

The payment system provides a RESTful API with the following main endpoints:

- `/api/payment/customers`: Customer management
- `/api/payment/methods`: Payment method management
- `/api/payment/intents`: Payment intent processing
- `/api/payment/orders`: Order management
- `/api/payment/subscriptions`: Subscription management
- `/api/payment/webhooks`: Webhook handling
- `/api/payment/addresses`: Address management
- `/api/payment/membership-types`: Membership plan management
- `/api/payment/users/:userId/memberships`: User membership management
- `/api/payment/users/:userId/addons`: Add-on feature purchases
- `/api/payment/access/verify`: Feature access verification

**Coming Soon:**
- `/api/payment/analytics/*`: Analytics and reporting endpoints for revenue metrics, subscription insights, and customer behavior

## Implementation

The payment system follows a layered architecture:

1. **API Layer**: Standardized REST endpoints
2. **Service Layer**: Business logic and provider-agnostic operations
3. **Provider Layer**: Provider-specific implementations
4. **Data Layer**: Database operations

This architecture allows for:

- **Abstraction**: Hide provider-specific details behind a consistent interface
- **Flexibility**: Switch between providers without changing client code
- **Extensibility**: Add new providers or features without major changes

## Supported Payment Providers

- **Stripe**: Full support for payments, subscriptions, and saved payment methods
- **PayPal**: Support for payments and subscriptions
- **Authorize.net**: Support for payments and saved payment methods
- **Square**: Support for payments (coming soon)

## Additional Features

- **Analytics Dashboard**: Comprehensive reporting and insights (coming soon)
  - Revenue tracking and financial metrics
  - Subscription analytics (MRR, churn, LTV)
  - Customer segmentation and behavior analysis
  - Customizable reports and data exports

## Security Considerations

The payment system follows industry best practices for security:

- **PCI Compliance**: Never stores raw credit card data
- **API Key Security**: Securely stores provider API keys
- **Webhook Validation**: Validates webhook signatures to prevent fraud
- **HTTPS**: All payment endpoints use HTTPS
- **Input Validation**: Validates all input data before processing

## Getting Started

1. Set up the database tables as defined in the [database schema](./docs/database-schema.md)
2. Implement the provider interfaces for your chosen payment providers
3. Create the service layer to handle business logic
4. Implement the API endpoints as defined in the [API routes documentation](./docs/api-routes.md)
5. Set up webhook handling for real-time updates

For detailed implementation instructions, see the [implementation guide](./docs/implementation-guide.md).

## Provider-Specific Setup

### Stripe

1. Create a Stripe account and get API keys
2. Install the Stripe SDK: `npm install stripe`
3. Implement the Stripe provider interface
4. Set up webhook endpoints and configure in Stripe dashboard

### PayPal

1. Create a PayPal Developer account and get API credentials
2. Install the PayPal SDK: `npm install @paypal/checkout-server-sdk`
3. Implement the PayPal provider interface
4. Set up IPN (Instant Payment Notification) for webhooks

### Authorize.net

1. Create an Authorize.net account and get API credentials
2. Install the Authorize.net SDK: `npm install authorizenet`
3. Implement the Authorize.net provider interface
4. Set up webhook endpoints

## Example Usage

### Creating a Customer

```typescript
// Create a customer with Stripe
const customerData = {
  user_id: 'user_123',
  provider_id: 'stripe',
  email: 'customer@example.com',
  name: 'John Doe'
};

const customer = await paymentService.createCustomer(customerData);
```

### Processing a Payment

```typescript
// Process a payment for an order
const paymentData = {
  order_id: 'order_123',
  payment_method_id: 'pm_123',
  amount_cents: 2000,
  currency: 'USD'
};

const paymentIntent = await paymentService.createPaymentIntent(paymentData);
```

### Creating a Subscription

```typescript
// Create a subscription
const subscriptionData = {
  user_id: 'user_123',
  product_id: 'prod_123',
  payment_method_id: 'pm_123'
};

const subscription = await paymentService.createSubscription(subscriptionData);
```

### Creating a Membership

```typescript
// Create a membership for a user
const membershipData = {
  user_id: 'user_123',
  membership_type_id: 'premium_monthly',
  payment_method_id: 'pm_123'
};

const membership = await paymentService.createMembership(membershipData);
```

### Checking Feature Access

```typescript
// Check if a user has access to a specific feature
const accessParams = {
  user_id: 'user_123',
  feature_id: 'hd_streaming'
};

const accessResult = await paymentService.checkFeatureAccess(accessParams);

if (accessResult.has_access) {
  // User has access to the feature
  serveHDContent();
} else {
  // User doesn't have access, show upgrade options
  showUpgradeOptions(accessResult.upgrade_options);
}
```

## Contributing

We welcome contributions from developers of all skill levels! Whether you're fixing a bug, adding a feature, or improving documentation, your help makes Native Payments better for everyone.

Here's how you can contribute:

1. **Report Issues**: Found a bug or have a feature request? Open an issue on our repository.
2. **Submit Pull Requests**: Have a fix or enhancement? Fork the repo, make your changes, and submit a PR.
3. **Improve Documentation**: Help us make our docs clearer and more comprehensive.
4. **Share Examples**: Built something cool with Native Payments? Share your implementation examples.
5. **Spread the Word**: Star our repository and tell others about Native Payments.

Check out our [Contributing Guide](./CONTRIBUTING.md) for more detailed instructions.

## License

Native Payments is open source software licensed under the MIT License.

```
MIT License

Copyright (c) 2023 Pubflow Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<p align="center">
  <b>Built with ❤️ by the Pubflow Team</b><br>
  <a href="https://pubflow.com">https://pubflow.com</a>
</p>
