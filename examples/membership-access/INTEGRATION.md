# Membership System Integration with Native Payments

This document explains how the membership system integrates with the Native Payments framework to provide feature-based access control for your application.

## Overview

The membership system extends the Native Payments framework to support:

1. Different membership tiers with specific features
2. One-time lifetime purchases
3. Recurring subscription options
4. Feature-based access control
5. Add-on purchases for individual features

## Database Integration

The membership system adds two tables to the Native Payments database schema:

1. **`membership_types`**: Defines different membership plans and their included features
2. **`user_memberships`**: Tracks user memberships and purchased add-ons

These tables integrate with the existing payment tables:

- `membership_types` → `products`: Membership types are represented as products in the payment system
- `user_memberships` → `subscriptions`/`orders`: Memberships are linked to either subscriptions (for recurring) or orders (for one-time)

## API Routes Integration

The membership API routes follow the same RESTful pattern as the Native Payments API:

### Membership Types

- `GET /api/payment/membership-types`: List all membership types
- `GET /api/payment/membership-types/:id`: Get a specific membership type

### User Memberships

- `GET /api/payment/users/:userId/memberships`: List all memberships for a user
- `GET /api/payment/users/:userId/memberships/:membershipId`: Get a specific membership
- `POST /api/payment/users/:userId/memberships`: Create a new membership
- `POST /api/payment/users/:userId/memberships/:membershipId/cancel`: Cancel a membership

### Add-ons

- `POST /api/payment/users/:userId/addons`: Purchase an add-on feature

### Access Verification

- `GET /api/payment/access/verify`: Check if a user has access to a specific feature

## Payment Flow Integration

### Creating a Membership

When a user purchases a membership:

1. The client calls `POST /api/payment/users/:userId/memberships`
2. The API creates either:
   - A subscription (for recurring memberships)
   - An order (for one-time/lifetime memberships)
3. The payment is processed through the payment provider
4. A user_membership record is created with the appropriate status

```
┌─────┐          ┌─────────┐          ┌───────────────┐          ┌─────────────────┐
│User │          │Your App │          │Native Payments│          │Payment Provider │
└──┬──┘          └────┬────┘          └───────┬───────┘          └────────┬────────┘
   │  Select Plan     │                       │                           │
   │─────────────────>│                       │                           │
   │                  │                       │                           │
   │                  │  Create Membership    │                           │
   │                  │──────────────────────>│                           │
   │                  │                       │                           │
   │                  │                       │  Create Subscription      │
   │                  │                       │─────────────────────────>│
   │                  │                       │<─────────────────────────│
   │                  │                       │                           │
   │                  │  Create User Membership                           │
   │                  │──────┐                │                           │
   │                  │      │                │                           │
   │                  │<─────┘                │                           │
   │                  │                       │                           │
   │  Confirmation    │                       │                           │
   │<─────────────────│                       │                           │
   │                  │                       │                           │
```

### Webhook Processing

The payment system's webhooks are extended to handle membership-related events:

1. Payment webhooks are received at `/api/payment/webhooks`
2. The webhook handler identifies subscription or order events
3. For relevant events, it updates the associated membership status

```
┌─────────────────┐          ┌───────────────┐          ┌─────────────────┐
│Payment Provider │          │Native Payments│          │Membership System│
└────────┬────────┘          └───────┬───────┘          └────────┬────────┘
         │  Webhook Event            │                           │
         │─────────────────────────>│                           │
         │                          │                           │
         │                          │  Process Payment Event    │
         │                          │──────────────────────────>│
         │                          │                           │
         │                          │                           │  Update Membership
         │                          │                           │──────┐
         │                          │                           │      │
         │                          │                           │<─────┘
         │                          │                           │
         │                          │<──────────────────────────│
         │                          │                           │
         │  Webhook Response        │                           │
         │<─────────────────────────│                           │
         │                          │                           │
```

### Feature Access Verification

When checking if a user has access to a feature:

1. The client calls `GET /api/payment/access/verify`
2. The API checks the user's active memberships
3. It verifies if any membership includes the requested feature
4. It also checks for any purchased add-ons that provide the feature
5. The response indicates whether access is granted and provides upgrade options if not

```
┌─────┐          ┌─────────┐          ┌───────────────┐          ┌─────────────────┐
│User │          │Your App │          │Native Payments│          │Protected Content│
└──┬──┘          └────┬────┘          └───────┬───────┘          └────────┬────────┘
   │  Request Content  │                       │                           │
   │─────────────────>│                       │                           │
   │                  │                       │                           │
   │                  │  Check Feature Access │                           │
   │                  │──────────────────────>│                           │
   │                  │                       │                           │
   │                  │<──────────────────────│                           │
   │                  │                       │                           │
   │                  │  Access Granted       │                           │
   │                  │───────────────────────────────────────────────────>
   │                  │                       │                           │
   │                  │<───────────────────────────────────────────────────
   │                  │                       │                           │
   │  Content Delivery│                       │                           │
   │<─────────────────│                       │                           │
   │                  │                       │                           │
```

## Implementation Details

### Features Configuration

Features are defined in a configuration file (`features-config.js`) that specifies:

- Basic features included in memberships (streaming, downloads, HD/4K quality)
- Add-on features that can be purchased separately (family sharing, exclusive content)
- Properties for each feature (name, description, price for add-ons, duration)

```javascript
// Example feature definition
{
  'hd': {
    id: 'hd',
    name: 'HD Quality',
    description: 'Stream content in high definition'
  },
  'family_sharing': {
    id: 'family_sharing',
    name: 'Family Sharing',
    description: 'Share your subscription with up to 5 family members',
    is_addon: true,
    price_cents: 499, // $4.99
    currency: 'USD',
    duration_days: 30
  }
}
```

### Membership Types

Membership types are stored in the database with a JSON array of included features:

```javascript
{
  id: 'premium_monthly',
  name: 'Premium Plan - Monthly',
  description: 'Full access to all content with monthly billing',
  duration_type: 'recurring',
  duration_days: 30,
  price_cents: 1499, // $14.99
  currency: 'USD',
  features: ['streaming', 'download', 'hd'] // Features included in this plan
}
```

### User Memberships

User memberships track the active memberships for each user:

```javascript
{
  id: 'mem_123456',
  user_id: 'user_789',
  membership_type_id: 'premium_monthly',
  subscription_id: 'sub_456', // For recurring memberships
  order_id: null, // For one-time purchases
  status: 'active',
  start_date: '2023-06-01T00:00:00Z',
  end_date: '2023-07-01T00:00:00Z', // null for lifetime
  auto_renew: true,
  addons: [
    {
      feature_id: 'family_sharing',
      name: 'Family Sharing',
      subscription_id: 'sub_789',
      start_date: '2023-06-05T00:00:00Z',
      end_date: '2023-07-05T00:00:00Z',
      auto_renew: true
    }
  ]
}
```

## Client Integration

The client can use the membership API to:

1. List available membership types
2. Purchase memberships
3. Check feature access
4. Purchase add-ons

Example React hooks are provided for easy integration:

- `useFeatureAccess(featureId)`: Check if a user has access to a feature
- `useMembershipStatus(membershipTypeId)`: Check a user's membership status
- `FeatureGated`: Component that conditionally renders content based on feature access

## Best Practices

1. **Cache Membership Status**: Cache the user's membership status to avoid database queries on every request.
2. **Graceful Degradation**: If a user doesn't have access to a premium feature, offer a lower-quality alternative when possible.
3. **Clear Upgrade Paths**: Always provide clear information about how to upgrade when access is denied.
4. **Expiration Handling**: Proactively notify users before their membership or add-on expires.
5. **Audit Logging**: Log access attempts for security and analytics purposes.
6. **Feature Flags**: Use feature flags to gradually roll out new premium features.

## Conclusion

The membership system seamlessly integrates with the Native Payments framework to provide a complete solution for feature-based access control. By leveraging the existing payment infrastructure, it enables you to offer different membership tiers, lifetime access, and add-on features with minimal additional code.
