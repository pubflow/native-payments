-- SQLite Schema for Native Payments System

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- Users Table (Enhanced)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    user_type TEXT NOT NULL, -- 'individual', 'business', 'admin'
    picture TEXT,
    user_name TEXT UNIQUE,
    password_hash TEXT,
    recovery_email TEXT,
    phone TEXT,
    is_verified INTEGER NOT NULL DEFAULT 0, -- Boolean: 0=false, 1=true
    is_locked INTEGER NOT NULL DEFAULT 0, -- Boolean: 0=false, 1=true
    two_factor INTEGER NOT NULL DEFAULT 0, -- Boolean: 0=false, 1=true (indicates if 2FA is enabled)
    passkeys TEXT, -- JSON string for multiple passkeys
    metadata TEXT, -- JSON string for additional user information
    first_time INTEGER NOT NULL DEFAULT 1, -- Boolean: 0=false, 1=true
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Trigger for updated_at on users
CREATE TRIGGER IF NOT EXISTS update_users_timestamp
AFTER UPDATE ON users
BEGIN
    UPDATE users SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Organizations
CREATE TABLE IF NOT EXISTS organizations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner_user_id TEXT NOT NULL,
    business_email TEXT,
    business_phone TEXT,
    tax_id TEXT,
    address TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Trigger for updated_at on organizations
CREATE TRIGGER IF NOT EXISTS update_organizations_timestamp
AFTER UPDATE ON organizations
BEGIN
    UPDATE organizations SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TABLE IF NOT EXISTS organization_users (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'billing', 'member'
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE (organization_id, user_id)
);

-- Trigger for updated_at on organization_users
CREATE TRIGGER IF NOT EXISTS update_organization_users_timestamp
AFTER UPDATE ON organization_users
BEGIN
    UPDATE organization_users SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Addresses
CREATE TABLE IF NOT EXISTS addresses (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    organization_id TEXT,
    address_type TEXT NOT NULL, -- 'billing', 'shipping', 'both'
    is_default INTEGER NOT NULL DEFAULT 0,
    name TEXT,
    line1 TEXT NOT NULL,
    line2 TEXT,
    city TEXT NOT NULL,
    state TEXT,
    postal_code TEXT NOT NULL,
    country TEXT NOT NULL, -- ISO 2-letter country code
    phone TEXT,
    email TEXT,
    is_guest INTEGER NOT NULL DEFAULT 0, -- Indicates if this is a guest address (0 = false, 1 = true)
    guest_email TEXT, -- Email for guest addresses (for identification)
    guest_name TEXT, -- Name for guest addresses
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = 1) -- Must belong to either a user, organization, or be a guest
);

-- Trigger for updated_at on addresses
CREATE TRIGGER IF NOT EXISTS update_addresses_timestamp
AFTER UPDATE ON addresses
BEGIN
    UPDATE addresses SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Payment Providers
CREATE TABLE IF NOT EXISTS payment_providers (
    id TEXT PRIMARY KEY, -- 'stripe', 'paypal', 'authorize_net', etc.
    display_name TEXT NOT NULL,
    description TEXT, -- Description of the payment provider
    picture TEXT, -- URL to payment provider logo or icon
    is_active INTEGER NOT NULL DEFAULT 1,
    supports_subscriptions INTEGER NOT NULL DEFAULT 0,
    supports_saved_methods INTEGER NOT NULL DEFAULT 0,
    config TEXT, -- JSON string for provider-specific configuration
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Trigger for updated_at on payment_providers
CREATE TRIGGER IF NOT EXISTS update_payment_providers_timestamp
AFTER UPDATE ON payment_providers
BEGIN
    UPDATE payment_providers SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Provider Customers
CREATE TABLE IF NOT EXISTS provider_customers (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    organization_id TEXT,
    provider_id TEXT NOT NULL,
    provider_customer_id TEXT NOT NULL, -- ID from the provider (e.g., Stripe customer ID)
    guest_email TEXT, -- Email for guest customers
    guest_name TEXT, -- Name for guest customers
    is_guest INTEGER NOT NULL DEFAULT 0, -- Indicates if this is a guest customer (0 = false, 1 = true)
    metadata TEXT, -- JSON string
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    UNIQUE (provider_id, provider_customer_id),
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = 1) -- Must belong to either a user, organization, or be a guest
);

-- Trigger for updated_at on provider_customers
CREATE TRIGGER IF NOT EXISTS update_provider_customers_timestamp
AFTER UPDATE ON provider_customers
BEGIN
    UPDATE provider_customers SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Payment Methods
CREATE TABLE IF NOT EXISTS payment_methods (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    organization_id TEXT,
    provider_id TEXT NOT NULL,
    provider_payment_method_id TEXT NOT NULL, -- ID from the provider
    payment_type TEXT NOT NULL, -- 'credit_card', 'bank_account', 'paypal', etc.
    last_four TEXT, -- Last 4 digits of card or account
    expiry_month TEXT, -- Expiration month (for cards)
    expiry_year TEXT, -- Expiration year (for cards)
    card_brand TEXT, -- 'visa', 'mastercard', etc.
    is_default INTEGER NOT NULL DEFAULT 0,
    billing_address_id TEXT,
    is_guest INTEGER NOT NULL DEFAULT 0, -- Indicates if this is a guest payment method (0 = false, 1 = true)
    guest_email TEXT, -- Email for guest payment methods (for identification)
    guest_name TEXT, -- Name for guest payment methods
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest = 1) -- Must belong to either a user, organization, or be a guest
);

-- Trigger for updated_at on payment_methods
CREATE TRIGGER IF NOT EXISTS update_payment_methods_timestamp
AFTER UPDATE ON payment_methods
BEGIN
    UPDATE payment_methods SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Product Categories
CREATE TABLE IF NOT EXISTS product_categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    parent_id TEXT,
    image TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (parent_id) REFERENCES product_categories(id) ON DELETE SET NULL
);

-- Trigger for updated_at on product_categories
CREATE TRIGGER IF NOT EXISTS update_product_categories_timestamp
AFTER UPDATE ON product_categories
BEGIN
    UPDATE product_categories SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Products/Plans
CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    product_type TEXT NOT NULL, -- 'physical', 'digital', 'service', 'subscription'
    is_recurring INTEGER NOT NULL DEFAULT 0,
    price_cents INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    billing_interval TEXT, -- 'monthly', 'yearly', null for one-time
    trial_days INTEGER DEFAULT 0,
    image TEXT, -- Main product image URL
    gallery TEXT, -- JSON array of additional image URLs
    category_id TEXT,
    parent_product_id TEXT, -- For product variations, references the parent product
    variations TEXT, -- JSON array of variation options (e.g., size, color)
    metadata TEXT, -- JSON string
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (category_id) REFERENCES product_categories(id) ON DELETE SET NULL,
    FOREIGN KEY (parent_product_id) REFERENCES products(id) ON DELETE SET NULL
);

-- Trigger for updated_at on products
CREATE TRIGGER IF NOT EXISTS update_products_timestamp
AFTER UPDATE ON products
BEGIN
    UPDATE products SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Orders
CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY,
    order_number TEXT UNIQUE NOT NULL, -- Human-readable order number
    user_id TEXT,
    organization_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'paid', 'cancelled', 'refunded'
    subtotal_cents INTEGER NOT NULL,
    tax_cents INTEGER NOT NULL DEFAULT 0,
    discount_cents INTEGER NOT NULL DEFAULT 0,
    total_cents INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    billing_address TEXT, -- JSON string
    shipping_address TEXT, -- JSON string
    metadata TEXT, -- JSON string
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL) -- Must belong to either a user or organization
);

-- Trigger for updated_at on orders
CREATE TRIGGER IF NOT EXISTS update_orders_timestamp
AFTER UPDATE ON orders
BEGIN
    UPDATE orders SET updated_at = datetime('now') WHERE id = NEW.id;
END;

CREATE TABLE IF NOT EXISTS order_items (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_cents INTEGER NOT NULL,
    total_cents INTEGER NOT NULL,
    metadata TEXT, -- JSON string
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);

-- Subscriptions (Enhanced with guest support via customer_id and automatic billing)
CREATE TABLE IF NOT EXISTS subscriptions (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    organization_id TEXT,
    customer_id TEXT NOT NULL, -- References provider_customers table (supports both users and guests)
    product_id TEXT, -- Optional for custom donations/flexible subscriptions
    payment_method_id TEXT,
    provider_id TEXT NOT NULL,
    provider_subscription_id TEXT,
    status TEXT NOT NULL, -- 'active', 'cancelled', 'past_due', 'trialing', 'incomplete', 'incomplete_expired'
    current_period_start TEXT NOT NULL,
    current_period_end TEXT NOT NULL,
    cancel_at_period_end INTEGER NOT NULL DEFAULT 0,
    trial_end TEXT,
    price_cents INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    -- Billing automation fields
    billing_interval TEXT NOT NULL DEFAULT 'monthly', -- 'daily', 'weekly', 'monthly', 'yearly'
    interval_multiplier INTEGER DEFAULT 1, -- Optional: 2 for every 2 months, 3 for every 3 weeks, etc.
    next_billing_date TEXT, -- When the next billing should occur (ISO 8601 format)
    last_billing_attempt TEXT, -- Last time we attempted to bill this subscription (ISO 8601 format)
    billing_retry_count INTEGER NOT NULL DEFAULT 0, -- Number of failed billing attempts
    max_retry_attempts INTEGER NOT NULL DEFAULT 3, -- Maximum retry attempts before suspension
    billing_status TEXT NOT NULL DEFAULT 'active', -- 'active', 'past_due', 'suspended', 'cancelled'
    metadata TEXT, -- JSON string
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
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

-- Trigger for updated_at on subscriptions
CREATE TRIGGER IF NOT EXISTS update_subscriptions_timestamp
AFTER UPDATE ON subscriptions
BEGIN
    UPDATE subscriptions SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Payments (Enhanced with guest checkout support and payment intent functionality)
CREATE TABLE IF NOT EXISTS payments (
    id TEXT PRIMARY KEY,
    order_id TEXT,
    subscription_id TEXT,
    user_id TEXT, -- Made optional for guest checkout
    organization_id TEXT,
    payment_method_id TEXT,
    provider_id TEXT NOT NULL,
    provider_payment_id TEXT, -- Final payment ID from provider
    provider_intent_id TEXT, -- Intent ID from provider (e.g., Stripe payment intent)
    client_secret TEXT, -- Client secret for frontend confirmation
    amount_cents INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    status TEXT NOT NULL, -- 'pending', 'requires_confirmation', 'requires_action', 'processing', 'succeeded', 'failed', 'refunded'
    description TEXT,
    error_message TEXT,
    -- Enhanced tracking fields
    concept TEXT, -- Human-readable concept (e.g., "Monthly Subscription", "Product Purchase", "Donation")
    reference_code TEXT, -- Machine-readable code for analytics (e.g., "subscription_monthly", "donation_campaign_2024")
    category TEXT, -- High-level category (e.g., "subscription", "donation", "purchase", "refund", "fee")
    tags TEXT, -- Comma-separated tags for flexible categorization (e.g., "promotion,summer,discount")
    is_guest_payment INTEGER NOT NULL DEFAULT 0, -- Track if this was a guest payment (0 = false, 1 = true)
    guest_data TEXT, -- JSON string with guest information (email, name, phone, etc.)
    guest_email TEXT, -- Extracted guest email for indexing and queries
    metadata TEXT, -- JSON string
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    completed_at TEXT,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest_payment = 1) -- Must belong to a user, organization, or be guest payment
);

-- Trigger for updated_at on payments
CREATE TRIGGER IF NOT EXISTS update_payments_timestamp
AFTER UPDATE ON payments
BEGIN
    UPDATE payments SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Invoices
CREATE TABLE IF NOT EXISTS invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT UNIQUE NOT NULL,
    order_id TEXT,
    subscription_id TEXT,
    user_id TEXT,
    organization_id TEXT,
    status TEXT NOT NULL, -- 'draft', 'open', 'paid', 'void', 'uncollectible'
    amount_cents INTEGER NOT NULL,
    tax_cents INTEGER NOT NULL DEFAULT 0,
    discount_cents INTEGER NOT NULL DEFAULT 0,
    total_cents INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    issue_date TEXT NOT NULL,
    due_date TEXT NOT NULL,
    paid_date TEXT,
    billing_address TEXT, -- JSON string
    provider_id TEXT,
    provider_invoice_id TEXT,
    invoice_url TEXT, -- Optional friendly URL to access the invoice
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE SET NULL
);

-- Trigger for updated_at on invoices
CREATE TRIGGER IF NOT EXISTS update_invoices_timestamp
AFTER UPDATE ON invoices
BEGIN
    UPDATE invoices SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Webhooks and Events
CREATE TABLE IF NOT EXISTS payment_webhooks (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'payment.succeeded', 'subscription.created', etc.
    payload TEXT NOT NULL, -- JSON string
    processed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    processed_at TEXT,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS payment_events (
    id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL, -- 'payment', 'subscription', 'order', etc.
    entity_id TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'created', 'updated', 'failed', etc.
    data TEXT, -- JSON string
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Membership Types
CREATE TABLE IF NOT EXISTS membership_types (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    duration_type TEXT NOT NULL, -- 'recurring', 'fixed', 'lifetime'
    duration_days INTEGER, -- NULL for 'lifetime' memberships
    price_cents INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    features TEXT, -- JSON array of features included in this membership
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Trigger for updated_at on membership_types
CREATE TRIGGER IF NOT EXISTS update_membership_types_timestamp
AFTER UPDATE ON membership_types
BEGIN
    UPDATE membership_types SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- User Memberships
CREATE TABLE IF NOT EXISTS user_memberships (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    membership_type_id TEXT NOT NULL,
    subscription_id TEXT, -- For recurring memberships
    order_id TEXT, -- For one-time purchases
    status TEXT NOT NULL, -- 'active', 'expired', 'cancelled', 'pending'
    start_date TEXT NOT NULL,
    end_date TEXT, -- NULL for lifetime memberships
    auto_renew INTEGER NOT NULL DEFAULT 0,
    addons TEXT, -- JSON array of purchased addons with their expiration dates
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (membership_type_id) REFERENCES membership_types(id) ON DELETE RESTRICT,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

-- Trigger for updated_at on user_memberships
CREATE TRIGGER IF NOT EXISTS update_user_memberships_timestamp
AFTER UPDATE ON user_memberships
BEGIN
    UPDATE user_memberships SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Indexes for performance
CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_organization_id ON addresses(organization_id);
CREATE INDEX idx_addresses_address_type ON addresses(address_type);
CREATE INDEX idx_addresses_is_guest ON addresses(is_guest);
CREATE INDEX idx_addresses_guest_email ON addresses(guest_email);
CREATE INDEX idx_addresses_is_default ON addresses(is_default);
CREATE INDEX idx_provider_customers_user_id ON provider_customers(user_id);
CREATE INDEX idx_provider_customers_organization_id ON provider_customers(organization_id);
CREATE INDEX idx_provider_customers_is_guest ON provider_customers(is_guest);
CREATE INDEX idx_provider_customers_guest_email ON provider_customers(guest_email);
CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_organization_id ON payment_methods(organization_id);
CREATE INDEX idx_payment_methods_is_guest ON payment_methods(is_guest);
CREATE INDEX idx_payment_methods_guest_email ON payment_methods(guest_email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_organization_id ON orders(organization_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_organization_id ON subscriptions(organization_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_next_billing ON subscriptions(next_billing_date, billing_status);
CREATE INDEX idx_subscriptions_billing_status ON subscriptions(billing_status);
CREATE INDEX idx_subscriptions_retry_billing ON subscriptions(last_billing_attempt, billing_retry_count);
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
    id TEXT PRIMARY KEY,
    snapshot_date TEXT NOT NULL, -- DATE format: YYYY-MM-DD
    metric_type TEXT NOT NULL, -- 'daily_revenue', 'active_subscriptions', etc.
    metric_value REAL NOT NULL,
    currency TEXT,
    breakdown TEXT, -- JSON string with detailed breakdown
    calculation_method TEXT DEFAULT 'scheduled', -- 'scheduled', 'on_demand', 'manual'
    calculation_duration_ms INTEGER, -- How long the calculation took
    data_freshness TEXT DEFAULT 'historical', -- 'historical', 'recent', 'real_time'
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(snapshot_date, metric_type, currency)
);

-- Trigger for updated_at on analytics_snapshots
CREATE TRIGGER IF NOT EXISTS update_analytics_snapshots_timestamp
AFTER UPDATE ON analytics_snapshots
BEGIN
    UPDATE analytics_snapshots SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Analytics Events (Optional - for detailed event tracking)
CREATE TABLE IF NOT EXISTS analytics_events (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    session_id TEXT,
    event_type TEXT NOT NULL, -- 'payment_completed', 'subscription_created', etc.
    event_category TEXT, -- 'revenue', 'conversion', 'engagement'
    entity_type TEXT, -- 'order', 'subscription', 'membership'
    entity_id TEXT,
    properties TEXT, -- JSON string with event-specific data
    revenue_cents INTEGER DEFAULT 0,
    currency TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- User Cohorts (Optional - for cohort analysis)
CREATE TABLE IF NOT EXISTS user_cohorts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    cohort_month TEXT NOT NULL, -- DATE format: YYYY-MM-01 (first day of month)
    cohort_type TEXT NOT NULL, -- 'first_purchase', 'first_subscription'
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, cohort_type)
);

-- Analytics Indexes
CREATE INDEX idx_analytics_snapshots_date_type ON analytics_snapshots(snapshot_date, metric_type);
CREATE INDEX idx_analytics_snapshots_currency ON analytics_snapshots(currency);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX idx_analytics_events_category ON analytics_events(event_category);
CREATE INDEX idx_user_cohorts_month ON user_cohorts(cohort_month);
CREATE INDEX idx_user_cohorts_type ON user_cohorts(cohort_type);