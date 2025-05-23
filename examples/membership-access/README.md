# Membership Access Implementation

This example demonstrates how to implement a membership access system using the Native Payments framework. It shows how to verify user access to features based on their membership status, including support for lifetime memberships.

## Use Case

A platform that offers:
- Different membership tiers with specific features
- One-time lifetime purchases
- Recurring subscription options
- Feature-based access control

## Implementation Overview

### 1. Features Configuration

First, define your available features in a configuration file:

```javascript
// features-config.js
const AVAILABLE_FEATURES = {
  // Basic features
  'streaming': {
    id: 'streaming',
    name: 'Streaming Access',
    description: 'Access to stream all content'
  },
  'download': {
    id: 'download',
    name: 'Download Access',
    description: 'Ability to download content for offline use'
  },
  'hd': {
    id: 'hd',
    name: 'HD Quality',
    description: 'Stream content in high definition'
  },
  '4k': {
    id: '4k',
    name: '4K Quality',
    description: 'Stream content in ultra high definition'
  },
  
  // Addon features
  'family_sharing': {
    id: 'family_sharing',
    name: 'Family Sharing',
    description: 'Share your subscription with up to 5 family members',
    is_addon: true,
    price_cents: 499, // $4.99
    currency: 'USD',
    duration_days: 30
  },
  'exclusive_content': {
    id: 'exclusive_content',
    name: 'Exclusive Content',
    description: 'Access to exclusive premium content',
    is_addon: true,
    price_cents: 299, // $2.99
    currency: 'USD',
    duration_days: 30
  },
  'lifetime_downloads': {
    id: 'lifetime_downloads',
    name: 'Lifetime Downloads',
    description: 'Permanent access to download all content',
    is_addon: true,
    price_cents: 9900, // $99.00
    currency: 'USD',
    duration_days: null // null indicates permanent
  }
};

module.exports = { AVAILABLE_FEATURES };
```

### 2. Membership Types Setup

Configure your membership types with the features they include:

```javascript
// Setup membership types
const membershipTypes = [
  {
    id: 'basic_monthly',
    name: 'Basic Plan - Monthly',
    description: 'Access to basic content with monthly billing',
    duration_type: 'recurring',
    duration_days: 30,
    price_cents: 999, // $9.99
    currency: 'USD',
    features: JSON.stringify(['streaming']) // Only streaming basic
  },
  {
    id: 'premium_monthly',
    name: 'Premium Plan - Monthly',
    description: 'Full access to all content with monthly billing',
    duration_type: 'recurring',
    duration_days: 30,
    price_cents: 1499, // $14.99
    currency: 'USD',
    features: JSON.stringify(['streaming', 'download', 'hd']) // Streaming, downloads and HD
  },
  {
    id: 'premium_yearly',
    name: 'Premium Plan - Yearly',
    description: 'Full access to all content with yearly billing (save 16%)',
    duration_type: 'recurring',
    duration_days: 365,
    price_cents: 14990, // $149.90
    currency: 'USD',
    features: JSON.stringify(['streaming', 'download', 'hd'])
  },
  {
    id: 'lifetime_access',
    name: 'Lifetime Access',
    description: 'One-time payment for permanent access to all current and future content',
    duration_type: 'lifetime',
    duration_days: null, // No expiration
    price_cents: 49900, // $499.00
    currency: 'USD',
    features: JSON.stringify(['streaming', 'download', 'hd', '4k']) // Everything included
  }
];

// Create membership types in your database
for (const membershipType of membershipTypes) {
  await db.membership_types.create(membershipType);
}
```

### 3. API Endpoint for Checking Membership Access

```javascript
// routes/membership.js
const express = require('express');
const router = express.Router();
const { AVAILABLE_FEATURES } = require('../config/features-config');

// Middleware to verify user authentication
const authMiddleware = require('../middleware/auth');

/**
 * Check if a user has access to a specific feature
 * GET /api/payment/features/check?feature_id=feature_name
 */
router.get('/features/check', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const featureId = req.query.feature_id;
    
    if (!featureId) {
      return res.status(400).json({ error: 'Missing feature_id parameter' });
    }
    
    // Check if the feature exists
    if (!AVAILABLE_FEATURES[featureId]) {
      return res.status(404).json({ error: 'Feature not found' });
    }
    
    const feature = AVAILABLE_FEATURES[featureId];
    
    // Get user's active memberships
    const userMemberships = await db.user_memberships.findAll({
      where: {
        user_id: userId,
        status: 'active'
      }
    });
    
    if (!userMemberships || userMemberships.length === 0) {
      // User has no active memberships
      return res.json({
        has_access: false,
        reason: 'No active membership',
        available_memberships: await getAvailableMembershipsWithFeature(featureId)
      });
    }
    
    // Check each membership for access to the feature
    const now = new Date();
    
    for (const membership of userMemberships) {
      // Get membership type details
      const membershipType = await db.membership_types.findById(membership.membership_type_id);
      
      // Check if membership has expired (except lifetime memberships)
      if (membershipType.duration_type !== 'lifetime' && membership.end_date) {
        const endDate = new Date(membership.end_date);
        if (endDate < now) {
          // Update membership status to expired
          await db.user_memberships.update(membership.id, { status: 'expired' });
          continue; // Skip to next membership
        }
      }
      
      // Check if membership includes the requested feature
      const includedFeatures = JSON.parse(membershipType.features || '[]');
      if (includedFeatures.includes(featureId)) {
        return res.json({
          has_access: true,
          access_source: 'membership',
          membership: {
            id: membership.id,
            type: membershipType.name,
            expires: membership.end_date || 'never'
          }
        });
      }
      
      // Check if user has purchased this feature as an addon
      const addons = JSON.parse(membership.addons || '[]');
      const matchingAddon = addons.find(addon => addon.feature_id === featureId);
      
      if (matchingAddon) {
        // Check if addon is still valid
        if (!matchingAddon.end_date || new Date(matchingAddon.end_date) > now) {
          return res.json({
            has_access: true,
            access_source: 'addon',
            addon: {
              name: matchingAddon.name,
              expires: matchingAddon.end_date || 'never'
            }
          });
        }
      }
    }
    
    // If we get here, user doesn't have access to the feature
    // Return available options for upgrade
    const currentMembership = userMemberships[0]; // First active membership
    const currentMembershipType = await db.membership_types.findById(currentMembership.membership_type_id);
    
    return res.json({
      has_access: false,
      current_membership: {
        id: currentMembership.id,
        type: currentMembershipType.name
      },
      upgrade_options: await getAvailableMembershipsWithFeature(featureId),
      addon_options: feature.is_addon ? [feature] : []
    });
    
  } catch (error) {
    console.error('Error checking feature access:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Helper function to get available memberships that include a feature
 */
async function getAvailableMembershipsWithFeature(featureId) {
  const allMembershipTypes = await db.membership_types.findAll({
    where: { is_active: true }
  });
  
  return allMembershipTypes
    .filter(type => {
      const features = JSON.parse(type.features || '[]');
      return features.includes(featureId);
    })
    .map(type => ({
      id: type.id,
      name: type.name,
      price_cents: type.price_cents,
      currency: type.currency,
      duration_type: type.duration_type,
      features: JSON.parse(type.features || '[]')
    }));
}

module.exports = router;
```

### 4. Middleware for Protecting Routes

```javascript
// middleware/feature-access.js

const { AVAILABLE_FEATURES } = require('../config/features-config');

/**
 * Middleware to check if a user has access to a specific feature
 * @param {string} featureId - The ID of the feature to check
 */
function requireFeatureAccess(featureId) {
  return async (req, res, next) => {
    try {
      const userId = req.user.id;
      
      // Call the feature check function
      const response = await fetch(`${process.env.API_BASE_URL}/api/payment/features/check?feature_id=${featureId}`, {
        headers: {
          'Authorization': req.headers.authorization
        }
      });
      
      const result = await response.json();
      
      if (result.has_access) {
        // User has access, continue to the route handler
        next();
      } else {
        // User doesn't have access
        res.status(403).json({
          error: 'Access denied',
          reason: result.reason || 'Your membership does not include this feature',
          upgrade_options: result.upgrade_options,
          addon_options: result.addon_options
        });
      }
    } catch (error) {
      console.error('Error in feature access middleware:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  };
}

module.exports = { requireFeatureAccess };
```

### 5. Using the Middleware in Routes

```javascript
// routes/content.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { requireFeatureAccess } = require('../middleware/feature-access');

// Route that requires HD streaming access
router.get('/videos/:id/hd', 
  authMiddleware,
  requireFeatureAccess('hd'),
  async (req, res) => {
    // User has access to HD content
    const videoId = req.params.id;
    const hdStreamUrl = await generateHDStreamUrl(videoId);
    
    res.json({
      video_id: videoId,
      stream_url: hdStreamUrl,
      quality: 'hd',
      expires_in: 3600 // 1 hour
    });
  }
);

// Route that requires 4K streaming access
router.get('/videos/:id/4k', 
  authMiddleware,
  requireFeatureAccess('4k'),
  async (req, res) => {
    // User has access to 4K content
    const videoId = req.params.id;
    const fourKStreamUrl = await generate4KStreamUrl(videoId);
    
    res.json({
      video_id: videoId,
      stream_url: fourKStreamUrl,
      quality: '4k',
      expires_in: 3600 // 1 hour
    });
  }
);

module.exports = router;
```

## Sequence Diagram

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

## Best Practices

1. **Cache Membership Status**: Cache the user's membership status to avoid database queries on every request.
2. **Graceful Degradation**: If a user doesn't have access to a premium feature, offer a lower-quality alternative when possible.
3. **Clear Upgrade Paths**: Always provide clear information about how to upgrade when access is denied.
4. **Expiration Handling**: Proactively notify users before their membership or addon expires.
5. **Audit Logging**: Log access attempts for security and analytics purposes.
6. **Feature Flags**: Use feature flags to gradually roll out new premium features.

## Common Issues and Solutions

1. **Performance Concerns**: Use Redis or another caching solution to store membership status and feature access.
2. **Subscription Sync Issues**: Implement webhook handlers to immediately update membership status when payment events occur.
3. **Lifetime Access Management**: Ensure lifetime memberships are properly flagged and never expire.
4. **Feature Granularity**: Balance between too many and too few features for clear membership tiers.
5. **Addon Management**: Provide a clear UI for users to manage their purchased addons.
