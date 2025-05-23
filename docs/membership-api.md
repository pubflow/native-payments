# Membership API Documentation

This document outlines the API endpoints for the membership system that integrates with the Native Payments framework.

## Overview

The membership API extends the Native Payments system to provide feature-based access control for your application. It allows you to:

- Define different membership tiers with specific features
- Support one-time lifetime purchases
- Manage recurring subscription options
- Implement feature-based access control
- Offer add-on purchases for individual features

## API Endpoints

### Membership Types

#### List All Membership Types

```
GET /api/payment/membership-types
```

Returns a list of all available membership types.

**Response Example:**

```json
[
  {
    "id": "basic_monthly",
    "name": "Basic Plan - Monthly",
    "description": "Access to basic content with monthly billing",
    "duration_type": "recurring",
    "duration_days": 30,
    "price_cents": 999,
    "currency": "USD",
    "features": ["streaming"]
  },
  {
    "id": "premium_monthly",
    "name": "Premium Plan - Monthly",
    "description": "Full access to all content with monthly billing",
    "duration_type": "recurring",
    "duration_days": 30,
    "price_cents": 1499,
    "currency": "USD",
    "features": ["streaming", "download", "hd"]
  },
  {
    "id": "lifetime_access",
    "name": "Lifetime Access",
    "description": "One-time payment for permanent access",
    "duration_type": "lifetime",
    "duration_days": null,
    "price_cents": 49900,
    "currency": "USD",
    "features": ["streaming", "download", "hd", "4k"]
  }
]
```

#### Get a Specific Membership Type

```
GET /api/payment/membership-types/:id
```

Returns details for a specific membership type.

**Parameters:**
- `id` (path parameter): The ID of the membership type

**Response Example:**

```json
{
  "id": "premium_monthly",
  "name": "Premium Plan - Monthly",
  "description": "Full access to all content with monthly billing",
  "duration_type": "recurring",
  "duration_days": 30,
  "price_cents": 1499,
  "currency": "USD",
  "features": ["streaming", "download", "hd"]
}
```

### User Memberships

#### List User Memberships

```
GET /api/payment/users/:userId/memberships
```

Returns all memberships for a specific user.

**Parameters:**
- `userId` (path parameter): The ID of the user

**Response Example:**

```json
[
  {
    "id": "mem_123456",
    "status": "active",
    "start_date": "2023-06-01T00:00:00Z",
    "end_date": "2023-07-01T00:00:00Z",
    "auto_renew": true,
    "subscription_id": "sub_789012",
    "order_id": null,
    "addons": [
      {
        "feature_id": "family_sharing",
        "name": "Family Sharing",
        "subscription_id": "sub_345678",
        "start_date": "2023-06-05T00:00:00Z",
        "end_date": "2023-07-05T00:00:00Z",
        "auto_renew": true
      }
    ],
    "membership_type": {
      "id": "premium_monthly",
      "name": "Premium Plan - Monthly",
      "duration_type": "recurring",
      "features": ["streaming", "download", "hd"]
    },
    "created_at": "2023-06-01T00:00:00Z"
  }
]
```

#### Get a Specific User Membership

```
GET /api/payment/users/:userId/memberships/:membershipId
```

Returns details for a specific user membership.

**Parameters:**
- `userId` (path parameter): The ID of the user
- `membershipId` (path parameter): The ID of the membership

**Response Example:**

```json
{
  "id": "mem_123456",
  "status": "active",
  "start_date": "2023-06-01T00:00:00Z",
  "end_date": "2023-07-01T00:00:00Z",
  "auto_renew": true,
  "subscription_id": "sub_789012",
  "order_id": null,
  "addons": [
    {
      "feature_id": "family_sharing",
      "name": "Family Sharing",
      "subscription_id": "sub_345678",
      "start_date": "2023-06-05T00:00:00Z",
      "end_date": "2023-07-05T00:00:00Z",
      "auto_renew": true
    }
  ],
  "membership_type": {
    "id": "premium_monthly",
    "name": "Premium Plan - Monthly",
    "duration_type": "recurring",
    "features": ["streaming", "download", "hd"]
  },
  "created_at": "2023-06-01T00:00:00Z"
}
```

#### Create a User Membership

```
POST /api/payment/users/:userId/memberships
```

Creates a new membership for a user.

**Parameters:**
- `userId` (path parameter): The ID of the user

**Request Body:**
```json
{
  "membership_type_id": "premium_monthly",
  "payment_method_id": "pm_123456"
}
```

**Response Example:**

```json
{
  "id": "mem_123456",
  "status": "active",
  "start_date": "2023-06-01T00:00:00Z",
  "end_date": "2023-07-01T00:00:00Z",
  "auto_renew": true,
  "subscription_id": "sub_789012",
  "order_id": null,
  "addons": [],
  "membership_type": {
    "id": "premium_monthly",
    "name": "Premium Plan - Monthly",
    "duration_type": "recurring",
    "features": ["streaming", "download", "hd"]
  },
  "created_at": "2023-06-01T00:00:00Z"
}
```

**Notes:**
- For recurring memberships, this endpoint creates a subscription in the payment system
- For one-time/lifetime memberships, it creates an order and processes the payment

#### Cancel a User Membership

```
POST /api/payment/users/:userId/memberships/:membershipId/cancel
```

Cancels a user's membership.

**Parameters:**
- `userId` (path parameter): The ID of the user
- `membershipId` (path parameter): The ID of the membership

**Response Example:**

```json
{
  "success": true,
  "message": "Membership cancelled successfully"
}
```

**Notes:**
- For recurring memberships, this endpoint cancels the associated subscription
- The membership status is updated to "cancelled"
- Auto-renew is set to false

### Add-ons

#### Purchase an Add-on

```
POST /api/payment/users/:userId/addons
```

Purchases an add-on feature for a user.

**Parameters:**
- `userId` (path parameter): The ID of the user

**Request Body:**
```json
{
  "feature_id": "family_sharing",
  "payment_method_id": "pm_123456",
  "is_recurring": true
}
```

**Response Example:**

```json
{
  "success": true,
  "addon": {
    "feature_id": "family_sharing",
    "name": "Family Sharing",
    "subscription_id": "sub_345678",
    "order_id": null,
    "start_date": "2023-06-05T00:00:00Z",
    "end_date": "2023-07-05T00:00:00Z",
    "auto_renew": true
  },
  "membership": {
    "id": "mem_123456",
    "status": "active",
    "addons": [
      {
        "feature_id": "family_sharing",
        "name": "Family Sharing",
        "subscription_id": "sub_345678",
        "start_date": "2023-06-05T00:00:00Z",
        "end_date": "2023-07-05T00:00:00Z",
        "auto_renew": true
      }
    ]
  }
}
```

**Notes:**
- The user must have an active membership to purchase add-ons
- For recurring add-ons, this endpoint creates a subscription
- For one-time add-ons, it creates an order and processes the payment
- The add-on is added to the user's membership in the `addons` array

### Access Verification

#### Check Feature Access

```
GET /api/payment/access/verify
```

Checks if a user has access to a specific feature.

**Query Parameters:**
- `user_id` (required): The ID of the user
- `feature_id` (required): The ID of the feature to check

**Response Example (Access Granted):**

```json
{
  "has_access": true,
  "access_source": "membership",
  "membership": {
    "id": "mem_123456",
    "type": "Premium Plan - Monthly",
    "expires": "2023-07-01T00:00:00Z"
  }
}
```

**Response Example (Access via Add-on):**

```json
{
  "has_access": true,
  "access_source": "addon",
  "addon": {
    "name": "Family Sharing",
    "expires": "2023-07-05T00:00:00Z"
  }
}
```

**Response Example (Access Denied):**

```json
{
  "has_access": false,
  "current_membership": {
    "id": "mem_123456",
    "type": "Basic Plan - Monthly"
  },
  "upgrade_options": [
    {
      "id": "premium_monthly",
      "name": "Premium Plan - Monthly",
      "price_cents": 1499,
      "currency": "USD",
      "duration_type": "recurring",
      "features": ["streaming", "download", "hd"]
    }
  ],
  "addon_options": [
    {
      "id": "hd_addon",
      "name": "HD Quality",
      "price_cents": 299,
      "currency": "USD",
      "duration_days": 30
    }
  ]
}
```

**Notes:**
- This endpoint checks if the user has access to the specified feature through any of their active memberships or add-ons
- If access is granted, it returns the source of the access (membership or add-on)
- If access is denied, it returns upgrade options and available add-ons

#### Check Membership Status

```
GET /api/payment/memberships/check
```

Checks if a user has an active membership.

**Query Parameters:**
- `user_id` (required): The ID of the user
- `membership_type_id` (optional): Specific membership type to check for

**Response Example (Has Membership):**

```json
{
  "has_active_membership": true,
  "memberships": [
    {
      "id": "mem_123456",
      "membership_type_id": "premium_monthly",
      "membership_type": {
        "id": "premium_monthly",
        "name": "Premium Plan - Monthly",
        "duration_type": "recurring",
        "features": ["streaming", "download", "hd"]
      },
      "status": "active",
      "start_date": "2023-06-01T00:00:00Z",
      "end_date": "2023-07-01T00:00:00Z",
      "is_lifetime": false,
      "auto_renew": true
    }
  ]
}
```

**Response Example (No Membership):**

```json
{
  "has_active_membership": false,
  "memberships": [],
  "available_memberships": [
    {
      "id": "basic_monthly",
      "name": "Basic Plan - Monthly",
      "price_cents": 999,
      "currency": "USD",
      "duration_type": "recurring",
      "features": ["streaming"]
    },
    {
      "id": "premium_monthly",
      "name": "Premium Plan - Monthly",
      "price_cents": 1499,
      "currency": "USD",
      "duration_type": "recurring",
      "features": ["streaming", "download", "hd"]
    }
  ]
}
```

**Notes:**
- This endpoint checks if the user has any active memberships
- If a specific membership type is provided, it checks only for that type
- If no active memberships are found, it returns available membership options

## Webhook Integration

The membership system integrates with the payment system's webhooks to handle membership-related events.

### Webhook Endpoint

```
POST /api/payment/webhooks
```

**Handled Events:**

- `subscription.renewed`: Extends the membership end date
- `subscription.payment_succeeded`: Updates membership status to active
- `subscription.cancelled`: Sets auto_renew to false
- `subscription.payment_failed`: Updates membership status to payment_failed
- `subscription.expired`: Updates membership status to expired
- `order.payment_succeeded`: Activates the membership
- `order.payment_failed`: Updates membership status to cancelled
- `order.refunded`: Updates membership status to refunded

## Data Models

### Membership Types

```json
{
  "id": "premium_monthly",
  "name": "Premium Plan - Monthly",
  "description": "Full access to all content with monthly billing",
  "duration_type": "recurring", // "recurring", "fixed", or "lifetime"
  "duration_days": 30, // null for "lifetime"
  "price_cents": 1499,
  "currency": "USD",
  "features": ["streaming", "download", "hd"], // Array of feature IDs
  "is_active": true,
  "created_at": "2023-01-01T00:00:00Z",
  "updated_at": "2023-01-01T00:00:00Z"
}
```

### User Memberships

```json
{
  "id": "mem_123456",
  "user_id": "user_789012",
  "membership_type_id": "premium_monthly",
  "subscription_id": "sub_345678", // For recurring memberships
  "order_id": null, // For one-time purchases
  "status": "active", // "active", "expired", "cancelled", "payment_failed", "refunded"
  "start_date": "2023-06-01T00:00:00Z",
  "end_date": "2023-07-01T00:00:00Z", // null for lifetime memberships
  "auto_renew": true,
  "addons": [
    {
      "feature_id": "family_sharing",
      "name": "Family Sharing",
      "subscription_id": "sub_901234",
      "order_id": null,
      "start_date": "2023-06-05T00:00:00Z",
      "end_date": "2023-07-05T00:00:00Z",
      "auto_renew": true
    }
  ],
  "created_at": "2023-06-01T00:00:00Z",
  "updated_at": "2023-06-01T00:00:00Z"
}
```

### Features Configuration

Features are defined in a configuration file with the following structure:

```json
{
  "streaming": {
    "id": "streaming",
    "name": "Streaming Access",
    "description": "Access to stream all content"
  },
  "download": {
    "id": "download",
    "name": "Download Access",
    "description": "Ability to download content for offline use"
  },
  "hd": {
    "id": "hd",
    "name": "HD Quality",
    "description": "Stream content in high definition"
  },
  "family_sharing": {
    "id": "family_sharing",
    "name": "Family Sharing",
    "description": "Share your subscription with up to 5 family members",
    "is_addon": true,
    "price_cents": 499,
    "currency": "USD",
    "duration_days": 30
  }
}
```

## Integration with Payment System

The membership system integrates with the Native Payments system in the following ways:

1. **Products**: Membership types are represented as products in the payment system
2. **Subscriptions**: Recurring memberships create and manage subscriptions
3. **Orders**: One-time/lifetime memberships create orders and process payments
4. **Webhooks**: Payment webhooks update membership status automatically

## Client Usage Examples

### Checking Feature Access

```javascript
// Example using fetch API
async function checkFeatureAccess(userId, featureId) {
  const response = await fetch(`/api/payment/access/verify?user_id=${userId}&feature_id=${featureId}`, {
    headers: {
      'Authorization': `Bearer ${userToken}`
    }
  });
  
  const data = await response.json();
  
  if (data.has_access) {
    // User has access to the feature
    return true;
  } else {
    // Show upgrade options
    showUpgradeModal(data.upgrade_options, data.addon_options);
    return false;
  }
}

// Usage
if (await checkFeatureAccess(currentUser.id, '4k')) {
  // Show 4K content
  show4KContent();
} else {
  // Show standard content
  showStandardContent();
}
```

### Purchasing a Membership

```javascript
// Example using fetch API
async function purchaseMembership(userId, membershipTypeId, paymentMethodId) {
  const response = await fetch(`/api/payment/users/${userId}/memberships`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${userToken}`
    },
    body: JSON.stringify({
      membership_type_id: membershipTypeId,
      payment_method_id: paymentMethodId
    })
  });
  
  const data = await response.json();
  
  if (response.ok) {
    // Membership created successfully
    showConfirmation(data);
  } else {
    // Handle error
    showError(data.error);
  }
}

// Usage
purchaseMembership(currentUser.id, 'premium_monthly', 'pm_123456');
```
