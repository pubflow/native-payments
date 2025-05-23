/**
 * API Integration Example
 * 
 * This file demonstrates how to integrate the membership API routes
 * with the main Native Payments API.
 */

const express = require('express');
const app = express();
const bodyParser = require('body-parser');

// Import route handlers
const paymentRoutes = require('../payment-routes');
const membershipRoutes = require('./standardized-api-routes');

// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Authentication middleware (simplified example)
const authMiddleware = (req, res, next) => {
  // In a real application, you would validate the token
  // and set req.user based on the authenticated user
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const token = authHeader.split(' ')[1];
  
  // Mock user authentication - in a real app, you would verify the token
  // and fetch the user from your database
  req.user = {
    id: req.query.user_id || req.params.userId || 'user_123',
    token: token
  };
  
  next();
};

// Apply authentication middleware to protected routes
const protectedRoutes = [
  '/api/payment/users/:userId/memberships',
  '/api/payment/users/:userId/memberships/:membershipId',
  '/api/payment/users/:userId/memberships/:membershipId/cancel',
  '/api/payment/access/verify'
];

protectedRoutes.forEach(route => {
  app.use(route, authMiddleware);
});

// Mount the payment API routes
app.use('/api/payment', paymentRoutes);

// Mount the membership API routes
app.use('/api/payment', membershipRoutes);

/**
 * Example of how the API routes work together
 * 
 * 1. User purchases a membership:
 *    POST /api/payment/users/:userId/memberships
 *    - Creates a subscription or order in the payment system
 *    - Creates a user_membership record
 * 
 * 2. Payment webhook receives an event:
 *    POST /api/payment/webhooks
 *    - Payment system processes the webhook
 *    - Updates subscription/order status
 *    - Triggers membership status update
 * 
 * 3. Application checks if user has access to a feature:
 *    GET /api/payment/access/verify?user_id=123&feature_id=hd
 *    - Checks user's memberships and addons
 *    - Returns access status and options
 */

// Webhook handler for payment events that affect memberships
app.post('/api/payment/webhooks', async (req, res) => {
  try {
    const event = req.body;
    
    // Process the webhook event
    if (event.type.startsWith('subscription.')) {
      await handleSubscriptionWebhook(event);
    } else if (event.type.startsWith('order.')) {
      await handleOrderWebhook(event);
    }
    
    res.json({ received: true });
  } catch (error) {
    console.error('Error processing webhook:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Handle subscription-related webhook events
 */
async function handleSubscriptionWebhook(event) {
  const subscriptionId = event.data.subscription.id;
  
  // Find memberships associated with this subscription
  const memberships = await db.user_memberships.findAll({
    where: { subscription_id: subscriptionId }
  });
  
  if (!memberships || memberships.length === 0) {
    console.log(`No memberships found for subscription ${subscriptionId}`);
    return;
  }
  
  const membership = memberships[0];
  const membershipType = await db.membership_types.findById(membership.membership_type_id);
  
  switch (event.type) {
    case 'subscription.renewed':
    case 'subscription.payment_succeeded':
      // Extend the membership end date
      const newEndDate = new Date();
      newEndDate.setDate(newEndDate.getDate() + membershipType.duration_days);
      
      await db.user_memberships.update(membership.id, {
        status: 'active',
        end_date: newEndDate.toISOString()
      });
      break;
      
    case 'subscription.cancelled':
      // Mark the membership to not auto-renew
      await db.user_memberships.update(membership.id, {
        auto_renew: false
      });
      break;
      
    case 'subscription.payment_failed':
      // Mark the membership as at risk
      await db.user_memberships.update(membership.id, {
        status: 'payment_failed'
      });
      break;
      
    case 'subscription.expired':
    case 'subscription.deleted':
      // Mark the membership as expired
      await db.user_memberships.update(membership.id, {
        status: 'expired'
      });
      break;
  }
}

/**
 * Handle order-related webhook events
 */
async function handleOrderWebhook(event) {
  const orderId = event.data.order.id;
  
  // Find memberships associated with this order
  const memberships = await db.user_memberships.findAll({
    where: { order_id: orderId }
  });
  
  if (!memberships || memberships.length === 0) {
    console.log(`No memberships found for order ${orderId}`);
    return;
  }
  
  const membership = memberships[0];
  
  switch (event.type) {
    case 'order.payment_succeeded':
    case 'order.completed':
      // Activate the membership
      await db.user_memberships.update(membership.id, {
        status: 'active'
      });
      break;
      
    case 'order.payment_failed':
    case 'order.cancelled':
      // Mark the membership as cancelled
      await db.user_memberships.update(membership.id, {
        status: 'cancelled'
      });
      break;
      
    case 'order.refunded':
      // Mark the membership as refunded
      await db.user_memberships.update(membership.id, {
        status: 'refunded'
      });
      break;
  }
}

/**
 * Purchase an addon for a user
 * POST /api/payment/users/:userId/addons
 */
app.post('/api/payment/users/:userId/addons', authMiddleware, async (req, res) => {
  try {
    const userId = req.params.userId;
    const { feature_id, payment_method_id, is_recurring } = req.body;
    
    // Validate required fields
    if (!feature_id) {
      return res.status(400).json({ error: 'feature_id is required' });
    }
    
    if (!payment_method_id) {
      return res.status(400).json({ error: 'payment_method_id is required' });
    }
    
    // Check if the feature exists and is an addon
    const feature = AVAILABLE_FEATURES[feature_id];
    if (!feature || !feature.is_addon) {
      return res.status(400).json({ error: 'Invalid addon feature' });
    }
    
    // Get user's active memberships
    const userMemberships = await db.user_memberships.findAll({
      where: {
        user_id: userId,
        status: 'active'
      }
    });
    
    if (!userMemberships || userMemberships.length === 0) {
      return res.status(400).json({ 
        error: 'User must have an active membership to purchase addons' 
      });
    }
    
    // Use the first active membership
    const membership = userMemberships[0];
    
    // Process the addon purchase
    let subscriptionId = null;
    let orderId = null;
    
    if (is_recurring && feature.duration_days) {
      // Create a subscription for the addon
      const productId = `addon_${feature_id}`;
      
      // Create product if it doesn't exist
      let product = await db.products.findOne({ id: productId });
      if (!product) {
        product = await db.products.create({
          id: productId,
          name: feature.name,
          description: feature.description,
          product_type: 'subscription',
          is_recurring: true,
          price_cents: feature.price_cents,
          currency: feature.currency,
          billing_interval: 'monthly',
          metadata: JSON.stringify({
            feature_id: feature_id,
            is_addon: true
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
        current_period_end: new Date(Date.now() + feature.duration_days * 24 * 60 * 60 * 1000).toISOString(),
        price_cents: feature.price_cents,
        currency: feature.currency,
        metadata: JSON.stringify({
          feature_id: feature_id,
          is_addon: true
        })
      });
      
      subscriptionId = subscription.id;
    } else {
      // Create an order for one-time addon purchase
      const order = await db.orders.create({
        id: uuidv4(),
        order_number: `ORD-${Date.now()}`,
        user_id: userId,
        status: 'pending',
        subtotal_cents: feature.price_cents,
        tax_cents: 0,
        discount_cents: 0,
        total_cents: feature.price_cents,
        currency: feature.currency,
        metadata: JSON.stringify({
          feature_id: feature_id,
          is_addon: true
        })
      });
      
      // Create order item
      await db.order_items.create({
        id: uuidv4(),
        order_id: order.id,
        product_id: `addon_${feature_id}`,
        quantity: 1,
        unit_price_cents: feature.price_cents,
        total_cents: feature.price_cents
      });
      
      // Process payment
      const payment = await db.payments.create({
        id: uuidv4(),
        order_id: order.id,
        user_id: userId,
        payment_method_id: payment_method_id,
        provider_id: 'stripe', // This should be configurable
        amount_cents: feature.price_cents,
        currency: feature.currency,
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
    
    // Update the membership with the new addon
    const startDate = new Date();
    let endDate = null;
    
    // If the addon has a duration
    if (feature.duration_days) {
      endDate = new Date();
      endDate.setDate(endDate.getDate() + feature.duration_days);
    }
    
    // Get current addons
    const addons = JSON.parse(membership.addons || '[]');
    
    // Add the new addon
    addons.push({
      feature_id: feature_id,
      name: feature.name,
      subscription_id: subscriptionId,
      order_id: orderId,
      start_date: startDate.toISOString(),
      end_date: endDate ? endDate.toISOString() : null,
      auto_renew: !!is_recurring
    });
    
    // Update the membership
    await db.user_memberships.update(membership.id, {
      addons: JSON.stringify(addons)
    });
    
    // Get the updated membership
    const updatedMembership = await db.user_memberships.findById(membership.id);
    
    res.status(201).json({
      success: true,
      addon: {
        feature_id: feature_id,
        name: feature.name,
        subscription_id: subscriptionId,
        order_id: orderId,
        start_date: startDate.toISOString(),
        end_date: endDate ? endDate.toISOString() : null,
        auto_renew: !!is_recurring
      },
      membership: updatedMembership
    });
  } catch (error) {
    console.error('Error purchasing addon:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;
