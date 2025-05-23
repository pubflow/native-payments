/**
 * Features Configuration
 * 
 * This file defines all available features that can be included in memberships
 * or purchased as addons. Each feature has a unique ID and properties that
 * describe it.
 */

/**
 * Available features configuration
 * 
 * Each feature has:
 * - id: Unique identifier for the feature
 * - name: Display name for the feature
 * - description: Detailed description of what the feature provides
 * - is_addon: (Optional) Whether this feature can be purchased separately as an addon
 * - price_cents: (Optional) Price in cents if this is an addon
 * - currency: (Optional) Currency code for the price if this is an addon
 * - duration_days: (Optional) Duration in days if this is a time-limited addon (null for permanent)
 */
const AVAILABLE_FEATURES = {
  // Basic features included in memberships
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
  
  // Addon features that can be purchased separately
  'family_sharing': {
    id: 'family_sharing',
    name: 'Family Sharing',
    description: 'Share your subscription with up to 5 family members',
    is_addon: true,
    price_cents: 499, // $4.99
    currency: 'USD',
    duration_days: 30 // 30-day addon
  },
  'exclusive_content': {
    id: 'exclusive_content',
    name: 'Exclusive Content',
    description: 'Access to exclusive premium content',
    is_addon: true,
    price_cents: 299, // $2.99
    currency: 'USD',
    duration_days: 30 // 30-day addon
  },
  'lifetime_downloads': {
    id: 'lifetime_downloads',
    name: 'Lifetime Downloads',
    description: 'Permanent access to download all content',
    is_addon: true,
    price_cents: 9900, // $99.00
    currency: 'USD',
    duration_days: null // null indicates permanent
  },
  
  // Service-specific features
  'cloud_storage': {
    id: 'cloud_storage',
    name: 'Cloud Storage',
    description: 'Store your files in the cloud',
    is_addon: true,
    price_cents: 199, // $1.99
    currency: 'USD',
    duration_days: 30
  },
  'priority_support': {
    id: 'priority_support',
    name: 'Priority Support',
    description: 'Get priority customer support',
    is_addon: true,
    price_cents: 499, // $4.99
    currency: 'USD',
    duration_days: 30
  },
  'ad_free': {
    id: 'ad_free',
    name: 'Ad-Free Experience',
    description: 'Remove all advertisements'
  },
  'early_access': {
    id: 'early_access',
    name: 'Early Access',
    description: 'Get early access to new content and features'
  }
};

module.exports = { AVAILABLE_FEATURES };
