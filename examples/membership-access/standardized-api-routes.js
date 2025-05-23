/**
 * Standardized Membership API Routes
 * 
 * This file contains standardized API routes for the membership system
 * that align with the Native Payments API structure.
 */

const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const { AVAILABLE_FEATURES } = require('./features-config');

/**
 * Get all membership types
 * GET /api/payment/membership-types
 */
router.get('/membership-types', async (req, res) => {
  try {
    const membershipTypes = await db.membership_types.findAll({
      where: { is_active: true }
    });
    
    // Format the response
    const formattedTypes = membershipTypes.map(type => ({
      id: type.id,
      name: type.name,
      description: type.description,
      duration_type: type.duration_type,
      duration_days: type.duration_days,
      price_cents: type.price_cents,
      currency: type.currency,
      features: JSON.parse(type.features || '[]')
    }));
    
    res.json(formattedTypes);
  } catch (error) {
    console.error('Error fetching membership types:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get a specific membership type
 * GET /api/payment/membership-types/:id
 */
router.get('/membership-types/:id', async (req, res) => {
  try {
    const membershipType = await db.membership_types.findById(req.params.id);
    
    if (!membershipType) {
      return res.status(404).json({ error: 'Membership type not found' });
    }
    
    // Format the response
    const formattedType = {
      id: membershipType.id,
      name: membershipType.name,
      description: membershipType.description,
      duration_type: membershipType.duration_type,
      duration_days: membershipType.duration_days,
      price_cents: membershipType.price_cents,
      currency: membershipType.currency,
      features: JSON.parse(membershipType.features || '[]')
    };
    
    res.json(formattedType);
  } catch (error) {
    console.error('Error fetching membership type:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get user memberships
 * GET /api/payment/users/:userId/memberships
 */
router.get('/users/:userId/memberships', async (req, res) => {
  try {
    const userId = req.params.userId;
    
    // Check if user exists
    const user = await db.users.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Get all memberships for the user
    const userMemberships = await db.user_memberships.findAll({
      where: { user_id: userId }
    });
    
    // Get membership types for each membership
    const membershipsWithTypes = await Promise.all(
      userMemberships.map(async (membership) => {
        const membershipType = await db.membership_types.findById(membership.membership_type_id);
        return {
          id: membership.id,
          status: membership.status,
          start_date: membership.start_date,
          end_date: membership.end_date,
          auto_renew: membership.auto_renew,
          subscription_id: membership.subscription_id,
          order_id: membership.order_id,
          addons: JSON.parse(membership.addons || '[]'),
          membership_type: {
            id: membershipType.id,
            name: membershipType.name,
            duration_type: membershipType.duration_type,
            features: JSON.parse(membershipType.features || '[]')
          },
          created_at: membership.created_at
        };
      })
    );
    
    res.json(membershipsWithTypes);
  } catch (error) {
    console.error('Error fetching user memberships:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Get a specific user membership
 * GET /api/payment/users/:userId/memberships/:membershipId
 */
router.get('/users/:userId/memberships/:membershipId', async (req, res) => {
  try {
    const { userId, membershipId } = req.params;
    
    // Check if user exists
    const user = await db.users.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Get the membership
    const membership = await db.user_memberships.findOne({
      where: {
        id: membershipId,
        user_id: userId
      }
    });
    
    if (!membership) {
      return res.status(404).json({ error: 'Membership not found' });
    }
    
    // Get the membership type
    const membershipType = await db.membership_types.findById(membership.membership_type_id);
    
    // Format the response
    const formattedMembership = {
      id: membership.id,
      status: membership.status,
      start_date: membership.start_date,
      end_date: membership.end_date,
      auto_renew: membership.auto_renew,
      subscription_id: membership.subscription_id,
      order_id: membership.order_id,
      addons: JSON.parse(membership.addons || '[]'),
      membership_type: {
        id: membershipType.id,
        name: membershipType.name,
        duration_type: membershipType.duration_type,
        features: JSON.parse(membershipType.features || '[]')
      },
      created_at: membership.created_at
    };
    
    res.json(formattedMembership);
  } catch (error) {
    console.error('Error fetching user membership:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Create a new membership for a user
 * POST /api/payment/users/:userId/memberships
 */
router.post('/users/:userId/memberships', async (req, res) => {
  try {
    const userId = req.params.userId;
    const { membership_type_id, payment_method_id } = req.body;
    
    // Validate required fields
    if (!membership_type_id) {
      return res.status(400).json({ error: 'membership_type_id is required' });
    }
    
    if (!payment_method_id) {
      return res.status(400).json({ error: 'payment_method_id is required' });
    }
    
    // Check if user exists
    const user = await db.users.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Get the membership type
    const membershipType = await db.membership_types.findById(membership_type_id);
    if (!membershipType) {
      return res.status(404).json({ error: 'Membership type not found' });
    }
    
    // Create the appropriate payment entity based on membership type
    let subscriptionId = null;
    let orderId = null;
    
    if (membershipType.duration_type === 'recurring') {
      // Create a subscription for recurring memberships
      const productId = `membership_${membership_type_id}`;
      
      // Check if product exists, create if not
      let product = await db.products.findOne({ id: productId });
      if (!product) {
        product = await db.products.create({
          id: productId,
          name: membershipType.name,
          description: membershipType.description,
          product_type: 'subscription',
          is_recurring: true,
          price_cents: membershipType.price_cents,
          currency: membershipType.currency,
          billing_interval: membershipType.duration_days === 30 ? 'monthly' : 'yearly',
          metadata: JSON.stringify({
            membership_type_id: membership_type_id
          })
        });
      }
      
      // Create the subscription
      const subscription = await db.subscriptions.create({
        id: uuidv4(),
        user_id: userId,
        product_id: productId,
        payment_method_id: payment_method_id,
        provider_id: 'stripe', // This should be configurable
        status: 'active',
        current_period_start: new Date().toISOString(),
        current_period_end: new Date(Date.now() + membershipType.duration_days * 24 * 60 * 60 * 1000).toISOString(),
        price_cents: membershipType.price_cents,
        currency: membershipType.currency,
        metadata: JSON.stringify({
          membership_type_id: membership_type_id
        })
      });
      
      subscriptionId = subscription.id;
    } else {
      // Create an order for one-time purchases (like lifetime memberships)
      const order = await db.orders.create({
        id: uuidv4(),
        order_number: `ORD-${Date.now()}`,
        user_id: userId,
        status: 'pending',
        subtotal_cents: membershipType.price_cents,
        tax_cents: 0,
        discount_cents: 0,
        total_cents: membershipType.price_cents,
        currency: membershipType.currency,
        metadata: JSON.stringify({
          membership_type_id: membership_type_id
        })
      });
      
      // Create order item
      await db.order_items.create({
        id: uuidv4(),
        order_id: order.id,
        product_id: `membership_${membership_type_id}`,
        quantity: 1,
        unit_price_cents: membershipType.price_cents,
        total_cents: membershipType.price_cents
      });
      
      // Process payment
      const payment = await db.payments.create({
        id: uuidv4(),
        order_id: order.id,
        user_id: userId,
        payment_method_id: payment_method_id,
        provider_id: 'stripe', // This should be configurable
        amount_cents: membershipType.price_cents,
        currency: membershipType.currency,
        status: 'completed',
        completed_at: new Date().toISOString()
      });
      
      // Update order status
      await db.orders.update(order.id, {
        status: 'paid',
        completed_at: new Date().toISOString()
      });
      
      orderId = order.id;
    }
    
    // Calculate end date (null for lifetime)
    let endDate = null;
    if (membershipType.duration_type !== 'lifetime') {
      endDate = new Date(Date.now() + membershipType.duration_days * 24 * 60 * 60 * 1000).toISOString();
    }
    
    // Create the user membership
    const membership = await db.user_memberships.create({
      id: uuidv4(),
      user_id: userId,
      membership_type_id: membership_type_id,
      subscription_id: subscriptionId,
      order_id: orderId,
      status: 'active',
      start_date: new Date().toISOString(),
      end_date: endDate,
      auto_renew: membershipType.duration_type === 'recurring',
      addons: '[]'
    });
    
    // Get the created membership with type
    const membershipWithType = {
      ...membership,
      membership_type: {
        id: membershipType.id,
        name: membershipType.name,
        duration_type: membershipType.duration_type,
        features: JSON.parse(membershipType.features || '[]')
      }
    };
    
    res.status(201).json(membershipWithType);
  } catch (error) {
    console.error('Error creating membership:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Cancel a user membership
 * POST /api/payment/users/:userId/memberships/:membershipId/cancel
 */
router.post('/users/:userId/memberships/:membershipId/cancel', async (req, res) => {
  try {
    const { userId, membershipId } = req.params;
    
    // Check if user exists
    const user = await db.users.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Get the membership
    const membership = await db.user_memberships.findOne({
      where: {
        id: membershipId,
        user_id: userId
      }
    });
    
    if (!membership) {
      return res.status(404).json({ error: 'Membership not found' });
    }
    
    // If it's a recurring membership, cancel the subscription
    if (membership.subscription_id) {
      const subscription = await db.subscriptions.findById(membership.subscription_id);
      
      if (subscription) {
        await db.subscriptions.update(subscription.id, {
          status: 'cancelled',
          cancel_at_period_end: true
        });
      }
    }
    
    // Update the membership
    await db.user_memberships.update(membershipId, {
      status: 'cancelled',
      auto_renew: false
    });
    
    res.json({ success: true, message: 'Membership cancelled successfully' });
  } catch (error) {
    console.error('Error cancelling membership:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Check if a user has access to a feature
 * GET /api/payment/access/verify
 * 
 * Query parameters:
 * - user_id: The ID of the user to check
 * - feature_id: The ID of the feature to check
 */
router.get('/access/verify', async (req, res) => {
  try {
    const userId = req.query.user_id;
    const featureId = req.query.feature_id;
    
    // Validate required parameters
    if (!userId) {
      return res.status(400).json({ error: 'Missing user_id parameter' });
    }
    
    if (!featureId) {
      return res.status(400).json({ error: 'Missing feature_id parameter' });
    }
    
    // Check if the user exists
    const user = await db.users.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
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
