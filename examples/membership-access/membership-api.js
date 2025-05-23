/**
 * Membership API Implementation
 * 
 * This file contains the implementation of the membership access API endpoints
 * for checking user access to features based on their membership status.
 */

const express = require('express');
const router = express.Router();

// Import the features configuration
const { AVAILABLE_FEATURES } = require('./features-config');

/**
 * Check if a user has access to a specific feature
 * GET /api/payment/features/check
 * 
 * Query parameters:
 * - user_id: The ID of the user to check
 * - feature_id: The ID of the feature to check
 * 
 * Response:
 * - has_access: Boolean indicating if the user has access to the feature
 * - access_source: 'membership' or 'addon' if has_access is true
 * - membership: Details about the membership if access_source is 'membership'
 * - addon: Details about the addon if access_source is 'addon'
 * - upgrade_options: Available memberships that include the feature if has_access is false
 * - addon_options: Available addons for the feature if has_access is false
 */
router.get('/features/check', async (req, res) => {
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

/**
 * Verify if a user has an active membership
 * GET /api/payment/memberships/check
 * 
 * Query parameters:
 * - user_id: The ID of the user to check
 * - membership_type_id: (Optional) Specific membership type to check for
 * 
 * Response:
 * - has_active_membership: Boolean indicating if the user has an active membership
 * - memberships: Array of active memberships if has_active_membership is true
 * - available_memberships: Array of available memberships if has_active_membership is false
 */
router.get('/memberships/check', async (req, res) => {
  try {
    const userId = req.query.user_id;
    const specificMembershipTypeId = req.query.membership_type_id;
    
    // Validate required parameters
    if (!userId) {
      return res.status(400).json({ error: 'Missing user_id parameter' });
    }
    
    // Check if the user exists
    const user = await db.users.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Get all active memberships for the user
    const userMemberships = await db.user_memberships.findAll({
      where: {
        user_id: userId,
        status: 'active'
      }
    });
    
    // Verify if any memberships have expired
    const now = new Date();
    const activeMemberships = [];
    
    for (const membership of userMemberships) {
      // Get the membership type
      const membershipType = await db.membership_types.findById(membership.membership_type_id);
      
      // Lifetime memberships never expire
      if (membershipType.duration_type === 'lifetime') {
        activeMemberships.push({
          ...membership,
          membership_type: membershipType,
          is_lifetime: true
        });
        continue;
      }
      
      // Check if the membership has expired
      if (membership.end_date) {
        const endDate = new Date(membership.end_date);
        if (endDate > now) {
          activeMemberships.push({
            ...membership,
            membership_type: membershipType,
            is_lifetime: false
          });
        } else {
          // Update the membership status to expired
          await db.user_memberships.update(membership.id, { status: 'expired' });
        }
      }
    }
    
    // Filter by specific membership type if requested
    let filteredMemberships = activeMemberships;
    if (specificMembershipTypeId) {
      filteredMemberships = activeMemberships.filter(
        m => m.membership_type_id === specificMembershipTypeId
      );
    }
    
    // Prepare the response
    const hasActiveMembership = filteredMemberships.length > 0;
    
    // If no active memberships, include available memberships
    let availableMemberships = [];
    if (!hasActiveMembership) {
      availableMemberships = await db.membership_types.findAll({
        where: { is_active: true }
      });
    }
    
    return res.json({
      has_active_membership: hasActiveMembership,
      memberships: filteredMemberships,
      available_memberships: hasActiveMembership ? undefined : availableMemberships
    });
    
  } catch (error) {
    console.error('Error checking membership status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
