-- PostgreSQL Schema for Native Payments System

-- Users Table (Enhanced) - Hybrid Soft Delete + ON DELETE CASCADE Strategy
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255), -- Optional: first name
    last_name VARCHAR(255), -- Optional: last name
    email VARCHAR(255) NOT NULL UNIQUE,
    user_type VARCHAR(255) NOT NULL, -- 'individual', 'business', 'admin'
    picture TEXT,
    user_name VARCHAR(255) UNIQUE,
    password_hash TEXT,
    phone VARCHAR(50) UNIQUE, -- Optional phone number for SMS authentication (unique)
    is_verified BOOLEAN NOT NULL DEFAULT false,
    is_locked BOOLEAN NOT NULL DEFAULT false,
    two_factor BOOLEAN NOT NULL DEFAULT false, -- Indicates if 2FA is enabled
    lang VARCHAR(10) NULL, -- Optional language preference (e.g., 'en', 'es', 'ja')
    metadata JSONB, -- JSON object for additional user information in English
    first_time BOOLEAN NOT NULL DEFAULT true,

    -- Soft Delete Fields (Default Strategy)
    deleted_at TIMESTAMP NULL, -- Timestamp when user was deleted (NULL = active)
    deletion_reason VARCHAR(100) NULL, -- Reason: 'user_request', 'admin_action', 'gdpr_compliance', 'inactivity', 'violation'

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ========================================
-- OPTIMIZED INDEXES FOR USERS TABLE
-- ========================================

-- Primary functional indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_user_name ON users(user_name) WHERE deleted_at IS NULL AND user_name IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE deleted_at IS NULL AND phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_user_type ON users(user_type) WHERE deleted_at IS NULL;

-- Soft delete indexes (for efficient queries on active/deleted users)
CREATE INDEX IF NOT EXISTS idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_deleted ON users(deleted_at, deletion_reason) WHERE deleted_at IS NOT NULL;

-- Authentication and verification indexes
CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email, is_verified) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_verification_status ON users(is_verified) WHERE deleted_at IS NULL;

-- Search and filtering indexes
CREATE INDEX IF NOT EXISTS idx_users_name_search ON users(name, last_name) WHERE deleted_at IS NULL AND (name IS NOT NULL OR last_name IS NOT NULL);

-- Security and account status indexes
CREATE INDEX IF NOT EXISTS idx_users_locked_status ON users(is_locked) WHERE deleted_at IS NULL AND is_locked = true;
CREATE INDEX IF NOT EXISTS idx_users_two_factor ON users(two_factor) WHERE deleted_at IS NULL AND two_factor = true;

-- Temporal indexes for analytics and maintenance
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_updated_at ON users(updated_at) WHERE deleted_at IS NULL;

-- Language and metadata indexes
CREATE INDEX IF NOT EXISTS idx_users_lang ON users(lang) WHERE deleted_at IS NULL AND lang IS NOT NULL;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_users_type_verified ON users(user_type, is_verified) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_email_type ON users(email, user_type) WHERE deleted_at IS NULL;

-- Tokens (Authentication & Security)
CREATE TABLE IF NOT EXISTS tokens (
    id VARCHAR(255) PRIMARY KEY,
    token VARCHAR(64) UNIQUE NOT NULL, -- Hashed token for security
    type VARCHAR(20) NOT NULL, -- 'email', 'phone', 'username'
    identifier_value VARCHAR(255) NOT NULL, -- The actual identifier value
    token_type VARCHAR(30) NOT NULL, -- 'magic_link', 'password_reset', 'email_verification', 'phone_verification'
    user_id VARCHAR(255) NULL, -- NULL for guest tokens, user ID for registered users

    -- Simple attempt system
    attempts_remaining INTEGER NOT NULL DEFAULT 1, -- How many attempts are left

    -- Basic states and timestamps
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'consumed', 'expired', 'revoked'
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    consumed_at TIMESTAMP NULL, -- When the token was successfully consumed

    -- Optional context and metadata
    context VARCHAR(255) NULL, -- Optional context for two-factor validation (e.g., 'change_username_samuelorecio_to_michaeljackson')
    metadata JSONB NULL,

    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TRIGGER update_tokens_timestamp
BEFORE UPDATE ON tokens
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Organizations
CREATE TABLE IF NOT EXISTS organizations (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    owner_user_id VARCHAR(255) NOT NULL,
    business_email VARCHAR(255),
    business_phone VARCHAR(50),
    tax_id VARCHAR(100),
    address TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TRIGGER update_organizations_timestamp
BEFORE UPDATE ON organizations
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS organization_users (
    id VARCHAR(255) PRIMARY KEY,
    organization_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'billing', 'member'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE (organization_id, user_id)
);

CREATE TRIGGER update_organization_users_timestamp
BEFORE UPDATE ON organization_users
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

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
    is_guest BOOLEAN NOT NULL DEFAULT false, -- Indicates if this is a guest address
    guest_email VARCHAR(255), -- Email for guest addresses (for identification)
    guest_name VARCHAR(255), -- Name for guest addresses
    metadata JSONB, -- JSON object for additional address information (e.g., nickname, category, notes)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = true) -- Must belong to either a user, organization, or be a guest
);

CREATE TRIGGER update_addresses_timestamp
BEFORE UPDATE ON addresses
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Payment Providers
CREATE TABLE IF NOT EXISTS payment_providers (
    id VARCHAR(50) PRIMARY KEY, -- 'stripe', 'paypal', 'authorize_net', etc.
    display_name VARCHAR(255) NOT NULL,
    description VARCHAR(500), -- Description of the payment provider
    picture VARCHAR(255), -- URL to payment provider logo or icon
    is_active BOOLEAN NOT NULL DEFAULT true,
    supports_subscriptions BOOLEAN NOT NULL DEFAULT false,
    supports_saved_methods BOOLEAN NOT NULL DEFAULT false,
    config JSONB, -- Provider-specific configuration
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER update_payment_providers_timestamp
BEFORE UPDATE ON payment_providers
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Provider Customers
CREATE TABLE IF NOT EXISTS provider_customers (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    provider_id VARCHAR(50) NOT NULL,
    provider_customer_id VARCHAR(255) NOT NULL, -- ID from the provider (e.g., Stripe customer ID)
    guest_email VARCHAR(255), -- Email for guest customers
    guest_name VARCHAR(255), -- Name for guest customers
    is_guest BOOLEAN NOT NULL DEFAULT false, -- Indicates if this is a guest customer
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    UNIQUE (provider_id, provider_customer_id),
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = true) -- Must belong to either a user, organization, or be a guest
);

CREATE TRIGGER update_provider_customers_timestamp
BEFORE UPDATE ON provider_customers
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Payment Methods
CREATE TABLE IF NOT EXISTS payment_methods (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    provider_id VARCHAR(50) NOT NULL,
    provider_payment_method_id VARCHAR(255) NOT NULL, -- ID from the provider
    payment_type VARCHAR(50) NOT NULL, -- 'credit_card', 'bank_account', 'paypal', etc.
    last_four VARCHAR(4), -- Last 4 digits of card or account
    expiry_month VARCHAR(2), -- Expiration month (for cards)
    expiry_year VARCHAR(4), -- Expiration year (for cards)
    card_brand VARCHAR(50), -- 'visa', 'mastercard', etc.
    is_default BOOLEAN NOT NULL DEFAULT false,
    billing_address_id VARCHAR(255),
    is_guest BOOLEAN NOT NULL DEFAULT false, -- Indicates if this is a guest payment method
    guest_email VARCHAR(255), -- Email for guest payment methods (for identification)
    guest_name VARCHAR(255), -- Name for guest payment methods
    metadata JSONB, -- JSON object for additional payment method information (e.g., nickname, category)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = true) -- Must belong to either a user, organization, or be a guest
);

CREATE TRIGGER update_payment_methods_timestamp
BEFORE UPDATE ON payment_methods
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Product Categories
CREATE TABLE IF NOT EXISTS product_categories (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    parent_id VARCHAR(255),
    image VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES product_categories(id) ON DELETE SET NULL
);

CREATE TRIGGER update_product_categories_timestamp
BEFORE UPDATE ON product_categories
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Products/Plans
CREATE TABLE IF NOT EXISTS products (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    product_type VARCHAR(50) NOT NULL, -- 'physical', 'digital', 'service', 'subscription'
    is_recurring BOOLEAN NOT NULL DEFAULT false,
    price_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    billing_interval VARCHAR(20), -- 'monthly', 'yearly', null for one-time
    trial_days INTEGER DEFAULT 0,
    image VARCHAR(255), -- Main product image URL
    gallery JSONB, -- JSON array of additional image URLs
    category_id VARCHAR(255),
    parent_product_id VARCHAR(255), -- For product variations, references the parent product
    variations JSONB, -- JSON array of variation options (e.g., size, color)
    metadata JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE SET NULL,
    FOREIGN KEY (parent_product_id) REFERENCES products(id) ON DELETE SET NULL
);

CREATE TRIGGER update_products_timestamp
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Orders
CREATE TABLE IF NOT EXISTS orders (
    id VARCHAR(255) PRIMARY KEY,
    order_number VARCHAR(255) UNIQUE NOT NULL, -- Human-readable order number
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255), -- References provider_customers table (supports registered guests)

    -- Anonymous guest support
    is_guest_order BOOLEAN NOT NULL DEFAULT false, -- Track if this was an anonymous guest order
    guest_data JSONB, -- JSON object with anonymous guest information (email, name, phone, etc.)
    guest_email VARCHAR(255), -- Extracted guest email for indexing and queries

    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'paid', 'cancelled', 'refunded'
    subtotal_cents BIGINT NOT NULL,
    tax_cents BIGINT NOT NULL DEFAULT 0,
    discount_cents BIGINT NOT NULL DEFAULT 0,
    total_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    billing_address JSONB,
    shipping_address JSONB,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES provider_customers(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_order = true) -- Must belong to a user, organization, customer, or be an anonymous guest order
);

CREATE TRIGGER update_orders_timestamp
BEFORE UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TABLE IF NOT EXISTS order_items (
    id VARCHAR(255) PRIMARY KEY,
    order_id VARCHAR(255) NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_cents BIGINT NOT NULL,
    total_cents BIGINT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

-- Subscriptions (Enhanced with guest support via customer_id and automatic billing)
CREATE TABLE IF NOT EXISTS subscriptions (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255) NOT NULL, -- References provider_customers table (supports both users and guests)
    product_id VARCHAR(255), -- Optional for custom donations/flexible subscriptions
    payment_method_id VARCHAR(255),
    provider_id VARCHAR(50) NOT NULL,
    provider_subscription_id VARCHAR(255),
    status VARCHAR(50) NOT NULL, -- 'active', 'cancelled', 'past_due', 'trialing', 'incomplete', 'incomplete_expired'
    current_period_start TIMESTAMP NOT NULL,
    current_period_end TIMESTAMP NOT NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT false,
    trial_end TIMESTAMP,
    price_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    -- Billing automation fields
    billing_interval VARCHAR(20) NOT NULL DEFAULT 'monthly', -- 'daily', 'weekly', 'monthly', 'yearly'
    interval_multiplier INTEGER DEFAULT 1, -- Optional: 2 for every 2 months, 3 for every 3 weeks, etc.
    next_billing_date TIMESTAMP, -- When the next billing should occur
    last_billing_attempt TIMESTAMP, -- Last time we attempted to bill this subscription
    billing_retry_count INTEGER NOT NULL DEFAULT 0, -- Number of failed billing attempts
    max_retry_attempts INTEGER NOT NULL DEFAULT 3, -- Maximum retry attempts before suspension
    billing_status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'past_due', 'suspended', 'cancelled'
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES provider_customers(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL), -- Must belong to a user, organization, or have a customer
    CHECK (billing_interval IN ('daily', 'weekly', 'monthly', 'yearly')),
    CHECK (interval_multiplier IS NULL OR (interval_multiplier > 0 AND interval_multiplier <= 12)),
    CHECK (billing_status IN ('active', 'past_due', 'suspended', 'cancelled'))
);

CREATE TRIGGER update_subscriptions_timestamp
BEFORE UPDATE ON subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Payments (Enhanced with guest checkout support and payment intent functionality)
CREATE TABLE IF NOT EXISTS payments (
    id VARCHAR(255) PRIMARY KEY,
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    user_id VARCHAR(255), -- Made optional for guest checkout
    organization_id VARCHAR(255),
    payment_method_id VARCHAR(255),
    provider_id VARCHAR(50) NOT NULL,
    provider_payment_id VARCHAR(255), -- Final payment ID from provider
    provider_intent_id VARCHAR(255), -- Intent ID from provider (e.g., Stripe payment intent)
    client_secret VARCHAR(255), -- Client secret for frontend confirmation
    amount_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(50) NOT NULL, -- 'pending', 'requires_confirmation', 'requires_action', 'processing', 'succeeded', 'failed', 'refunded'
    description TEXT,
    error_message TEXT,
    -- Enhanced tracking fields
    concept VARCHAR(100), -- Human-readable concept (e.g., "Monthly Subscription", "Product Purchase", "Donation")
    reference_code VARCHAR(100), -- Machine-readable code for analytics (e.g., "subscription_monthly", "donation_campaign_2024")
    category VARCHAR(50), -- High-level category (e.g., "subscription", "donation", "purchase", "refund", "fee")
    tags VARCHAR(500), -- Comma-separated tags for flexible categorization (e.g., "promotion,summer,discount")
    is_guest_payment BOOLEAN NOT NULL DEFAULT false, -- Track if this was a guest payment
    guest_data JSONB, -- JSON object with guest information (email, name, phone, etc.)
    guest_email VARCHAR(255), -- Extracted guest email for indexing and queries
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest_payment = true) -- Must belong to a user, organization, or be guest payment
);

CREATE TRIGGER update_payments_timestamp
BEFORE UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Invoices
CREATE TABLE IF NOT EXISTS invoices (
    id VARCHAR(255) PRIMARY KEY,
    invoice_number VARCHAR(255) UNIQUE NOT NULL,
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255), -- References provider_customers table (supports both users and guests)
    status VARCHAR(50) NOT NULL, -- 'draft', 'open', 'paid', 'void', 'uncollectible'
    amount_cents BIGINT NOT NULL,
    tax_cents BIGINT NOT NULL DEFAULT 0,
    discount_cents BIGINT NOT NULL DEFAULT 0,
    total_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    issue_date TIMESTAMP NOT NULL,
    due_date TIMESTAMP NOT NULL,
    paid_date TIMESTAMP,
    billing_address JSONB,
    provider_id VARCHAR(50),
    provider_invoice_id VARCHAR(255),
    invoice_url VARCHAR(500), -- Optional friendly URL to access the invoice
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES provider_customers(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL) -- Must belong to a user, organization, or have a customer
);

CREATE TRIGGER update_invoices_timestamp
BEFORE UPDATE ON invoices
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Webhooks and Events
CREATE TABLE IF NOT EXISTS payment_webhooks (
    id VARCHAR(255) PRIMARY KEY,
    provider_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- 'payment.succeeded', 'subscription.created', etc.
    payload JSONB NOT NULL,
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
    data JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Membership Types
CREATE TABLE IF NOT EXISTS membership_types (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    duration_type VARCHAR(50) NOT NULL, -- 'recurring', 'fixed', 'lifetime'
    duration_days INTEGER, -- NULL para 'lifetime'
    price_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    features JSONB, -- Array de features incluidas en esta membresía
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER update_membership_types_timestamp
BEFORE UPDATE ON membership_types
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- User Memberships
CREATE TABLE IF NOT EXISTS user_memberships (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    membership_type_id VARCHAR(255) NOT NULL,
    subscription_id VARCHAR(255), -- Para membresías recurrentes
    order_id VARCHAR(255), -- Para compras únicas
    status VARCHAR(50) NOT NULL, -- 'active', 'expired', 'cancelled', 'pending'
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP, -- NULL para membresías de por vida
    auto_renew BOOLEAN NOT NULL DEFAULT false,
    addons JSONB, -- Array de addons comprados con sus fechas de expiración
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (membership_type_id) REFERENCES membership_types(id) ON DELETE RESTRICT,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

CREATE TRIGGER update_user_memberships_timestamp
BEFORE UPDATE ON user_memberships
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();



-- Indexes for performance
-- Token indexes
CREATE INDEX idx_token_lookup ON tokens(token, status, expires_at);
CREATE INDEX idx_identifier_lookup ON tokens(type, identifier_value, status);
CREATE INDEX idx_user_tokens ON tokens(user_id, token_type, status);
CREATE INDEX idx_expiration_cleanup ON tokens(expires_at, status);
CREATE INDEX idx_token_type_status ON tokens(token_type, status);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_organization_id ON addresses(organization_id);
CREATE INDEX idx_addresses_type ON addresses(address_type);

CREATE INDEX idx_provider_customers_user_id ON provider_customers(user_id);
CREATE INDEX idx_provider_customers_organization_id ON provider_customers(organization_id);
CREATE INDEX idx_provider_customers_is_guest ON provider_customers(is_guest);
CREATE INDEX idx_provider_customers_guest_email ON provider_customers(guest_email);

CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_organization_id ON payment_methods(organization_id);
CREATE INDEX idx_payment_methods_is_guest ON payment_methods(is_guest);
CREATE INDEX idx_payment_methods_guest_email ON payment_methods(guest_email);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_organization_id ON addresses(organization_id);
CREATE INDEX idx_addresses_is_guest ON addresses(is_guest);
CREATE INDEX idx_addresses_guest_email ON addresses(guest_email);
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
CREATE INDEX idx_user_memberships_status ON user_memberships(status);
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
    breakdown JSONB, -- Detailed breakdown of the metric
    calculation_method VARCHAR(50) DEFAULT 'scheduled', -- 'scheduled', 'on_demand', 'manual'
    calculation_duration_ms INTEGER, -- How long the calculation took
    data_freshness VARCHAR(50) DEFAULT 'historical', -- 'historical', 'recent', 'real_time'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (snapshot_date, metric_type, currency)
);

CREATE TRIGGER update_analytics_snapshots_timestamp
BEFORE UPDATE ON analytics_snapshots
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- Analytics Events (Optional - for detailed event tracking)
CREATE TABLE IF NOT EXISTS analytics_events (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    session_id VARCHAR(255),
    event_type VARCHAR(50) NOT NULL, -- 'payment_completed', 'subscription_created', etc.
    event_category VARCHAR(50), -- 'revenue', 'conversion', 'engagement'
    entity_type VARCHAR(50), -- 'order', 'subscription', 'membership'
    entity_id VARCHAR(255),
    properties JSONB, -- Event-specific data
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
    UNIQUE (user_id, cohort_type)
);

-- Analytics Indexes
CREATE INDEX idx_analytics_snapshots_date_type ON analytics_snapshots(snapshot_date, metric_type);
CREATE INDEX idx_analytics_snapshots_currency ON analytics_snapshots(currency);

CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_events_category ON analytics_events(event_category);

CREATE INDEX idx_user_cohorts_month ON user_cohorts(cohort_month);
CREATE INDEX idx_user_cohorts_type ON user_cohorts(cohort_type);
