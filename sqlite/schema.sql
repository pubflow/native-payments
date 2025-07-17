-- SQLite Schema for Native Payments System

-- Enable foreign keys
PRAGMA foreign_keys = ON;

-- Users Table (Enhanced) - Uses Soft Delete Strategy
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT, -- Optional: first name
    last_name TEXT, -- Optional: last name
    email TEXT NOT NULL UNIQUE,
    user_type TEXT NOT NULL, -- 'individual', 'business', 'admin'
    picture TEXT,
    user_name TEXT UNIQUE,
    password_hash TEXT,
    phone TEXT UNIQUE, -- Optional phone number for SMS authentication (unique)
    is_verified INTEGER NOT NULL DEFAULT 0, -- Boolean: 0=false, 1=true
    is_locked INTEGER NOT NULL DEFAULT 0, -- Boolean: 0=false, 1=true
    two_factor INTEGER NOT NULL DEFAULT 0, -- Boolean: 0=false, 1=true (indicates if 2FA is enabled)
    lang TEXT NULL, -- Optional language preference (e.g., 'en', 'es', 'ja')
    metadata TEXT, -- JSON string for additional user information in English
    first_time INTEGER NOT NULL DEFAULT 1, -- Boolean: 0=false, 1=true

    -- Soft Delete Fields
    deleted_at TEXT NULL, -- Timestamp when user was deleted (NULL = active)
    deletion_reason TEXT NULL, -- Reason for deletion ('user_request', 'admin_action', 'gdpr_compliance', etc.)

    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

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
CREATE INDEX IF NOT EXISTS idx_users_locked_status ON users(is_locked) WHERE deleted_at IS NULL AND is_locked = 1;
CREATE INDEX IF NOT EXISTS idx_users_two_factor ON users(two_factor) WHERE deleted_at IS NULL AND two_factor = 1;

-- Temporal indexes for analytics and maintenance
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_updated_at ON users(updated_at) WHERE deleted_at IS NULL;

-- Language and metadata indexes
CREATE INDEX IF NOT EXISTS idx_users_lang ON users(lang) WHERE deleted_at IS NULL AND lang IS NOT NULL;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_users_type_verified ON users(user_type, is_verified) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_email_type ON users(email, user_type) WHERE deleted_at IS NULL;

-- Trigger for updated_at on users
CREATE TRIGGER IF NOT EXISTS update_users_timestamp
AFTER UPDATE ON users
BEGIN
    UPDATE users SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Tokens (Authentication & Security)
CREATE TABLE IF NOT EXISTS tokens (
    id TEXT PRIMARY KEY,
    token TEXT UNIQUE NOT NULL, -- Hashed token for security
    type TEXT NOT NULL, -- 'email', 'phone', 'username'
    identifier_value TEXT NOT NULL, -- The actual identifier value
    token_type TEXT NOT NULL, -- 'magic_link', 'password_reset', 'email_verification', 'phone_verification'
    user_id TEXT NULL, -- NULL for guest tokens, user ID for registered users

    -- Simple attempt system
    attempts_remaining INTEGER NOT NULL DEFAULT 1, -- How many attempts are left

    -- Basic states and timestamps
    status TEXT DEFAULT 'active', -- 'active', 'consumed', 'expired', 'revoked'
    expires_at TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    consumed_at TEXT NULL, -- When the token was successfully consumed

    -- Optional context and metadata
    context TEXT NULL, -- Optional context for two-factor validation (e.g., 'change_username_samuelorecio_to_michaeljackson')
    metadata TEXT NULL, -- JSON string

    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Trigger for updated_at on tokens
CREATE TRIGGER IF NOT EXISTS update_tokens_timestamp
AFTER UPDATE ON tokens
BEGIN
    UPDATE tokens SET updated_at = datetime('now') WHERE id = NEW.id;
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
    alias TEXT, -- User-friendly name for the address (e.g., "Home", "Office", "Mom's house")
    is_guest INTEGER NOT NULL DEFAULT 0, -- Indicates if this is a guest address (0 = false, 1 = true)
    guest_email TEXT, -- Email for guest addresses (for identification)
    guest_name TEXT, -- Name for guest addresses
    metadata TEXT, -- JSON string for additional address information (e.g., category, notes)
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
    payment_type TEXT NOT NULL, -- 'credit_card', 'bank_account', 'paypal', 'wallet', etc.
    wallet_type TEXT, -- 'apple_pay', 'google_pay', 'samsung_pay', etc. (only for wallet payment types)
    last_four TEXT, -- Last 4 digits of card or account
    expiry_month TEXT, -- Expiration month (for cards)
    expiry_year TEXT, -- Expiration year (for cards)
    card_brand TEXT, -- 'visa', 'mastercard', etc.
    is_default INTEGER NOT NULL DEFAULT 0,
    billing_address_id TEXT,
    alias TEXT, -- User-friendly name for the payment method (e.g., "My primary card", "Travel card")
    is_guest INTEGER NOT NULL DEFAULT 0, -- Indicates if this is a guest payment method (0 = false, 1 = true)
    guest_email TEXT, -- Email for guest payment methods (for identification)
    guest_name TEXT, -- Name for guest payment methods
    metadata TEXT, -- JSON string for additional payment method information (e.g., category, notes)
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

-- Products/Plans (Products only have base price - tax calculated dynamically at purchase)
CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    product_type TEXT NOT NULL, -- 'physical', 'digital', 'service', 'subscription'
    is_recurring INTEGER NOT NULL DEFAULT 0,

    -- PRODUCT PRICING (only base price - tax calculated dynamically)
    subtotal_cents INTEGER NOT NULL, -- Base product price (before tax/discounts)

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
    customer_id TEXT, -- References provider_customers table (supports registered guests)

    -- Anonymous guest support
    is_guest_order INTEGER NOT NULL DEFAULT 0, -- Track if this was an anonymous guest order (0 = false, 1 = true)
    guest_data TEXT, -- JSON string with anonymous guest information (email, name, phone, etc.)
    guest_email TEXT, -- Extracted guest email for indexing and queries

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
    FOREIGN KEY (customer_id) REFERENCES provider_customers(id) ON DELETE SET NULL,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_order = 1), -- Must belong to a user, organization, customer, or be an anonymous guest order
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents) -- Pricing validation
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

    -- NEW UNIFIED PRICING SYSTEM
    subtotal_cents INTEGER NOT NULL, -- Base subscription price
    tax_cents INTEGER NOT NULL DEFAULT 0, -- Applied taxes
    discount_cents INTEGER NOT NULL DEFAULT 0, -- Applied discounts
    total_cents INTEGER NOT NULL, -- Final subscription price (subtotal + tax - discount)

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

    -- Enhanced tracking fields (inspired by payments table)
    description TEXT, -- Human-readable description (e.g., "Premium Monthly Plan", "Basic Annual Subscription")
    concept TEXT, -- Human-readable concept (e.g., "Monthly Subscription", "Annual Plan", "Trial Subscription")
    reference_code TEXT, -- Machine-readable code for analytics (e.g., "subscription_monthly", "plan_premium_annual")
    category TEXT, -- High-level category (e.g., "subscription", "trial", "upgrade", "downgrade")
    tags TEXT, -- Comma-separated tags for flexible categorization (e.g., "promotion,summer,discount,premium")

    -- Guest subscription support (inspired by payments table)
    is_guest_subscription INTEGER NOT NULL DEFAULT 0, -- Track if this is a guest subscription (0 = false, 1 = true)
    guest_data TEXT, -- JSON string with guest information (email, name, phone, etc.)
    guest_email TEXT, -- Extracted guest email for indexing and queries
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES provider_customers(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_subscription = 1), -- Must belong to a user, organization, have a customer, or be guest subscription
    CHECK (billing_interval IN ('daily', 'weekly', 'monthly', 'yearly')),
    CHECK (interval_multiplier IS NULL OR (interval_multiplier > 0 AND interval_multiplier <= 12)),
    CHECK (billing_status IN ('active', 'past_due', 'suspended', 'cancelled')),
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents) -- Pricing validation
);

-- Trigger for updated_at on subscriptions
CREATE TRIGGER IF NOT EXISTS update_subscriptions_timestamp
AFTER UPDATE ON subscriptions
BEGIN
    UPDATE subscriptions SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Payments (Enhanced with financial breakdown and custom payment support)
CREATE TABLE IF NOT EXISTS payments (
    id TEXT PRIMARY KEY,
    order_id TEXT,
    subscription_id TEXT,
    user_id TEXT, -- Made optional for guest checkout
    organization_id TEXT,
    payment_method_id TEXT,
    provider_id TEXT, -- Made optional for custom payments
    provider_payment_id TEXT, -- Final payment ID from provider
    provider_intent_id TEXT, -- Intent ID from provider (e.g., Stripe payment intent)
    client_secret TEXT, -- Client secret for frontend confirmation

    -- NEW UNIFIED PRICING SYSTEM
    subtotal_cents INTEGER NOT NULL, -- Base amount before taxes and discounts
    tax_cents INTEGER NOT NULL DEFAULT 0, -- Applied taxes
    discount_cents INTEGER NOT NULL DEFAULT 0, -- Applied discounts
    total_cents INTEGER NOT NULL, -- Final amount (subtotal + tax - discount)

    currency TEXT NOT NULL DEFAULT 'USD',
    status TEXT NOT NULL, -- 'pending', 'requires_confirmation', 'requires_action', 'processing', 'succeeded', 'failed', 'refunded'
    description TEXT,
    error_message TEXT,

    -- Enhanced tracking fields
    concept TEXT, -- Human-readable concept (e.g., "Monthly Subscription", "Product Purchase", "Donation")
    reference_code TEXT, -- Machine-readable code for analytics and payment links
    category TEXT, -- High-level category (e.g., "subscription", "donation", "purchase", "refund", "fee")
    tags TEXT, -- Comma-separated tags for flexible categorization

    -- Custom/Manual payment support
    is_manual_payment INTEGER NOT NULL DEFAULT 0, -- For manual/legacy payments
    manual_payment_method TEXT, -- 'cash', 'check', 'bank_transfer', 'legacy_system'
    manual_payment_reference TEXT, -- Reference for manual payment
    manual_payment_date TEXT, -- Actual date of manual payment

    -- Guest support
    is_guest_payment INTEGER NOT NULL DEFAULT 0, -- Track if this was a guest payment (0 = false, 1 = true)
    guest_data TEXT, -- JSON string with guest information (email, name, phone, etc.)
    guest_email TEXT, -- Extracted guest email for indexing and queries

    -- Coupon tracking
    applied_coupons TEXT, -- JSON string of applied coupons with details

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

    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR is_guest_payment = 1),
    -- Allow direct payments (donations), order payments, subscription payments, or manual payments
    CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL OR is_manual_payment = 1 OR (order_id IS NULL AND subscription_id IS NULL)),
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents) -- Pricing validation
);

-- Trigger for updated_at on payments
CREATE TRIGGER IF NOT EXISTS update_payments_timestamp
AFTER UPDATE ON payments
BEGIN
    UPDATE payments SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Invoices (Enhanced with guest support and payment links)
CREATE TABLE IF NOT EXISTS invoices (
    id TEXT PRIMARY KEY,
    invoice_number TEXT UNIQUE NOT NULL,
    order_id TEXT,
    subscription_id TEXT,
    payment_id TEXT, -- Optional reference to payment (updated after payment completion)
    user_id TEXT,
    organization_id TEXT,
    customer_id TEXT, -- References provider_customers table (supports both users and guests)

    status TEXT NOT NULL, -- 'draft', 'open', 'paid', 'void', 'uncollectible'

    -- NEW UNIFIED PRICING SYSTEM (consistent with payments)
    subtotal_cents INTEGER NOT NULL, -- Base amount before taxes and discounts
    tax_cents INTEGER NOT NULL DEFAULT 0, -- Applied taxes
    discount_cents INTEGER NOT NULL DEFAULT 0, -- Applied discounts
    total_cents INTEGER NOT NULL, -- Final amount (subtotal + tax - discount)

    currency TEXT NOT NULL DEFAULT 'USD',
    issue_date TEXT NOT NULL,
    due_date TEXT NOT NULL,
    paid_date TEXT,

    -- Enhanced guest invoice support
    is_guest_invoice INTEGER NOT NULL DEFAULT 0,
    guest_data TEXT, -- JSON string with guest information for invoices
    guest_email TEXT, -- Extracted guest email for indexing

    -- Payment link support
    reference_code TEXT, -- For referencing specific payments
    payment_link_url TEXT, -- Unique URL to pay this invoice
    payment_link_expires_at TEXT, -- Payment link expiration

    -- Payment method tracking (saved when payment is completed)
    payment_method_id TEXT, -- Payment method used for this invoice (updated after payment)

    billing_address TEXT, -- JSON string
    provider_id TEXT,
    provider_invoice_id TEXT,
    invoice_url TEXT, -- Optional friendly URL to access the invoice

    -- Coupon tracking
    applied_coupons TEXT, -- JSON string of applied coupons to this invoice

    metadata TEXT, -- JSON string
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES provider_customers(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE SET NULL,

    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_invoice = 1),
    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents) -- Pricing validation
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
-- Token indexes
CREATE INDEX idx_token_lookup ON tokens(token, status, expires_at);
CREATE INDEX idx_identifier_lookup ON tokens(type, identifier_value, status);
CREATE INDEX idx_user_tokens ON tokens(user_id, token_type, status);
CREATE INDEX idx_expiration_cleanup ON tokens(expires_at, status);
CREATE INDEX idx_token_type_status ON tokens(token_type, status);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_organization_id ON addresses(organization_id);
CREATE INDEX idx_addresses_address_type ON addresses(address_type);
CREATE INDEX idx_addresses_is_guest ON addresses(is_guest);
CREATE INDEX idx_addresses_guest_email ON addresses(guest_email);
CREATE INDEX idx_addresses_is_default ON addresses(is_default);
CREATE INDEX idx_addresses_alias ON addresses(alias) WHERE alias IS NOT NULL;

CREATE INDEX idx_provider_customers_user_id ON provider_customers(user_id);
CREATE INDEX idx_provider_customers_organization_id ON provider_customers(organization_id);
CREATE INDEX idx_provider_customers_is_guest ON provider_customers(is_guest);
CREATE INDEX idx_provider_customers_guest_email ON provider_customers(guest_email);

CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_organization_id ON payment_methods(organization_id);
CREATE INDEX idx_payment_methods_is_guest ON payment_methods(is_guest);
CREATE INDEX idx_payment_methods_guest_email ON payment_methods(guest_email);
CREATE INDEX idx_payment_methods_alias ON payment_methods(alias) WHERE alias IS NOT NULL;

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

-- ========================================
-- DISCOUNT COUPONS SYSTEM
-- ========================================

-- Discount Coupons
CREATE TABLE IF NOT EXISTS discount_coupons (
    id TEXT PRIMARY KEY,

    -- Basic coupon information
    code TEXT UNIQUE NOT NULL, -- Unique coupon code (e.g., "SUMMER2024", "WELCOME10")
    name TEXT NOT NULL, -- Friendly name (e.g., "Summer Discount 2024")
    description TEXT, -- Detailed description of the coupon

    -- Discount type and value
    discount_type TEXT NOT NULL, -- 'percentage', 'fixed_amount', 'free_shipping', 'buy_x_get_y'
    discount_value REAL NOT NULL, -- Discount value (percentage or fixed amount)
    currency TEXT DEFAULT 'USD', -- Currency for fixed amount discounts

    -- Limits and restrictions
    minimum_amount_cents INTEGER DEFAULT 0, -- Minimum amount to apply coupon
    maximum_discount_cents INTEGER, -- Maximum discount (useful for percentages)
    usage_limit INTEGER, -- Total usage limit (NULL = unlimited)
    usage_limit_per_customer INTEGER, -- Limit per customer (NULL = unlimited per customer)
    current_usage_count INTEGER NOT NULL DEFAULT 0, -- Current usage counter

    -- Validity dates
    starts_at TEXT, -- Start date (NULL = immediate)
    expires_at TEXT, -- Expiration date (NULL = no expiration)

    -- Applicability restrictions
    applicable_to TEXT NOT NULL DEFAULT 'all', -- 'all', 'products', 'categories', 'subscriptions'
    applicable_product_ids TEXT, -- JSON string of specific product IDs
    applicable_category_ids TEXT, -- JSON string of specific category IDs
    excluded_product_ids TEXT, -- JSON string of excluded product IDs

    -- User restrictions
    applicable_user_types TEXT, -- JSON string of user types ('individual', 'business', etc.)
    applicable_customer_segments TEXT, -- JSON string of customer segments
    first_time_customers_only INTEGER NOT NULL DEFAULT 0, -- Only for new customers

    -- State and configuration
    is_active INTEGER NOT NULL DEFAULT 1,
    is_stackable INTEGER NOT NULL DEFAULT 0, -- Can be combined with other coupons
    auto_apply INTEGER NOT NULL DEFAULT 0, -- Automatically applied if conditions are met

    -- Tracking and analytics
    campaign_id TEXT, -- Marketing campaign ID
    source TEXT, -- Coupon source ('email', 'social', 'affiliate', etc.)
    tags TEXT, -- Tags for flexible categorization

    -- Advanced configuration
    buy_x_get_y_config TEXT, -- JSON string for "buy X get Y" offers
    tier_discounts TEXT, -- JSON string for tiered discounts

    metadata TEXT, -- JSON string for additional metadata
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_by TEXT, -- User who created the coupon

    CHECK (discount_type IN ('percentage', 'fixed_amount', 'free_shipping', 'buy_x_get_y')),
    CHECK (applicable_to IN ('all', 'products', 'categories', 'subscriptions')),
    CHECK (discount_value >= 0),
    CHECK (usage_limit IS NULL OR usage_limit > 0),
    CHECK (usage_limit_per_customer IS NULL OR usage_limit_per_customer > 0),
    CHECK (current_usage_count >= 0)
);

-- Trigger for updated_at on discount_coupons
CREATE TRIGGER IF NOT EXISTS update_discount_coupons_timestamp
AFTER UPDATE ON discount_coupons
BEGIN
    UPDATE discount_coupons SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- Coupon Usage Tracking
CREATE TABLE IF NOT EXISTS coupon_usage (
    id TEXT PRIMARY KEY,
    coupon_id TEXT NOT NULL,

    -- Who used the coupon
    user_id TEXT,
    customer_id TEXT, -- For guests
    guest_email TEXT, -- For anonymous guests

    -- Where it was used
    order_id TEXT,
    subscription_id TEXT,
    payment_id TEXT,
    invoice_id TEXT,

    -- Usage details
    discount_amount_cents INTEGER NOT NULL, -- Actual discount applied
    original_amount_cents INTEGER NOT NULL, -- Original amount before discount
    final_amount_cents INTEGER NOT NULL, -- Final amount after discount
    currency TEXT NOT NULL DEFAULT 'USD',

    -- Usage metadata
    usage_context TEXT, -- JSON string for additional context of usage
    ip_address TEXT, -- IP address (for fraud detection)
    user_agent TEXT, -- User agent (for analytics)

    created_at TEXT NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (coupon_id) REFERENCES discount_coupons(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (customer_id) REFERENCES provider_customers(id) ON DELETE SET NULL,
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
    id TEXT PRIMARY KEY,

    -- Basic tax information
    name TEXT NOT NULL, -- "Sales Tax", "IVA", "GST", "VAT"
    description TEXT, -- Detailed description
    rate REAL NOT NULL, -- Tax rate (0.0360 = 3.6%)
    type TEXT NOT NULL DEFAULT 'percentage', -- 'percentage', 'fixed_amount'

    -- Geographic applicability
    country TEXT, -- 'US', 'MX', 'ES', 'CA'
    state_province TEXT, -- 'CA', 'TX', 'CDMX', 'ON'
    city TEXT, -- 'New York', 'Los Angeles'
    postal_code TEXT, -- Specific postal codes

    -- Product/Category applicability (optional filters)
    applicable_categories TEXT, -- JSON string of category_ids ["clothing", "electronics"]
    applicable_product_types TEXT, -- JSON string of product_types ["physical", "digital"]
    excluded_categories TEXT, -- JSON string of excluded category_ids
    excluded_product_types TEXT, -- JSON string of excluded product_types

    -- Configuration
    is_active INTEGER NOT NULL DEFAULT 1,
    priority INTEGER DEFAULT 0, -- Higher priority wins in conflicts
    effective_from TEXT, -- When this rate becomes effective
    effective_until TEXT, -- When this rate expires

    -- Additional data
    metadata TEXT, -- JSON string for additional tax configuration
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_by TEXT, -- User who created this rate

    -- Validations
    CHECK (rate >= 0),
    CHECK (type IN ('percentage', 'fixed_amount')),
    CHECK (priority >= 0)
);

-- Trigger for updated_at on tax_rates
CREATE TRIGGER IF NOT EXISTS update_tax_rates_timestamp
AFTER UPDATE ON tax_rates
BEGIN
    UPDATE tax_rates SET updated_at = datetime('now') WHERE id = NEW.id;
END;

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