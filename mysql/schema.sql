-- MySQL Schema for Native Payments System

-- Main users table with all user information including new fields
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255), -- Optional: first name
    last_name VARCHAR(255), -- Optional: last name
    email VARCHAR(255) NOT NULL UNIQUE,
    user_type VARCHAR(255) NOT NULL, -- 'individual', 'business', 'admin'
    picture TEXT,
    user_name VARCHAR(255) UNIQUE,
    password_hash TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT false,

    -- Contact Information
    phone VARCHAR(50) UNIQUE, -- Primary phone (unique)
    mobile VARCHAR(50), -- Alternative mobile number
    recovery_email VARCHAR(255), -- Recovery email address

    -- Profile Information
    display_name VARCHAR(255), -- Display name for UI
    bio TEXT, -- User biography (max 500 chars)
    gender CHAR(1), -- ISO 5218: 'm', 'f', 'x'
    dob DATE, -- Date of birth
    tmz VARCHAR(50), -- IANA timezone (e.g., America/New_York)

    -- Security & Preferences
    is_locked BOOLEAN NOT NULL DEFAULT false,
    two_factor BOOLEAN NOT NULL DEFAULT false, -- Indicates if 2FA is enabled
    lang VARCHAR(10) NULL, -- Optional language preference (e.g., 'en', 'es', 'ja')
    first_time BOOLEAN NOT NULL DEFAULT true,

    -- Soft Delete Support
    deleted_at TIMESTAMP NULL, -- Timestamp when user was deleted (NULL = active)
    deletion_reason VARCHAR(100) NULL, -- Reason: 'user_request', 'admin_action', 'gdpr_compliance', 'inactivity', 'violation'

    -- System Fields
    reference_id VARCHAR(255), -- External reference ID
    metadata JSON, -- JSON object for additional user information in English
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tokens (Authentication & Security)
CREATE TABLE IF NOT EXISTS tokens (
    id VARCHAR(255) PRIMARY KEY,
    token VARCHAR(64) UNIQUE NOT NULL, -- Hashed token for security
    type VARCHAR(20) NOT NULL, -- 'email', 'phone', 'username'
    identifier_value VARCHAR(255) NOT NULL, -- The actual identifier value
    token_type VARCHAR(30) NOT NULL, -- 'magic_link', 'password_reset', 'email_verification', 'phone_verification'
    user_id VARCHAR(255) NULL, -- NULL for guest tokens, user ID for registered users

    -- Simple attempt system
    attempts_remaining INT NOT NULL DEFAULT 1, -- How many attempts are left

    -- Basic states and timestamps
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'consumed', 'expired', 'revoked'
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    consumed_at TIMESTAMP NULL, -- When the token was successfully consumed

    -- Optional context and metadata
    context VARCHAR(255) NULL, -- Optional context for two-factor validation (e.g., 'change_username_samuelorecio_to_michaeljackson')
    metadata JSON NULL,

    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Organizations
CREATE TABLE IF NOT EXISTS organizations (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    owner_user_id VARCHAR(255) NOT NULL,
    business_email VARCHAR(255),
    business_phone VARCHAR(50),
    tax_id VARCHAR(100),
    address TEXT,
    country CHAR(2), -- ISO 2-letter country code
    picture TEXT, -- Organization logo/picture URL
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS organization_users (
    id VARCHAR(255) PRIMARY KEY,
    organization_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'billing', 'member'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY (organization_id, user_id)
);

-- Projects (Universal Entity for hierarchical billing/management)
CREATE TABLE IF NOT EXISTS projects (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE, -- URL-friendly identifier
    description TEXT,
    picture TEXT, -- Project logo/icon
    
    -- Ownership (Can belong to User or Organization)
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    
    -- Billing Context
    billing_account_id VARCHAR(255), -- ID of the entity responsible for billing
    billing_email VARCHAR(255),
    billing_currency VARCHAR(3) DEFAULT 'USD',
    
    -- Metadata & Status
    metadata JSON,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL)
);

-- Project Indexes
CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_projects_organization_id ON projects(organization_id);
CREATE INDEX idx_projects_billing_account ON projects(billing_account_id);

-- Payment Providers
CREATE TABLE IF NOT EXISTS payment_providers (
    id VARCHAR(50) PRIMARY KEY, -- 'stripe', 'paypal', 'authorize_net', etc.
    display_name VARCHAR(255) NOT NULL,
    description VARCHAR(500), -- Description of the payment provider
    picture VARCHAR(255), -- URL to payment provider logo or icon
    is_active BOOLEAN NOT NULL DEFAULT true,
    supports_subscriptions BOOLEAN NOT NULL DEFAULT false,
    supports_saved_methods BOOLEAN NOT NULL DEFAULT false,
    config JSON, -- Provider-specific configuration
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- External Entities (Unified Entity Management with Hierarchical Relationships)
CREATE TABLE IF NOT EXISTS external_entities (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    project_id VARCHAR(255), -- Link to Project

    -- CONTEXT FIELDS (primary classification)
    context_type VARCHAR(50) NOT NULL DEFAULT 'payment',  -- 'payment', 'newsletter', 'events', etc.
    context_id VARCHAR(255),                 -- Specific context identifier (optional)

    -- PAYMENT FIELDS (optional, only for payment contexts)
    payment_provider_id VARCHAR(50),        -- References payment_providers.id (optional)
    payment_provider_customer_id VARCHAR(255), -- External provider customer ID (optional)

    -- ENTITY RELATIONSHIPS
    provider_entity_id VARCHAR(255),         -- Reference to another entity in same table

    -- ENTITY DATA
    is_external BOOLEAN NOT NULL DEFAULT true,  -- true for external entities, false for registered users
    external_email VARCHAR(255),             -- Clean semantic naming
    external_name VARCHAR(255),              -- Clean semantic naming
    external_phone VARCHAR(50),              -- Optional phone
    external_alias VARCHAR(255),             -- Optional alias/nickname

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- FOREIGN KEYS WITH PROPER REFERENCES
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_provider_id) REFERENCES payment_providers(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_entity_id) REFERENCES external_entities(id) ON DELETE SET NULL,

    CHECK (user_id IS NOT NULL OR external_email IS NOT NULL) -- Either user_id or external_email must be provided
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create partial unique indexes to enforce conditional uniqueness
CREATE UNIQUE INDEX idx_external_entities_user_unique
ON external_entities (user_id, organization_id, project_id, payment_provider_id, context_type);

CREATE UNIQUE INDEX idx_external_entities_email_unique
ON external_entities (external_email, organization_id, project_id, payment_provider_id, context_type);

-- Addresses
CREATE TABLE IF NOT EXISTS addresses (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    address_type VARCHAR(50) NOT NULL, -- 'billing', 'shipping', 'both'
    is_default BOOLEAN NOT NULL DEFAULT false,
    name VARCHAR(255),
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(255) NOT NULL,
    state VARCHAR(255),
    postal_code VARCHAR(50) NOT NULL,
    country VARCHAR(2) NOT NULL, -- ISO 2-letter country code
    phone VARCHAR(50),
    email VARCHAR(255),
    alias VARCHAR(255), -- User-friendly name for the address (e.g., "Home", "Office", "Mom's house")
    is_guest BOOLEAN NOT NULL DEFAULT false, -- Indicates if this is a guest address
    guest_email VARCHAR(255), -- Email for guest addresses (for identification)
    guest_name VARCHAR(255), -- Name for guest addresses
    metadata JSON, -- JSON object for additional address information (e.g., category, notes)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = true) -- Must belong to either a user, organization, or be a guest
);

-- Payment Methods
CREATE TABLE IF NOT EXISTS payment_methods (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    provider_id VARCHAR(50) NOT NULL,
    provider_payment_method_id VARCHAR(255) NOT NULL, -- ID from the provider
    customer_id VARCHAR(255), -- Direct link to external_entities.id for better performance
    payment_type VARCHAR(50) NOT NULL, -- 'credit_card', 'bank_account', 'paypal', 'wallet', etc.
    wallet_type VARCHAR(50), -- 'apple_pay', 'google_pay', 'samsung_pay', etc. (only for wallet payment types)
    last_four VARCHAR(4), -- Last 4 digits of card or account
    expiry_month VARCHAR(2), -- Expiration month (for cards)
    expiry_year VARCHAR(4), -- Expiration year (for cards)
    card_brand VARCHAR(50), -- 'visa', 'mastercard', etc.
    is_default BOOLEAN NOT NULL DEFAULT false,
    billing_address_id VARCHAR(255),
    alias VARCHAR(255), -- User-friendly name for the payment method (e.g., "My primary card", "Travel card")
    is_guest BOOLEAN NOT NULL DEFAULT false, -- Indicates if this is a guest payment method
    guest_email VARCHAR(255), -- Email for guest payment methods (for identification)
    guest_name VARCHAR(255), -- Name for guest payment methods
    metadata JSON, -- JSON object for additional payment method information (e.g., category, notes)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE SET NULL,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = true) -- Must belong to either a user, organization, or be a guest
);

-- Product Categories
CREATE TABLE IF NOT EXISTS product_categories (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    parent_id VARCHAR(255),
    image VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES product_categories(id) ON DELETE SET NULL
);

-- Products/Plans (Products only have base price - tax calculated dynamically at purchase)
CREATE TABLE IF NOT EXISTS products (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    product_type VARCHAR(50) NOT NULL, -- 'physical', 'digital', 'service', 'subscription'
    is_recurring BOOLEAN NOT NULL DEFAULT false,

    -- PRODUCT PRICING (only base price - tax calculated dynamically)
    subtotal_cents BIGINT NOT NULL, -- Base product price (before tax/discounts)

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    billing_interval VARCHAR(20), -- 'monthly', 'yearly', null for one-time
    trial_days INT DEFAULT 0,
    image VARCHAR(255), -- Main product image URL
    gallery JSON, -- JSON array of additional image URLs
    category_id VARCHAR(255),
    parent_product_id VARCHAR(255), -- For product variations, references the parent product
    variations JSON, -- JSON array of variation options (e.g., size, color)
    metadata JSON,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE SET NULL,
    FOREIGN KEY (parent_product_id) REFERENCES products(id) ON DELETE SET NULL
);

-- Orders
CREATE TABLE IF NOT EXISTS orders (
    id VARCHAR(255) PRIMARY KEY,
    order_number VARCHAR(255) UNIQUE NOT NULL, -- Human-readable order number
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255), -- References external_entities table (supports registered guests)

    -- Anonymous guest support
    is_guest_order BOOLEAN NOT NULL DEFAULT false, -- Track if this was an anonymous guest order
    guest_data JSON, -- JSON object with anonymous guest information (email, name, phone, etc.)
    guest_email VARCHAR(255), -- Extracted guest email for indexing and queries

    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'paid', 'cancelled', 'refunded'
    subtotal_cents BIGINT NOT NULL,
    tax_cents BIGINT NOT NULL DEFAULT 0,
    discount_cents BIGINT NOT NULL DEFAULT 0,
    total_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    billing_address_id VARCHAR(255),
    shipping_address_id VARCHAR(255),
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE SET NULL,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_order = true), -- Must belong to a user, organization, customer, or be an anonymous guest order
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents) -- Pricing validation
);

CREATE TABLE IF NOT EXISTS order_items (
    id VARCHAR(255) PRIMARY KEY,
    order_id VARCHAR(255) NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price_cents BIGINT NOT NULL,
    total_cents BIGINT NOT NULL,
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

-- Subscriptions (Enhanced with guest support via customer_id and automatic billing)
CREATE TABLE IF NOT EXISTS subscriptions (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255) NOT NULL, -- References external_entities table (supports both users and guests)
    product_id VARCHAR(255), -- Optional for custom donations/flexible subscriptions
    payment_method_id VARCHAR(255),
    provider_id VARCHAR(50) NOT NULL,
    provider_subscription_id VARCHAR(255),
    status VARCHAR(50) NOT NULL, -- 'active', 'cancelled', 'past_due', 'trialing', 'incomplete', 'incomplete_expired'
    current_period_start TIMESTAMP NOT NULL,
    current_period_end TIMESTAMP NOT NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    trial_end TIMESTAMP,

    -- NEW UNIFIED PRICING SYSTEM
    subtotal_cents BIGINT NOT NULL, -- Base subscription price
    tax_cents BIGINT NOT NULL DEFAULT 0, -- Applied taxes
    discount_cents BIGINT NOT NULL DEFAULT 0, -- Applied discounts
    total_cents BIGINT NOT NULL, -- Final subscription price (subtotal + tax - discount)

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    -- Billing automation fields
    billing_interval VARCHAR(20) NOT NULL DEFAULT 'monthly', -- 'daily', 'weekly', 'monthly', 'yearly'
    interval_multiplier INT DEFAULT 1, -- Optional: 2 for every 2 months, 3 for every 3 weeks, etc.
    next_billing_date TIMESTAMP, -- When the next billing should occur
    last_billing_attempt TIMESTAMP, -- Last time we attempted to bill this subscription
    billing_retry_count INT NOT NULL DEFAULT 0, -- Number of failed billing attempts
    max_retry_attempts INT NOT NULL DEFAULT 3, -- Maximum retry attempts before suspension
    billing_status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'past_due', 'suspended', 'cancelled'
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Enhanced tracking fields (inspired by payments table)
    description TEXT, -- Human-readable description (e.g., "Premium Monthly Plan", "Basic Annual Subscription")
    concept VARCHAR(100), -- Human-readable concept (e.g., "Monthly Subscription", "Annual Plan", "Trial Subscription")
    reference_code VARCHAR(100), -- Machine-readable code for analytics (e.g., "subscription_monthly", "plan_premium_annual")
    category VARCHAR(50), -- High-level category (e.g., "subscription", "trial", "upgrade", "downgrade")
    tags VARCHAR(500), -- Comma-separated tags for flexible categorization (e.g., "promotion,summer,discount,premium")

    -- Guest subscription support (inspired by payments table)
    is_guest_subscription BOOLEAN NOT NULL DEFAULT FALSE, -- Track if this is a guest subscription
    guest_data JSON, -- JSON data with guest information (email, name, phone, etc.)
    guest_email VARCHAR(255), -- Extracted guest email for indexing and queries
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_subscription = TRUE), -- Must belong to a user, organization, have a customer, or be guest subscription
    CHECK (billing_interval IN ('daily', 'weekly', 'monthly', 'yearly')),
    CHECK (interval_multiplier IS NULL OR (interval_multiplier > 0 AND interval_multiplier <= 12)),
    CHECK (billing_status IN ('active', 'past_due', 'suspended', 'cancelled')),
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents) -- Pricing validation
);

-- Payments (Enhanced with financial breakdown and custom payment support)
CREATE TABLE IF NOT EXISTS payments (
    id VARCHAR(255) PRIMARY KEY,
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    user_id VARCHAR(255), -- Made optional for guest checkout
    organization_id VARCHAR(255),
    payment_method_id VARCHAR(255),
    provider_id VARCHAR(50), -- Made optional for custom payments
    provider_payment_id VARCHAR(255), -- Final payment ID from provider
    provider_intent_id VARCHAR(255), -- Intent ID from provider (e.g., Stripe payment intent)
    client_secret VARCHAR(255), -- Client secret for frontend confirmation

    -- NEW UNIFIED PRICING SYSTEM
    subtotal_cents BIGINT NOT NULL, -- Base amount before taxes and discounts
    tax_cents BIGINT NOT NULL DEFAULT 0, -- Applied taxes
    discount_cents BIGINT NOT NULL DEFAULT 0, -- Applied discounts
    total_cents BIGINT NOT NULL, -- Final amount (subtotal + tax - discount)

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(50) NOT NULL, -- 'pending', 'requires_confirmation', 'requires_action', 'processing', 'succeeded', 'failed', 'refunded'
    description TEXT,
    error_message TEXT,

    -- Enhanced tracking fields
    concept VARCHAR(100), -- Human-readable concept (e.g., "Monthly Subscription", "Product Purchase", "Donation")
    reference_code VARCHAR(100), -- Machine-readable code for analytics and payment links
    category VARCHAR(50), -- High-level category (e.g., "subscription", "donation", "purchase", "refund", "fee")
    tags VARCHAR(500), -- Comma-separated tags for flexible categorization

    -- Custom/Manual payment support
    is_manual_payment BOOLEAN NOT NULL DEFAULT false, -- For manual/legacy payments
    manual_payment_method VARCHAR(100), -- 'cash', 'check', 'bank_transfer', 'legacy_system'
    manual_payment_reference VARCHAR(255), -- Reference for manual payment
    manual_payment_date TIMESTAMP, -- Actual date of manual payment

    -- Guest support
    is_guest_payment BOOLEAN NOT NULL DEFAULT false, -- Track if this was a guest payment
    guest_data JSON, -- JSON object with guest information (email, name, phone, etc.)
    guest_email VARCHAR(255), -- Extracted guest email for indexing and queries

    -- Coupon tracking
    applied_coupons JSON, -- Array of applied coupons with details

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,

    -- Financial validation: total must equal subtotal + tax - discount
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents),
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest_payment = true),
    -- Allow direct payments (donations), order payments, subscription payments, or manual payments
    CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL OR is_manual_payment = true OR (order_id IS NULL AND subscription_id IS NULL))
);

-- Invoices (Enhanced with guest support and payment links)
CREATE TABLE IF NOT EXISTS invoices (
    id VARCHAR(255) PRIMARY KEY,
    invoice_number VARCHAR(255) UNIQUE NOT NULL,
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    payment_id VARCHAR(255), -- Optional reference to payment (updated after payment completion)
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255), -- References external_entities table (supports both users and guests)

    status VARCHAR(50) NOT NULL, -- 'draft', 'open', 'paid', 'void', 'uncollectible'

    -- NEW UNIFIED PRICING SYSTEM (consistent with payments)
    subtotal_cents BIGINT NOT NULL, -- Base amount before taxes and discounts
    tax_cents BIGINT NOT NULL DEFAULT 0, -- Applied taxes
    discount_cents BIGINT NOT NULL DEFAULT 0, -- Applied discounts
    total_cents BIGINT NOT NULL, -- Final amount (subtotal + tax - discount)

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    issue_date TIMESTAMP NOT NULL,
    due_date TIMESTAMP NOT NULL,
    paid_date TIMESTAMP,

    -- Enhanced guest invoice support
    is_guest_invoice BOOLEAN NOT NULL DEFAULT false,
    guest_data JSON, -- Guest information for invoices
    guest_email VARCHAR(255), -- Extracted guest email for indexing

    -- Payment link support
    reference_code VARCHAR(100), -- For referencing specific payments
    payment_link_url VARCHAR(500), -- Unique URL to pay this invoice
    payment_link_expires_at TIMESTAMP, -- Payment link expiration

    -- Payment method tracking (saved when payment is completed)
    payment_method_id VARCHAR(255), -- Payment method used for this invoice (updated after payment)

    billing_address_id VARCHAR(255),
    provider_id VARCHAR(50),
    provider_invoice_id VARCHAR(255),
    invoice_url VARCHAR(500), -- Optional friendly URL to access the invoice

    -- Coupon tracking
    applied_coupons JSON, -- Applied coupons to this invoice

    -- Line items and notes
    line_items JSON, -- JSON array with detailed line item breakdown
    notes TEXT, -- Additional notes for the invoice

    -- Optional Features Integration (added for optional features support)
    billing_schedule_id VARCHAR(255), -- Link to billing schedule if invoice was auto-generated
    account_balance_id VARCHAR(255), -- Link to account balance if payment uses balance

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE SET NULL,

    -- Financial validation: total must equal subtotal + tax - discount
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents),
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_invoice = true)
);

-- Webhooks and Events
CREATE TABLE IF NOT EXISTS payment_webhooks (
    id VARCHAR(255) PRIMARY KEY,
    provider_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- 'payment.succeeded', 'subscription.created', etc.
    payload JSON NOT NULL,
    processed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS payment_events (
    id VARCHAR(255) PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL, -- 'payment', 'subscription', 'order', etc.
    entity_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- 'created', 'updated', 'failed', etc.
    data JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Membership Types
CREATE TABLE IF NOT EXISTS membership_types (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    duration_type VARCHAR(50) NOT NULL, -- 'recurring', 'fixed', 'lifetime'
    duration_days INT, -- NULL for 'lifetime' memberships
    price_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    features JSON, -- JSON array of features included in this membership
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSON, -- JSON object for additional membership type information
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Entity Memberships (formerly User Memberships)
CREATE TABLE IF NOT EXISTS entity_memberships (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    project_id VARCHAR(255), -- Link to Project
    membership_type_id VARCHAR(255) NOT NULL,
    subscription_id VARCHAR(255), -- For recurring memberships
    order_id VARCHAR(255), -- For one-time purchases
    status VARCHAR(50) NOT NULL, -- 'active', 'expired', 'cancelled', 'pending'
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP, -- NULL for lifetime memberships
    auto_renew BOOLEAN NOT NULL DEFAULT false,
    addons JSON, -- JSON array of purchased addons with their expiration dates
    cancelled_at TIMESTAMP NULL, -- When the membership was cancelled
    cancellation_reason VARCHAR(255) NULL, -- Reason for cancellation
    metadata JSON, -- JSON object for additional membership information
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (membership_type_id) REFERENCES membership_types(id) ON DELETE RESTRICT,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR project_id IS NOT NULL)
);

-- ========================================
-- OPTIMIZED INDEXES FOR USERS TABLE
-- ========================================

-- Primary functional indexes
CREATE INDEX idx_users_email ON users(email, deleted_at);
CREATE INDEX idx_users_user_name ON users(user_name, deleted_at);
CREATE INDEX idx_users_phone ON users(phone, deleted_at);
CREATE INDEX idx_users_user_type ON users(user_type, deleted_at);

-- Soft delete indexes (for efficient queries on active/deleted users)
CREATE INDEX idx_users_active ON users(deleted_at);
CREATE INDEX idx_users_deleted ON users(deleted_at, deletion_reason);

-- Authentication and verification indexes
CREATE INDEX idx_users_email_verified ON users(email, is_verified, deleted_at);
CREATE INDEX idx_users_verification_status ON users(is_verified, deleted_at);

-- Search and filtering indexes
CREATE INDEX idx_users_name_search ON users(name, last_name, deleted_at);

-- Security and account status indexes
CREATE INDEX idx_users_locked_status ON users(is_locked, deleted_at);
CREATE INDEX idx_users_two_factor ON users(two_factor, deleted_at);

-- Temporal indexes for analytics and maintenance
CREATE INDEX idx_users_created_at ON users(created_at, deleted_at);
CREATE INDEX idx_users_updated_at ON users(updated_at, deleted_at);

-- Language and metadata indexes
CREATE INDEX idx_users_lang ON users(lang, deleted_at);

-- New profile and contact indexes
CREATE INDEX idx_users_mobile ON users(mobile, deleted_at);
CREATE INDEX idx_users_recovery_email ON users(recovery_email, deleted_at);
CREATE INDEX idx_users_display_name ON users(display_name, deleted_at);
CREATE INDEX idx_users_gender ON users(gender, deleted_at);
CREATE INDEX idx_users_dob ON users(dob, deleted_at);
CREATE INDEX idx_users_tmz ON users(tmz, deleted_at);
CREATE INDEX idx_users_reference_id ON users(reference_id, deleted_at);

-- Composite indexes for common query patterns
CREATE INDEX idx_users_type_verified ON users(user_type, is_verified, deleted_at);
CREATE INDEX idx_users_email_type ON users(email, user_type, deleted_at);

-- ========================================
-- OPTIMIZED INDEXES FOR ORGANIZATIONS TABLE
-- ========================================

-- Primary functional indexes for organizations
CREATE INDEX idx_organizations_owner_user_id ON organizations(owner_user_id);
CREATE INDEX idx_organizations_name ON organizations(name);
CREATE INDEX idx_organizations_business_email ON organizations(business_email);
CREATE INDEX idx_organizations_business_phone ON organizations(business_phone);
CREATE INDEX idx_organizations_tax_id ON organizations(tax_id);
CREATE INDEX idx_organizations_country ON organizations(country);

-- Temporal indexes for organizations
CREATE INDEX idx_organizations_created_at ON organizations(created_at);
CREATE INDEX idx_organizations_updated_at ON organizations(updated_at);

-- ========================================
-- OTHER TABLE INDEXES
-- ========================================

-- Token indexes
CREATE INDEX idx_token_lookup ON tokens(token, status, expires_at);
CREATE INDEX idx_identifier_lookup ON tokens(type, identifier_value, status);
CREATE INDEX idx_user_tokens ON tokens(user_id, token_type, status);
CREATE INDEX idx_expiration_cleanup ON tokens(expires_at, status);
CREATE INDEX idx_token_type_status ON tokens(token_type, status);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_organization_id ON addresses(organization_id);
CREATE INDEX idx_addresses_type ON addresses(address_type);
CREATE INDEX idx_addresses_is_guest ON addresses(is_guest);
CREATE INDEX idx_addresses_guest_email ON addresses(guest_email);
CREATE INDEX idx_addresses_is_default ON addresses(is_default);

-- External Entities Indexes
CREATE INDEX idx_external_entities_user_id ON external_entities(user_id);
CREATE INDEX idx_external_entities_organization_id ON external_entities(organization_id);
CREATE INDEX idx_external_entities_context_type ON external_entities(context_type);
CREATE INDEX idx_external_entities_payment_provider ON external_entities(payment_provider_id);
CREATE INDEX idx_external_entities_is_external ON external_entities(is_external);
CREATE INDEX idx_external_entities_external_email ON external_entities(external_email);
CREATE INDEX idx_external_entities_provider_entity ON external_entities(provider_entity_id);
CREATE INDEX idx_external_entities_context_email ON external_entities(context_type, external_email);
CREATE INDEX idx_external_entities_hierarchy ON external_entities(provider_entity_id, context_type);

CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_organization_id ON payment_methods(organization_id);
CREATE INDEX idx_payment_methods_customer_id ON payment_methods(customer_id);
CREATE INDEX idx_payment_methods_is_guest ON payment_methods(is_guest);
CREATE INDEX idx_payment_methods_guest_email ON payment_methods(guest_email);
CREATE INDEX idx_payment_methods_alias ON payment_methods(alias);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_organization_id ON addresses(organization_id);
CREATE INDEX idx_addresses_is_guest ON addresses(is_guest);
CREATE INDEX idx_addresses_guest_email ON addresses(guest_email);
CREATE INDEX idx_addresses_alias ON addresses(alias);
CREATE INDEX idx_addresses_address_type ON addresses(address_type);
CREATE INDEX idx_addresses_is_default ON addresses(is_default);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_organization_id ON orders(organization_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_is_guest_order ON orders(is_guest_order);
CREATE INDEX idx_orders_guest_email ON orders(guest_email);
CREATE INDEX idx_orders_status ON orders(status);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_organization_id ON subscriptions(organization_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_next_billing ON subscriptions(next_billing_date, billing_status);
CREATE INDEX idx_subscriptions_billing_status ON subscriptions(billing_status);
CREATE INDEX idx_subscriptions_retry_billing ON subscriptions(last_billing_attempt, billing_retry_count);
-- Enhanced subscription tracking indexes
CREATE INDEX idx_subscriptions_reference_code ON subscriptions(reference_code);
CREATE INDEX idx_subscriptions_category ON subscriptions(category);
CREATE INDEX idx_subscriptions_concept ON subscriptions(concept);
-- Guest subscription indexes
CREATE INDEX idx_subscriptions_is_guest ON subscriptions(is_guest_subscription);
CREATE INDEX idx_subscriptions_guest_email ON subscriptions(guest_email);
CREATE INDEX idx_guest_subscriptions ON subscriptions(guest_email, is_guest_subscription, created_at);

CREATE INDEX IF NOT EXISTS idx_guest_payments ON payments(guest_email, is_guest_payment, created_at);
CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_subscription_id ON payments(subscription_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_organization_id ON payments(organization_id);
CREATE INDEX idx_payments_provider_intent_id ON payments(provider_intent_id);
CREATE INDEX idx_payments_is_guest_payment ON payments(is_guest_payment);
CREATE INDEX idx_payments_guest_email ON payments(guest_email);
-- Enhanced payment tracking indexes
CREATE INDEX idx_payments_reference_code ON payments(reference_code);
CREATE INDEX idx_payments_category ON payments(category);
CREATE INDEX idx_payments_concept ON payments(concept);

CREATE INDEX idx_invoices_order_id ON invoices(order_id);
CREATE INDEX idx_invoices_subscription_id ON invoices(subscription_id);
CREATE INDEX idx_invoices_customer_id ON invoices(customer_id);
CREATE INDEX idx_invoices_status ON invoices(status);

CREATE INDEX idx_payment_webhooks_provider_id ON payment_webhooks(provider_id);
CREATE INDEX idx_payment_webhooks_processed ON payment_webhooks(processed);

CREATE INDEX idx_payment_events_entity_type_entity_id ON payment_events(entity_type, entity_id);

CREATE INDEX idx_user_memberships_user_id ON user_memberships(user_id);
CREATE INDEX idx_user_memberships_organization_id ON user_memberships(organization_id);
CREATE INDEX idx_user_memberships_status ON user_memberships(status);
CREATE INDEX idx_user_memberships_membership_type_id ON user_memberships(membership_type_id);
CREATE INDEX idx_user_memberships_subscription_id ON user_memberships(subscription_id);
CREATE INDEX idx_user_memberships_end_date ON user_memberships(end_date);
CREATE INDEX idx_user_memberships_cancelled_at ON user_memberships(cancelled_at);

CREATE INDEX idx_membership_types_is_active ON membership_types(is_active);

-- Analytics Tables (Optional Feature)
-- These tables can be added to enable advanced analytics and reporting

-- Analytics Snapshots (Core analytics table)
CREATE TABLE IF NOT EXISTS analytics_snapshots (
    id VARCHAR(255) PRIMARY KEY,
    snapshot_date DATE NOT NULL,
    metric_type VARCHAR(50) NOT NULL, -- 'daily_revenue', 'active_subscriptions', etc.
    metric_value DECIMAL(20, 2) NOT NULL,
    currency VARCHAR(3),
    breakdown JSON, -- Detailed breakdown of the metric
    calculation_method VARCHAR(50) DEFAULT 'scheduled', -- 'scheduled', 'on_demand', 'manual'
    calculation_duration_ms INT, -- How long the calculation took
    data_freshness VARCHAR(50) DEFAULT 'historical', -- 'historical', 'recent', 'real_time'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_snapshot (snapshot_date, metric_type, currency)
);

-- Analytics Events (Optional - for detailed event tracking)
CREATE TABLE IF NOT EXISTS analytics_events (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    session_id VARCHAR(255),
    event_type VARCHAR(50) NOT NULL, -- 'payment_completed', 'subscription_created', etc.
    event_category VARCHAR(50), -- 'revenue', 'conversion', 'engagement'
    entity_type VARCHAR(50), -- 'order', 'subscription', 'membership'
    entity_id VARCHAR(255),
    properties JSON, -- Event-specific data
    revenue_cents BIGINT DEFAULT 0,
    currency VARCHAR(3),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- User Cohorts (Optional - for cohort analysis)
CREATE TABLE IF NOT EXISTS user_cohorts (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    cohort_month DATE NOT NULL, -- First day of the month when user first made a purchase
    cohort_type VARCHAR(50) NOT NULL, -- 'first_purchase', 'first_subscription'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_cohort (user_id, cohort_type)
);

-- Analytics Indexes
CREATE INDEX idx_analytics_snapshots_date_type ON analytics_snapshots(snapshot_date, metric_type);
CREATE INDEX idx_analytics_snapshots_currency ON analytics_snapshots(currency);

CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);

CREATE INDEX idx_analytics_events_category ON analytics_events(event_category);

CREATE INDEX idx_user_cohorts_month ON user_cohorts(cohort_month);
CREATE INDEX idx_user_cohorts_type ON user_cohorts(cohort_type);

-- ========================================
-- DISCOUNT COUPONS SYSTEM
-- ========================================

-- Discount Coupons
CREATE TABLE IF NOT EXISTS discount_coupons (
    id VARCHAR(255) PRIMARY KEY,

    -- Basic coupon information
    code VARCHAR(100) UNIQUE NOT NULL, -- Unique coupon code (e.g., "SUMMER2024", "WELCOME10")
    name VARCHAR(255) NOT NULL, -- Friendly name (e.g., "Summer Discount 2024")
    description TEXT, -- Detailed description of the coupon

    -- Discount type and value
    discount_type VARCHAR(20) NOT NULL, -- 'percentage', 'fixed_amount', 'free_shipping', 'buy_x_get_y'
    discount_value DECIMAL(10,2) NOT NULL, -- Discount value (percentage or fixed amount)
    currency VARCHAR(3) DEFAULT 'USD', -- Currency for fixed amount discounts

    -- Limits and restrictions
    minimum_amount_cents BIGINT DEFAULT 0, -- Minimum amount to apply coupon
    maximum_discount_cents BIGINT, -- Maximum discount (useful for percentages)
    usage_limit INTEGER, -- Total usage limit (NULL = unlimited)
    usage_limit_per_customer INTEGER, -- Limit per customer (NULL = unlimited per customer)
    current_usage_count INTEGER NOT NULL DEFAULT 0, -- Current usage counter

    -- Validity dates
    starts_at TIMESTAMP, -- Start date (NULL = immediate)
    expires_at TIMESTAMP, -- Expiration date (NULL = no expiration)

    -- Applicability restrictions
    applicable_to VARCHAR(20) NOT NULL DEFAULT 'all', -- 'all', 'products', 'categories', 'subscriptions'
    applicable_product_ids JSON, -- Array of specific product IDs
    applicable_category_ids JSON, -- Array of specific category IDs
    excluded_product_ids JSON, -- Array of excluded product IDs

    -- User restrictions
    applicable_user_types JSON, -- Array of user types ('individual', 'business', etc.)
    applicable_customer_segments JSON, -- Array of customer segments
    first_time_customers_only BOOLEAN NOT NULL DEFAULT false, -- Only for new customers

    -- State and configuration
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_stackable BOOLEAN NOT NULL DEFAULT false, -- Can be combined with other coupons
    auto_apply BOOLEAN NOT NULL DEFAULT false, -- Automatically applied if conditions are met

    -- Tracking and analytics
    campaign_id VARCHAR(255), -- Marketing campaign ID
    source VARCHAR(100), -- Coupon source ('email', 'social', 'affiliate', etc.)
    tags VARCHAR(500), -- Tags for flexible categorization

    -- Advanced configuration
    buy_x_get_y_config JSON, -- Configuration for "buy X get Y" offers
    tier_discounts JSON, -- Tiered discounts (e.g., 10% for $100, 15% for $200)

    metadata JSON, -- Additional metadata
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by VARCHAR(255), -- User who created the coupon

    -- Validations
    CHECK (discount_type IN ('percentage', 'fixed_amount', 'free_shipping', 'buy_x_get_y')),
    CHECK (applicable_to IN ('all', 'products', 'categories', 'subscriptions')),
    CHECK (discount_value >= 0),
    CHECK (usage_limit IS NULL OR usage_limit > 0),
    CHECK (usage_limit_per_customer IS NULL OR usage_limit_per_customer > 0),
    CHECK (current_usage_count >= 0),
    CHECK (starts_at IS NULL OR expires_at IS NULL OR starts_at < expires_at)
);

-- Coupon Usage Tracking
CREATE TABLE IF NOT EXISTS coupon_usage (
    id VARCHAR(255) PRIMARY KEY,
    coupon_id VARCHAR(255) NOT NULL,

    -- Who used the coupon
    user_id VARCHAR(255),
    customer_id VARCHAR(255), -- For guests
    guest_email VARCHAR(255), -- For anonymous guests

    -- Where it was used
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    payment_id VARCHAR(255),
    invoice_id VARCHAR(255),

    -- Usage details
    discount_amount_cents BIGINT NOT NULL, -- Actual discount applied
    original_amount_cents BIGINT NOT NULL, -- Original amount before discount
    final_amount_cents BIGINT NOT NULL, -- Final amount after discount
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Usage metadata
    usage_context JSON, -- Additional context of usage
    ip_address VARCHAR(45), -- IP address (for fraud detection)
    user_agent TEXT, -- User agent (for analytics)

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (coupon_id) REFERENCES discount_coupons(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE SET NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,

    CHECK (user_id IS NOT NULL OR customer_id IS NOT NULL OR guest_email IS NOT NULL),
    CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL OR payment_id IS NOT NULL OR invoice_id IS NOT NULL)
);

-- ========================================
-- TAX RATES SYSTEM (OPTIONAL)
-- ========================================

-- Tax Rates (Optional system for dynamic tax calculation)
CREATE TABLE IF NOT EXISTS tax_rates (
    id VARCHAR(255) PRIMARY KEY,

    -- Basic tax information
    name VARCHAR(255) NOT NULL, -- "Sales Tax", "IVA", "GST", "VAT"
    description TEXT, -- Detailed description
    rate DECIMAL(5,4) NOT NULL, -- Tax rate (0.0360 = 3.6%)
    type VARCHAR(50) NOT NULL DEFAULT 'percentage', -- 'percentage', 'fixed_amount'

    -- Geographic applicability
    country VARCHAR(2), -- 'US', 'MX', 'ES', 'CA'
    state_province VARCHAR(50), -- 'CA', 'TX', 'CDMX', 'ON'
    city VARCHAR(100), -- 'New York', 'Los Angeles'
    postal_code VARCHAR(20), -- Specific postal codes

    -- Product/Category applicability (optional filters)
    applicable_categories JSON, -- Array of category_ids ["clothing", "electronics"]
    applicable_product_types JSON, -- Array of product_types ["physical", "digital"]
    excluded_categories JSON, -- Array of excluded category_ids
    excluded_product_types JSON, -- Array of excluded product_types

    -- Configuration
    is_active BOOLEAN NOT NULL DEFAULT true,
    priority INTEGER DEFAULT 0, -- Higher priority wins in conflicts
    effective_from TIMESTAMP, -- When this rate becomes effective
    effective_until TIMESTAMP, -- When this rate expires

    -- Additional data
    metadata JSON, -- Additional tax configuration
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by VARCHAR(255), -- User who created this rate

    -- Validations
    CHECK (rate >= 0),
    CHECK (type IN ('percentage', 'fixed_amount')),
    CHECK (priority >= 0),
    CHECK (effective_from IS NULL OR effective_until IS NULL OR effective_from < effective_until)
);

-- Coupon system indexes
CREATE INDEX idx_discount_coupons_code ON discount_coupons(code);
CREATE INDEX idx_discount_coupons_active ON discount_coupons(is_active);
CREATE INDEX idx_discount_coupons_expires_at ON discount_coupons(expires_at);
CREATE INDEX idx_discount_coupons_campaign ON discount_coupons(campaign_id);
CREATE INDEX idx_discount_coupons_type ON discount_coupons(discount_type);
CREATE INDEX idx_discount_coupons_usage ON discount_coupons(current_usage_count, usage_limit);
CREATE INDEX idx_discount_coupons_applicable ON discount_coupons(applicable_to);

CREATE INDEX idx_coupon_usage_coupon_id ON coupon_usage(coupon_id);
CREATE INDEX idx_coupon_usage_user_id ON coupon_usage(user_id);
CREATE INDEX idx_coupon_usage_guest_email ON coupon_usage(guest_email);
CREATE INDEX idx_coupon_usage_amount ON coupon_usage(discount_amount_cents, currency);
CREATE INDEX idx_coupon_usage_date ON coupon_usage(created_at);

-- ========================================
-- OPTIMIZED INDEXES FOR PRODUCTS TABLE
-- ========================================

-- Primary functional indexes
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_product_type ON products(product_type);
CREATE INDEX idx_products_is_recurring ON products(is_recurring);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_parent_product_id ON products(parent_product_id);

-- Pricing and financial indexes
CREATE INDEX idx_products_subtotal_cents ON products(subtotal_cents);
CREATE INDEX idx_products_currency ON products(currency);
CREATE INDEX idx_products_billing_interval ON products(billing_interval);
CREATE INDEX idx_products_trial_days ON products(trial_days);

-- Search and content indexes
CREATE INDEX idx_products_name_search ON products(name);
CREATE INDEX idx_products_description_search ON products(description);

-- Temporal indexes for analytics and maintenance
CREATE INDEX idx_products_created_at ON products(created_at);
CREATE INDEX idx_products_updated_at ON products(updated_at);

-- Composite indexes for common query patterns
CREATE INDEX idx_products_active_type ON products(is_active, product_type);
CREATE INDEX idx_products_active_recurring ON products(is_active, is_recurring);
CREATE INDEX idx_products_active_category ON products(is_active, category_id);
CREATE INDEX idx_products_type_recurring ON products(product_type, is_recurring);
CREATE INDEX idx_products_active_price ON products(is_active, subtotal_cents);
CREATE INDEX idx_products_category_price ON products(category_id, subtotal_cents);
CREATE INDEX idx_products_currency_price ON products(currency, subtotal_cents);

-- Advanced composite indexes for complex queries
CREATE INDEX idx_products_active_type_price ON products(is_active, product_type, subtotal_cents);
CREATE INDEX idx_products_active_recurring_price ON products(is_active, is_recurring, subtotal_cents);
CREATE INDEX idx_products_category_type_price ON products(category_id, product_type, subtotal_cents);

-- Subscription-specific indexes
CREATE INDEX idx_products_subscription_billing ON products(is_recurring, billing_interval, subtotal_cents);
CREATE INDEX idx_products_subscription_trial ON products(is_recurring, trial_days, subtotal_cents);

-- Tax rates indexes
CREATE INDEX idx_tax_rates_active ON tax_rates(is_active);
CREATE INDEX idx_tax_rates_location ON tax_rates(country, state_province, city);
CREATE INDEX idx_tax_rates_priority ON tax_rates(priority DESC);
CREATE INDEX idx_tax_rates_effective ON tax_rates(effective_from, effective_until);
CREATE INDEX idx_tax_rates_type ON tax_rates(type);

-- ============================================
-- COST TRACKING FEATURE (Optional)
-- ============================================
-- Add these tables to enable profit analysis and cost tracking
-- This feature allows you to track product costs and calculate profit margins

-- Product Costs - Define base costs for products/services
CREATE TABLE IF NOT EXISTS product_costs (
    id VARCHAR(255) PRIMARY KEY,
    product_id VARCHAR(255) NOT NULL,

    -- Cost type
    cost_type VARCHAR(50) NOT NULL, -- 'fixed', 'per_unit', 'per_hour', 'percentage'

    -- Cost values (use appropriate field based on cost_type)
    cost_per_unit_cents BIGINT, -- For physical products
    cost_per_hour_cents BIGINT, -- For hourly services
    cost_percentage DECIMAL(5,2), -- For variable costs (e.g., commissions)
    fixed_cost_cents BIGINT, -- Fixed costs (e.g., setup fees)

    -- Indirect costs
    overhead_percentage DECIMAL(5,2) DEFAULT 0, -- General overhead expenses

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Cost validity period (for historical tracking)
    effective_from TIMESTAMP NOT NULL,
    effective_until TIMESTAMP,

    -- Categorization
    cost_category VARCHAR(50), -- 'production', 'shipping', 'labor', 'materials', 'overhead'
    description TEXT,

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CHECK (cost_type IN ('fixed', 'per_unit', 'per_hour', 'percentage'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Order Costs - Track actual costs per order/transaction
CREATE TABLE IF NOT EXISTS order_costs (
    id VARCHAR(255) PRIMARY KEY,
    order_id VARCHAR(255),
    order_item_id VARCHAR(255),
    subscription_id VARCHAR(255),

    -- Calculated costs
    base_cost_cents BIGINT NOT NULL,
    overhead_cost_cents BIGINT DEFAULT 0,
    total_cost_cents BIGINT NOT NULL,

    -- Calculation details
    quantity DECIMAL(10,2), -- Can be hours, units, etc.
    unit_type VARCHAR(50), -- 'units', 'hours', 'percentage'

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Reference to cost used
    product_cost_id VARCHAR(255),
    cost_breakdown JSON, -- JSON with detailed breakdown

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE,
    FOREIGN KEY (product_cost_id) REFERENCES product_costs(id) ON DELETE SET NULL,

    CHECK (total_cost_cents = base_cost_cents + overhead_cost_cents)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- View for order profitability analysis
CREATE OR REPLACE VIEW order_profitability AS
SELECT
    o.id as order_id,
    o.order_number,
    o.user_id,
    o.total_cents as revenue_cents,
    COALESCE(SUM(oc.total_cost_cents), 0) as cost_cents,
    o.total_cents - COALESCE(SUM(oc.total_cost_cents), 0) as profit_cents,
    CASE
        WHEN o.total_cents > 0
        THEN ROUND(((o.total_cents - COALESCE(SUM(oc.total_cost_cents), 0)) * 100.0 / o.total_cents), 2)
        ELSE 0
    END as profit_margin_percentage,
    o.created_at
FROM orders o
LEFT JOIN order_costs oc ON o.id = oc.order_id
GROUP BY o.id;

-- View for subscription profitability analysis
CREATE OR REPLACE VIEW subscription_profitability AS
SELECT
    s.id as subscription_id,
    s.user_id,
    s.product_id,
    s.total_cents as revenue_cents,
    COALESCE(SUM(oc.total_cost_cents), 0) as cost_cents,
    s.total_cents - COALESCE(SUM(oc.total_cost_cents), 0) as profit_cents,
    CASE
        WHEN s.total_cents > 0
        THEN ROUND(((s.total_cents - COALESCE(SUM(oc.total_cost_cents), 0)) * 100.0 / s.total_cents), 2)
        ELSE 0
    END as profit_margin_percentage,
    s.billing_interval,
    s.created_at
FROM subscriptions s
LEFT JOIN order_costs oc ON s.id = oc.subscription_id
GROUP BY s.id;

-- Cost Tracking Indexes
CREATE INDEX idx_product_costs_product ON product_costs(product_id);
CREATE INDEX idx_product_costs_effective ON product_costs(effective_from, effective_until);
CREATE INDEX idx_product_costs_category ON product_costs(cost_category);
CREATE INDEX idx_product_costs_type ON product_costs(cost_type);

CREATE INDEX idx_order_costs_order ON order_costs(order_id);
CREATE INDEX idx_order_costs_subscription ON order_costs(subscription_id);
CREATE INDEX idx_order_costs_created ON order_costs(created_at);
CREATE INDEX idx_order_costs_product_cost ON order_costs(product_cost_id);

-- ============================================
-- ACCOUNT BALANCE FEATURE (Optional)
-- ============================================
-- Add these tables to enable customer account balances, credits, and wallet system
-- This feature allows prepayments, promotional credits, and account-based transactions

-- Account Balances - Track customer balances (wallets, credits, prepayments)
CREATE TABLE IF NOT EXISTS account_balances (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255), -- For registered guests

    -- NEW: Segment balances by context/purpose
    reference_code VARCHAR(100), -- 'main_wallet', 'promo_credits', 'refund_balance', 'subscription_prepaid'
    balance_type VARCHAR(50) NOT NULL DEFAULT 'general', -- 'general', 'promotional', 'refund', 'prepaid'

    -- Current balance
    current_balance_cents BIGINT NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Limits
    credit_limit_cents BIGINT DEFAULT 0, -- Allowed credit limit
    minimum_balance_cents BIGINT DEFAULT 0, -- Required minimum balance

    -- Expiration (for promotional credits)
    expires_at TIMESTAMP, -- For balances that expire

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'frozen', 'suspended'

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_transaction_at TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE CASCADE,

    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL),
    UNIQUE KEY unique_balance (user_id, organization_id, customer_id, currency, reference_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Account Transactions - Record all balance movements
CREATE TABLE IF NOT EXISTS account_transactions (
    id VARCHAR(255) PRIMARY KEY,
    account_balance_id VARCHAR(255) NOT NULL,

    -- Transaction type
    transaction_type VARCHAR(50) NOT NULL, -- 'credit', 'debit', 'refund', 'adjustment', 'fee'

    -- Amounts
    amount_cents BIGINT NOT NULL,
    balance_before_cents BIGINT NOT NULL,
    balance_after_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- References
    invoice_id VARCHAR(255), -- If related to an invoice
    payment_id VARCHAR(255), -- If related to a payment
    subscription_id VARCHAR(255), -- If related to subscription
    order_id VARCHAR(255), -- If related to order

    -- Description
    description TEXT NOT NULL,
    reference_code VARCHAR(100), -- Unique reference code

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'completed', -- 'pending', 'completed', 'failed', 'reversed'

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,

    FOREIGN KEY (account_balance_id) REFERENCES account_balances(id) ON DELETE CASCADE,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,

    CHECK (transaction_type IN ('credit', 'debit', 'refund', 'adjustment', 'fee'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Account Balance Indexes
CREATE INDEX idx_account_balances_user ON account_balances(user_id);
CREATE INDEX idx_account_balances_org ON account_balances(organization_id);
CREATE INDEX idx_account_balances_customer ON account_balances(customer_id);
CREATE INDEX idx_account_balances_reference ON account_balances(reference_code);
CREATE INDEX idx_account_balances_type ON account_balances(balance_type);
CREATE INDEX idx_account_balances_expires ON account_balances(expires_at);
CREATE INDEX idx_account_balances_status ON account_balances(status);

CREATE INDEX idx_account_transactions_balance ON account_transactions(account_balance_id);
CREATE INDEX idx_account_transactions_created ON account_transactions(created_at);
CREATE INDEX idx_account_transactions_type ON account_transactions(transaction_type);
CREATE INDEX idx_account_transactions_invoice ON account_transactions(invoice_id);
CREATE INDEX idx_account_transactions_payment ON account_transactions(payment_id);
CREATE INDEX idx_account_transactions_status ON account_transactions(status);
CREATE INDEX idx_account_transactions_reference ON account_transactions(reference_code);

-- Account Balance Integration with Core Tables
-- Note: The invoices table (core schema) includes account_balance_id column for tracking
-- which balance was used for payment. This enables mixed payment scenarios.

-- ============================================
-- BILLING SCHEDULES FEATURE (Optional)
-- ============================================
-- Add these tables to enable automated recurring billing
-- This feature allows flexible recurring charges with multiple payment sources

-- Billing Schedules - Configure recurring charges
CREATE TABLE IF NOT EXISTS billing_schedules (
    id VARCHAR(255) PRIMARY KEY,

    -- Who gets charged
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255),

    -- Charge configuration
    schedule_type VARCHAR(50) NOT NULL, -- 'recurring', 'one_time', 'metered'

    -- Amounts
    amount_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Recurrence
    billing_interval VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
    interval_multiplier INT DEFAULT 1, -- Every X intervals

    -- Dates
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP, -- NULL = indefinite
    next_billing_date TIMESTAMP NOT NULL,
    last_billed_at TIMESTAMP,

    -- Payment method
    payment_method_id VARCHAR(255),
    account_balance_id VARCHAR(255), -- Can charge from specific balance
    payment_priority VARCHAR(50) DEFAULT 'balance_first', -- 'balance_first', 'payment_method_first', 'balance_only', 'payment_method_only'

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'paused', 'cancelled', 'completed', 'failed'

    -- Retry logic
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
    last_failure_reason TEXT,

    -- Description
    description TEXT NOT NULL,
    reference_code VARCHAR(100), -- To identify charge type
    category VARCHAR(50), -- 'subscription', 'installment', 'fee', 'custom'

    -- Notifications
    notify_before_days INT DEFAULT 3, -- Notify X days before
    last_notification_sent TIMESTAMP,

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (account_balance_id) REFERENCES account_balances(id) ON DELETE SET NULL,

    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL),
    CHECK (schedule_type IN ('recurring', 'one_time', 'metered')),
    CHECK (billing_interval IN ('daily', 'weekly', 'monthly', 'yearly'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Billing Schedule Executions - Track execution history
CREATE TABLE IF NOT EXISTS billing_schedule_executions (
    id VARCHAR(255) PRIMARY KEY,
    billing_schedule_id VARCHAR(255) NOT NULL,

    -- Result
    execution_status VARCHAR(50) NOT NULL, -- 'success', 'failed', 'partial'

    -- Amounts
    attempted_amount_cents BIGINT NOT NULL,
    charged_amount_cents BIGINT,

    -- Created references
    payment_id VARCHAR(255),
    invoice_id VARCHAR(255),
    account_transaction_id VARCHAR(255),

    -- Details
    payment_source VARCHAR(50), -- 'account_balance', 'payment_method', 'mixed'
    error_message TEXT,

    executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata JSON,

    FOREIGN KEY (billing_schedule_id) REFERENCES billing_schedules(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,
    FOREIGN KEY (account_transaction_id) REFERENCES account_transactions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Billing Schedules Indexes
CREATE INDEX idx_billing_schedules_user ON billing_schedules(user_id);
CREATE INDEX idx_billing_schedules_org ON billing_schedules(organization_id);
CREATE INDEX idx_billing_schedules_next_billing ON billing_schedules(next_billing_date, status);
CREATE INDEX idx_billing_schedules_status ON billing_schedules(status);
CREATE INDEX idx_billing_schedules_reference ON billing_schedules(reference_code);
CREATE INDEX idx_billing_schedules_category ON billing_schedules(category);

CREATE INDEX idx_billing_executions_schedule ON billing_schedule_executions(billing_schedule_id);
CREATE INDEX idx_billing_executions_status ON billing_schedule_executions(execution_status);
CREATE INDEX idx_billing_executions_executed ON billing_schedule_executions(executed_at);

-- Billing Schedules Integration with Core Tables
-- Note: The invoices table (core schema) includes billing_schedule_id column for tracking
-- which billing schedule generated the invoice. This enables automatic invoice generation.

-- ============================================
-- INVOICES & RECEIPTS FEATURE (Optional)
-- ============================================
-- Add these tables to enable universal billing system
-- Invoices = pre-payment documents, Receipts = post-payment proof
-- Note: invoices table already exists in core schema, we only add receipts here

-- Receipts - Post-payment proof (generated after successful payment)
CREATE TABLE IF NOT EXISTS receipts (
    id VARCHAR(255) PRIMARY KEY,
    receipt_number VARCHAR(100) UNIQUE NOT NULL,

    -- References
    invoice_id VARCHAR(255), -- Can be related to invoice
    payment_id VARCHAR(255) NOT NULL, -- Always related to a payment
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255),

    -- Amounts (reflect what was PAID)
    subtotal_cents BIGINT NOT NULL,
    tax_cents BIGINT NOT NULL DEFAULT 0,
    discount_cents BIGINT NOT NULL DEFAULT 0,
    total_cents BIGINT NOT NULL,

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Payment method used
    payment_method_id VARCHAR(255),
    payment_method_type VARCHAR(50), -- 'credit_card', 'bank_transfer', 'account_balance', etc.

    -- Customer data (snapshot)
    customer_name VARCHAR(255),
    customer_email VARCHAR(255),
    customer_address JSON, -- JSON with address details

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'issued', -- 'issued', 'void'

    -- Guest support
    is_guest_receipt BOOLEAN NOT NULL DEFAULT false,
    guest_data JSON,
    guest_email VARCHAR(255),

    -- URLs and documents
    receipt_url TEXT,
    receipt_pdf_url TEXT,

    -- Metadata
    line_items JSON, -- JSON with item breakdown
    applied_coupons JSON, -- JSON with applied coupons
    notes TEXT,
    metadata JSON,

    issue_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,

    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_receipt = true),
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Receipts Indexes
CREATE INDEX idx_receipts_payment ON receipts(payment_id);
CREATE INDEX idx_receipts_invoice ON receipts(invoice_id);
CREATE INDEX idx_receipts_user ON receipts(user_id);
CREATE INDEX idx_receipts_customer ON receipts(customer_id);
CREATE INDEX idx_receipts_created ON receipts(created_at);
CREATE INDEX idx_receipts_guest_email ON receipts(guest_email);
CREATE INDEX idx_receipts_receipt_number ON receipts(receipt_number);

-- ============================================
-- OPTIONAL FEATURES INTEGRATION INDEXES
-- ============================================
-- These indexes support the optional features integration with core tables

-- Invoices integration with optional features
CREATE INDEX idx_invoices_billing_schedule ON invoices(billing_schedule_id);
CREATE INDEX idx_invoices_account_balance ON invoices(account_balance_id);
CREATE INDEX idx_receipts_status ON receipts(status);
