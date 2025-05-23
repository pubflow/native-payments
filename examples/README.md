# Native Payments - Implementation Examples

This directory contains practical examples of how to implement the Native Payments system for various business models and use cases. Each example demonstrates a complete payment flow from start to finish.

## Available Examples

1. [SaaS Subscription](./saas-subscription/README.md) - Implementing recurring subscriptions for a SaaS product
2. [E-Commerce Store](./ecommerce-store/README.md) - Processing one-time payments for an online store
3. [Marketplace](./marketplace/README.md) - Handling payments between buyers and sellers in a marketplace
4. [Digital Downloads](./digital-downloads/README.md) - Selling digital products with instant delivery
5. [Donation Platform](./donation-platform/README.md) - Processing donations with variable amounts

## How to Use These Examples

Each example includes:

- A detailed README explaining the payment flow
- Code snippets for both backend and frontend implementation
- Sequence diagrams showing the interaction between components
- Sample API requests and responses

These examples are designed to be educational and can be adapted to your specific needs. They demonstrate best practices for implementing secure, reliable payment processing using the Native Payments system.

## Common Patterns

While each business model has unique requirements, there are common patterns that apply across all payment implementations:

1. **Customer Creation** - Creating and managing customer records
2. **Payment Method Management** - Securely collecting and storing payment methods
3. **Payment Processing** - Creating payment intents and handling the payment flow
4. **Webhook Handling** - Processing asynchronous events from payment providers
5. **Error Handling** - Gracefully handling payment failures and edge cases

## Getting Started

To get started, choose the example that most closely matches your business model and follow the implementation guide. You can mix and match components from different examples to create a custom solution for your specific needs.

If you have questions or need further assistance, please refer to the main [Native Payments documentation](../README.md).
