# Payment System Database Schema

This document outlines the database schema for a modular, multi-provider payment system that supports various business models including SaaS, eCommerce, and digital stores.

## Core Tables

### Tokens (Authentication & Security)

```sql
CREATE TABLE tokens (
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
    metadata JSON NULL,

    -- Foreign key constraint
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Performance indexes
CREATE INDEX idx_token_lookup ON tokens(token, status, expires_at);
CREATE INDEX idx_identifier_lookup ON tokens(type, identifier_value, status);
CREATE INDEX idx_user_tokens ON tokens(user_id, token_type, status);
CREATE INDEX idx_expiration_cleanup ON tokens(expires_at, status);
CREATE INDEX idx_token_type_status ON tokens(token_type, status);
```

**Key Features:**
- **Unified Token Management**: Single table for all token types (magic links, password reset, verification)
- **Security First**: Tokens are stored hashed, never in plain text
- **Built-in Rate Limiting**: Attempt system integrated directly into the token
- **Guest Support**: Works for both authenticated users and guests
- **Scalable Design**: Supports email, phone, and username identifiers
- **Context Support**: Optional context field for two-factor validation scenarios
- **Simple Status Management**: Clear token lifecycle with status tracking
- **Performance Optimized**: Strategic indexes for fast lookups and cleanup

**Enhanced User Profile Features:**
- **Extended Contact Information**: Primary phone, mobile, and recovery email support
- **Rich Profile Data**: Display name, bio, gender (ISO 5218), date of birth, and timezone
- **Global Localization**: Timezone-aware user profiles for international applications
- **External Integration**: Reference ID field for linking with external systems
- **Comprehensive Indexing**: Optimized indexes for all new profile fields

**Security Recommendations:**
- Always hash tokens before storing using a secure algorithm (e.g., SHA-256 with salt)
- Set appropriate expiration times (5-15 minutes for magic links, 1 hour for password reset)
- Implement automatic cleanup of expired tokens
- Use HTTPS for all token-related endpoints
- Log token usage for security auditing

**Usage Flow:**
1. **Create Token**: `attempts_remaining = 4` (configurable)
2. **Validate Token**: Each failed attempt decrements `attempts_remaining`
3. **Block Token**: When `attempts_remaining = 0`, token is blocked
4. **Consume Token**: Valid token sets `status = 'consumed'`

**Common Token Types:**
- `magic_link`: Passwordless authentication links
- `password_reset`: Password reset tokens
- `email_verification`: Email address verification
- `phone_verification`: Phone number verification

### Enhanced User Table (Hybrid Soft Delete + ON DELETE CASCADE Strategy)

```sql
-- Main users table with all user information including new fields
CREATE TABLE users (
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
    gender VARCHAR(1), -- ISO 5218: 'm', 'f', 'x'
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
);

-- ========================================
-- OPTIMIZED INDEXES FOR USERS TABLE
-- ========================================

-- Primary functional indexes
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_user_name ON users(user_name) WHERE deleted_at IS NULL AND user_name IS NOT NULL;
CREATE INDEX idx_users_user_type ON users(user_type) WHERE deleted_at IS NULL;

-- Soft delete indexes (for efficient queries on active/deleted users)
CREATE INDEX idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_deleted ON users(deleted_at, deletion_reason) WHERE deleted_at IS NOT NULL;

-- Authentication and verification indexes
CREATE INDEX idx_users_email_verified ON users(email, is_verified) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_verification_status ON users(is_verified) WHERE deleted_at IS NULL;

-- Search and filtering indexes
CREATE INDEX idx_users_name_search ON users(name, last_name) WHERE deleted_at IS NULL;

-- Security and account status indexes
CREATE INDEX idx_users_locked_status ON users(is_locked) WHERE deleted_at IS NULL AND is_locked = true;
CREATE INDEX idx_users_two_factor ON users(two_factor) WHERE deleted_at IS NULL AND two_factor = true;

-- Temporal indexes for analytics and maintenance
CREATE INDEX idx_users_created_at ON users(created_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_updated_at ON users(updated_at) WHERE deleted_at IS NULL;

-- Language and metadata indexes
CREATE INDEX idx_users_lang ON users(lang) WHERE deleted_at IS NULL AND lang IS NOT NULL;

-- New profile and contact indexes
CREATE INDEX idx_users_mobile ON users(mobile) WHERE deleted_at IS NULL AND mobile IS NOT NULL;
CREATE INDEX idx_users_recovery_email ON users(recovery_email) WHERE deleted_at IS NULL AND recovery_email IS NOT NULL;
CREATE INDEX idx_users_display_name ON users(display_name) WHERE deleted_at IS NULL AND display_name IS NOT NULL;
CREATE INDEX idx_users_gender ON users(gender) WHERE deleted_at IS NULL AND gender IS NOT NULL;
CREATE INDEX idx_users_dob ON users(dob) WHERE deleted_at IS NULL AND dob IS NOT NULL;
CREATE INDEX idx_users_tmz ON users(tmz) WHERE deleted_at IS NULL AND tmz IS NOT NULL;
CREATE INDEX idx_users_reference_id ON users(reference_id) WHERE deleted_at IS NULL AND reference_id IS NOT NULL;

-- Composite indexes for common query patterns
CREATE INDEX idx_users_type_verified ON users(user_type, is_verified) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_email_type ON users(email, user_type) WHERE deleted_at IS NULL;
```

## 🔄 **User Deletion Strategy**

### **Hybrid Approach: Soft Delete + ON DELETE CASCADE**

This system implements a flexible user deletion strategy that balances data retention, compliance requirements, and operational efficiency.

#### **Default Strategy: Soft Delete**
- **Purpose**: Preserve data for analytics, auditing, and accidental recovery
- **Implementation**: Set `deleted_at` timestamp and `deletion_reason`
- **Benefits**:
  - ✅ Data recovery possible
  - ✅ Historical analytics preserved
  - ✅ Audit trail maintained
  - ✅ No constraint violations

#### **Compliance Strategy: Hard Delete**
- **Purpose**: Complete data removal for GDPR/CCPA compliance
- **Implementation**: Physical deletion with `ON DELETE CASCADE`
- **Benefits**:
  - ✅ Complete data removal
  - ✅ Regulatory compliance
  - ✅ No orphaned records
  - ✅ Automatic cleanup

#### **Deletion Reasons**
- `user_request`: User-initiated account deletion
- `admin_action`: Administrative deletion
- `gdpr_compliance`: GDPR/CCPA compliance deletion
- `inactivity`: Automatic cleanup of inactive accounts
- `violation`: Terms of service violation

#### **Backend Implementation**
```javascript
// Soft delete (default)
await softDeleteUser(userId, 'user_request');

// Hard delete (compliance)
await hardDeleteUser(userId, 'gdpr_compliance');
```

### **Key Features:**
- **Soft Delete Fields**: `deleted_at`, `deletion_reason`
- **Optimized Indexes**: Partial indexes for active users only
- **Flexible Queries**: Easy filtering of active vs deleted users
- **Compliance Ready**: Support for complete data removal
- **Performance Optimized**: Strategic indexing for common query patterns
- **Security Enhanced**: Account status and verification tracking
- **Search Friendly**: Efficient search capabilities with separate name/last_name indexing

## 🔗 **Foreign Key Constraints Strategy**

### **ON DELETE CASCADE Implementation**

All foreign keys referencing the `users` table are configured with appropriate deletion strategies:

#### **CASCADE (Complete Removal)**
These tables will be **automatically deleted** when a user is removed:
- `tokens` - Authentication tokens
- `addresses` - User addresses
- `payment_methods` - Saved payment methods
- `external_entities` - External entity records (payment customers, newsletter subscribers, etc.)
- `organization_users` - Organization memberships
- `subscriptions` - Active subscriptions
- `user_memberships` - Membership records
- `user_cohorts` - Analytics cohorts

#### **SET NULL (Preserve Records)**
These tables will **preserve records** but remove user reference:
- `orders` - Order history (for business records)
- `payments` - Payment transactions (for financial records)
- `invoices` - Invoice history (for accounting)
- `user_events` - Analytics events (anonymized)

### **Database Consistency**

**All three database schemas (PostgreSQL, MySQL, SQLite) implement identical constraint strategies:**

```sql
-- Personal data (CASCADE - complete removal)
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE

-- Business data (SET NULL - preserve with anonymization)
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
```

### **Benefits of This Approach**

✅ **No Constraint Violations**: Automatic cleanup prevents foreign key errors
✅ **Data Integrity**: Business records preserved for compliance
✅ **Privacy Compliance**: Personal data completely removed
✅ **Operational Safety**: No manual cleanup required
✅ **Audit Trail**: Financial records maintained for legal requirements

## 🛡️ **Data Retention Best Practices**

### **What to Keep vs What to Delete**

#### **❌ Data to DELETE (Personal Information)**
- User profile data (name, email, phone)
- Personal preferences and settings
- Authentication tokens and sessions
- Personal addresses and payment methods
- Direct user communications

#### **✅ Data to PRESERVE (Business Critical)**
- **Financial Records**: Completed transactions, invoices, tax records
- **Analytics Data**: Aggregated metrics, revenue reports (anonymized)
- **Audit Logs**: Security events, compliance records
- **Legal Requirements**: Data required by law or regulation
- **Business Intelligence**: Anonymized behavioral data

#### **🔄 Data to ANONYMIZE**
- Order history → Replace user details with "Deleted User"
- Payment records → Keep transaction data, remove personal identifiers
- Support tickets → Preserve content, anonymize user information

### **Implementation Examples**

#### **Soft Delete Query (Default)**
```sql
-- Mark user as deleted (preserves all data)
UPDATE users
SET deleted_at = CURRENT_TIMESTAMP,
    deletion_reason = 'user_request'
WHERE id = 'user_123';

-- Query active users only
SELECT * FROM users WHERE deleted_at IS NULL;
```

#### **Hard Delete Query (Compliance)**
```sql
-- Complete removal (triggers CASCADE)
DELETE FROM users WHERE id = 'user_123';
-- This automatically removes:
-- - tokens, addresses, payment_methods
-- - subscriptions, orders (SET NULL)
-- - organization memberships
```

#### **Anonymization Query (Hybrid)**
```sql
-- Anonymize user data while preserving business records
UPDATE users
SET name = 'Deleted User',
    last_name = '',
    email = CONCAT('deleted_', id, '@example.com'),
    phone = NULL,
    picture = NULL,
    deleted_at = CURRENT_TIMESTAMP,
    deletion_reason = 'gdpr_compliance'
WHERE id = 'user_123';
```

### **Compliance Considerations**

#### **GDPR Requirements**
- **Right to be Forgotten**: Complete data removal within 30 days
- **Data Minimization**: Only keep necessary business data
- **Consent Withdrawal**: Remove all consent-based data

#### **Business Requirements**
- **Financial Records**: Keep for 7+ years (tax requirements)
- **Audit Trails**: Preserve for compliance and security
- **Analytics**: Use anonymized/aggregated data only

### **Recommended Deletion Workflow**

1. **User Request** → Soft delete (immediate)
2. **Grace Period** → 30 days for recovery
3. **Anonymization** → Replace personal data with generic values
4. **Hard Delete** → Only if legally required or after retention period

### Organizations

Enhanced organizations table with international support and branding capabilities.

**New Features:**
- **International Support**: Country field for global organization management
- **Branding**: Picture/logo URL field for organization visual identity
- **Comprehensive Indexing**: Optimized indexes for all organization fields

```sql
CREATE TABLE organizations (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    owner_user_id VARCHAR(255) NOT NULL,
    business_email VARCHAR(255),
    business_phone VARCHAR(50),
    tax_id VARCHAR(100),
    address TEXT,
    country VARCHAR(2), -- ISO 2-letter country code
    picture TEXT, -- Organization logo/picture URL
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE organization_users (
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

-- Organizations Indexes
CREATE INDEX idx_organizations_owner_user_id ON organizations(owner_user_id);
CREATE INDEX idx_organizations_name ON organizations(name);
CREATE INDEX idx_organizations_business_email ON organizations(business_email);
CREATE INDEX idx_organizations_business_phone ON organizations(business_phone);
CREATE INDEX idx_organizations_tax_id ON organizations(tax_id);
CREATE INDEX idx_organizations_country ON organizations(country);
CREATE INDEX idx_organizations_created_at ON organizations(created_at);
CREATE INDEX idx_organizations_updated_at ON organizations(updated_at);
```

### Addresses

```sql
CREATE TABLE addresses (
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
```

**Key Features:**
- Supports both billing and shipping addresses
- Can belong to users, organizations, or guests
- ISO country code standardization
- Default address selection
- `alias`: User-friendly name for easy identification (e.g., "Home", "Office", "Mom's house")
- `is_guest`: Boolean flag to identify guest addresses
- `guest_email`: Email for guest address identification and management
- `guest_name`: Display name for guest addresses
- `metadata`: JSON object for additional address information (nicknames, categories, notes)
- Modified CHECK constraint to allow guest addresses without user_id or organization_id

## Payment Provider Integration

### Payment Providers

```sql
CREATE TABLE payment_providers (
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
```

**Key Features:**
- `description`: Detailed description of the payment provider
- `picture`: URL for provider logo/icon display
- `config`: JSON field for provider-specific settings (API keys, etc.)
- Feature flags for subscription and saved payment method support

### External Entities (Unified Customer Management)

```sql
CREATE TABLE external_entities (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),

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
    FOREIGN KEY (payment_provider_id) REFERENCES payment_providers(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_entity_id) REFERENCES external_entities(id) ON DELETE SET NULL,

    CHECK (user_id IS NOT NULL OR external_email IS NOT NULL) -- Either user_id or external_email must be provided
);

-- Create partial unique indexes to enforce conditional uniqueness
CREATE UNIQUE INDEX idx_external_entities_user_unique
ON external_entities (user_id, organization_id, payment_provider_id, context_type)
WHERE user_id IS NOT NULL AND payment_provider_id IS NOT NULL;

CREATE UNIQUE INDEX idx_external_entities_email_unique
ON external_entities (external_email, organization_id, payment_provider_id, context_type)
WHERE user_id IS NULL AND external_email IS NOT NULL AND payment_provider_id IS NOT NULL;
```

**Key Features:**
- **Unified Entity Management**: Single table for payment customers, newsletter subscribers, event attendees, etc.
- **Context-Based Classification**: `context_type` field enables multiple use cases beyond payments
- **Hierarchical Relationships**: `provider_entity_id` creates parent-child entity relationships
- **Scalable Design**: Supports future extensions (newsletter, events, contacts, surveys)
- **Clean Semantics**: `external_*` fields provide clear, descriptive naming
- **Payment-Optional**: Payment provider fields are optional for non-payment contexts
- **Guest Support**: Complete support for external entities without user accounts
- **Relationship Tracking**: Entities can be linked (e.g., guest → payment customer → newsletter subscriber)
- **Performance Optimized**: Conditional unique indexes prevent duplicates while allowing flexibility

**Hierarchical Design Patterns:**

1. **Simple Pattern** (Single Context):
   ```sql
   -- Direct payment entity creation
   INSERT INTO external_entities (context_type, payment_provider_id, external_email)
   VALUES ('payment', 'stripe', 'guest@example.com');
   ```

2. **Hierarchical Pattern** (Multiple Contexts):
   ```sql
   -- 1. Create guest parent entity
   INSERT INTO external_entities (context_type, external_email, external_name)
   VALUES ('guest', 'user@example.com', 'John Doe');

   -- 2. Create payment child entity
   INSERT INTO external_entities (context_type, payment_provider_id, provider_entity_id, external_email)
   VALUES ('payment', 'stripe', 'guest_entity_id', 'user@example.com');

   -- 3. Create newsletter child entity
   INSERT INTO external_entities (context_type, provider_entity_id, external_email)
   VALUES ('newsletter', 'guest_entity_id', 'user@example.com');
   ```

3. **Cross-Context Relationships**:
   ```sql
   -- Newsletter subscriber becomes payment customer
   INSERT INTO external_entities (context_type, payment_provider_id, provider_entity_id, external_email)
   VALUES ('payment', 'stripe', 'newsletter_entity_id', 'user@example.com');
   ```

### Payment Methods

```sql
CREATE TABLE payment_methods (
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
```

**Key Features:**
- Links to addresses table for billing information
- Supports multiple payment types (cards, bank accounts, digital wallets)
- Provider-agnostic design with provider-specific IDs
- `customer_id`: Direct link to external_entities table for improved performance and data consistency
- `wallet_type`: Specifies the type of wallet payment (apple_pay, google_pay, samsung_pay, etc.) when payment_type is 'wallet'
- `alias`: User-friendly name for easy identification (e.g., "My primary card", "Travel card", "Business expenses")
- `is_guest`: Boolean flag to identify guest payment methods
- `guest_email`: Email for guest payment method identification and management
- `guest_name`: Name for guest payment methods
- `metadata`: JSON object for additional payment method information (nicknames, categories)
- Modified CHECK constraint to allow guest payment methods without user_id or organization_id

**Wallet Payment Types:**
- `apple_pay`: Apple Pay wallet payments
- `google_pay`: Google Pay wallet payments
- `samsung_pay`: Samsung Pay wallet payments
- Additional wallet types can be added as needed

## Transaction Tables

### Product Categories

```sql
CREATE TABLE product_categories (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    parent_id VARCHAR(255),
    image VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES product_categories(id) ON DELETE SET NULL
);
```

**Key Features:**
- Hierarchical category structure with parent-child relationships
- Image support for category display
- Sort ordering for custom arrangement

### Products/Plans

```sql
CREATE TABLE products (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    product_type VARCHAR(50) NOT NULL, -- 'physical', 'digital', 'service', 'subscription'
    is_recurring BOOLEAN NOT NULL DEFAULT false,

    -- PRODUCT PRICING (only base price - tax calculated dynamically)
    subtotal_cents BIGINT NOT NULL, -- Base product price (before tax/discounts)

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    billing_interval VARCHAR(20), -- 'monthly', 'yearly', null for one-time
    trial_days INTEGER DEFAULT 0,
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
```

**Key Features:**
- Product categorization and hierarchical organization
- Image gallery support for multiple product images
- Product variations (size, color, etc.) stored as JSON
- Parent-child relationships for product variants

### Orders (Enhanced with Complete Guest Support)

```sql
CREATE TABLE orders (
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
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_order = true) -- Must belong to a user, organization, customer, or be an anonymous guest order
);

CREATE TABLE order_items (
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
```

**Key Features:**
- **Complete Guest Support**: Supports both registered guests (`customer_id`) and anonymous guests (`is_guest_order`)
- **Registered Guests**: Uses `customer_id` to reference `external_entities` for guests who want to save payment methods
- **Anonymous Guests**: Uses `is_guest_order` flag with `guest_data` JSON for completely anonymous checkout
- **Unified Customer Management**: Consistent with subscriptions and invoices design
- **Flexible Ownership**: Can belong to users, organizations, registered guests, or anonymous guests
- **Performance Optimized**: Proper indexing on guest fields for fast queries
- **Backward Compatible**: Existing user and organization orders continue to work

**Guest Order Types:**

1. **Anonymous Guest Order** (No account, no saved data):
```sql
INSERT INTO orders (
    is_guest_order, guest_data, guest_email, total_cents, currency
) VALUES (
    true,
    '{"email": "anon@example.com", "name": "John Anonymous", "phone": "+1234567890"}',
    'anon@example.com',
    2999,
    'USD'
);
```

2. **Registered Guest Order** (Saved payment methods, no full account):
```sql
INSERT INTO orders (customer_id, total_cents, currency)
VALUES ('cust_guest_456', 2999, 'USD');
```

3. **Authenticated User Order** (Full account):
```sql
INSERT INTO orders (user_id, total_cents, currency)
VALUES ('user_123', 2999, 'USD');
```

### Payments

```sql
CREATE TABLE payments (
    id VARCHAR(255) PRIMARY KEY,
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    payment_method_id VARCHAR(255),
    provider_id VARCHAR(50) NOT NULL,
    provider_payment_id VARCHAR(255),
    amount_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(50) NOT NULL, -- 'pending', 'completed', 'failed', 'refunded'
    error_message TEXT,
    -- Enhanced tracking fields
    concept VARCHAR(100), -- Human-readable concept (e.g., "Monthly Subscription", "Product Purchase", "Donation")
    reference_code VARCHAR(100), -- Machine-readable code for analytics (e.g., "subscription_monthly", "donation_campaign_2024")
    category VARCHAR(50), -- High-level category (e.g., "subscription", "donation", "purchase", "refund", "fee")
    tags VARCHAR(500), -- Comma-separated tags for flexible categorization (e.g., "promotion,summer,discount")
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
    CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL) -- Must be associated with either an order or subscription
);
```

**Enhanced Tracking Features:**
- `concept`: Human-readable description for easy identification
- `reference_code`: Unique machine-readable code for analytics and queries
- `category`: High-level categorization for reporting
- `tags`: Flexible comma-separated tags for multi-dimensional analysis

**Usage Examples:**
```sql
-- Analyze all promotional payments
SELECT * FROM payments WHERE reference_code LIKE '%promo%';

-- Get enterprise annual payments
SELECT * FROM payments WHERE tags LIKE '%enterprise%' AND tags LIKE '%annual%';

-- Revenue by category
SELECT category, SUM(amount_cents) as total_revenue
FROM payments
WHERE status = 'succeeded'
GROUP BY category;

-- Find specific campaign payments
SELECT * FROM payments WHERE reference_code = 'donation_campaign_2024';
```

### Subscriptions (Enhanced with Guest Support, Flexible Products & Automatic Billing)

```sql
CREATE TABLE subscriptions (
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
    interval_multiplier INTEGER DEFAULT 1, -- Optional: 2 for every 2 months, 3 for every 3 weeks, etc.
    next_billing_date TIMESTAMP, -- When the next billing should occur
    last_billing_attempt TIMESTAMP, -- Last time we attempted to bill this subscription
    billing_retry_count INTEGER NOT NULL DEFAULT 0, -- Number of failed billing attempts
    max_retry_attempts INTEGER NOT NULL DEFAULT 3, -- Maximum retry attempts before suspension
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
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE,
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL), -- Must belong to a user, organization, or have a customer
    CHECK (billing_interval IN ('daily', 'weekly', 'monthly', 'yearly')),
    CHECK (interval_multiplier IS NULL OR (interval_multiplier > 0 AND interval_multiplier <= 12)),
    CHECK (billing_status IN ('active', 'past_due', 'suspended', 'cancelled'))
);
```

**Key Features:**
- **Guest Support**: `customer_id` field enables subscriptions for guests without user accounts
- **Flexible Products**: `product_id` is optional for custom donations and flexible subscriptions
- **Multipurpose Design**: Supports both predefined products and custom pricing
- **Unified Customer Management**: Links to `external_entities` table for both users and guests
- **Enhanced Status**: Additional status values for incomplete payments
- **Flexible Ownership**: Can belong to users, organizations, or guests
- **Provider Agnostic**: Works with any payment provider
- **Clean Design**: No duplicate guest fields - guest info comes from `external_entities`
- **Automatic Billing**: Built-in support for automatic subscription renewals with flexible intervals
- **Retry Logic**: Configurable retry attempts for failed billing with status tracking
- **Flexible Intervals**: Support for custom billing frequencies using interval multipliers
- **Enhanced Tracking**: Advanced tracking fields for analytics and categorization (inspired by payments table)

#### Billing Automation Features

**Billing Intervals with Multipliers:**
- `billing_interval`: Base interval ('daily', 'weekly', 'monthly', 'yearly')
- `interval_multiplier`: Optional multiplier for custom frequencies (1-12)

**Common Billing Configurations:**
- **Weekly**: `billing_interval = 'weekly'`, `interval_multiplier = 1`
- **Biweekly**: `billing_interval = 'weekly'`, `interval_multiplier = 2`
- **Monthly**: `billing_interval = 'monthly'`, `interval_multiplier = 1`
- **Quarterly**: `billing_interval = 'monthly'`, `interval_multiplier = 3`
- **Bimonthly**: `billing_interval = 'monthly'`, `interval_multiplier = 2`
- **Semiannually**: `billing_interval = 'monthly'`, `interval_multiplier = 6`
- **Yearly**: `billing_interval = 'yearly'`, `interval_multiplier = 1`

**Billing Status Management:**
- `active`: Normal billing cycle
- `past_due`: Payment failed, retry scheduled
- `suspended`: Max retries reached, billing stopped
- `cancelled`: Subscription cancelled by user/admin

**Retry Logic:**
- `billing_retry_count`: Tracks failed attempts
- `max_retry_attempts`: Configurable retry limit (default: 3)
- `last_billing_attempt`: Timestamp of last billing attempt

#### Enhanced Tracking Fields

**Description & Concept:**
- `description`: Human-readable description for display purposes (e.g., "Premium Monthly Plan", "Basic Annual Subscription")
- `concept`: **Primary subscription title/name** used across all providers (e.g., "Monthly Subscription", "Annual Plan", "Trial Subscription")
  - **Provider Integration**: The `concept` field is used as the subscription title/name in external providers like Stripe
  - **Consistency**: Ensures the same subscription name appears in both internal system and external provider dashboards

**Analytics & Categorization:**
- `reference_code`: Machine-readable code for analytics and reporting (e.g., "subscription_monthly", "plan_premium_annual")
- `category`: High-level category for grouping (e.g., "subscription", "trial", "upgrade", "downgrade")
- `tags`: Comma-separated tags for flexible categorization (e.g., "promotion,summer,discount,premium")

**Automatic Population:**
- **Product Subscriptions**: `description` defaults to product name + billing interval
- **Custom Subscriptions**: `description` includes price and billing frequency
- **Reference Codes**: Auto-generated based on subscription type and parameters
- **Categories**: Default to "subscription" but can be customized for specific use cases

#### Provider Integration (Stripe, PayPal, etc.)

**Concept as Subscription Title:**
- The `concept` field is automatically used as the subscription title/name in external providers
- **Stripe Integration**: `concept` becomes the subscription description and product name
- **Metadata Sync**: All tracking fields are synced to provider metadata for consistency
- **Dashboard Consistency**: Same subscription names appear in both internal and provider dashboards

**Provider Metadata Mapping:**
```json
{
  "subscription_title": "concept_value",
  "subscription_concept": "concept_value",
  "subscription_description": "description_value",
  "subscription_category": "category_value",
  "subscription_reference_code": "reference_code_value"
}
```

**Example Provider Integration:**
```javascript
// Custom subscription with concept
{
  "concept": "Premium Business Plan",
  "description": "Monthly premium subscription for business users",
  "reference_code": "sub_premium_business_monthly",
  "category": "subscription",
  "tags": "premium,business,monthly"
}

// Results in Stripe:
// - Subscription Description: "Premium Business Plan"
// - Product Name: "Premium Business Plan"
// - Metadata includes all tracking fields
```

#### Subscription Use Cases

**1. Traditional Product Subscriptions** (with `product_id` and tracking fields)
```sql
-- Monthly premium plan subscription with concept as title
INSERT INTO subscriptions (
    customer_id, product_id, price_cents, currency,
    billing_interval, interval_multiplier, next_billing_date,
    concept, description, reference_code, category, tags
) VALUES (
    'cust_123', 'prod_premium_monthly', 2999, 'USD',
    'monthly', 1, '2024-02-15 00:00:00',
    'Premium Monthly Plan', 'Premium business subscription with advanced features',
    'sub_premium_monthly_2024', 'subscription', 'premium,business,monthly'
);
-- Results in Stripe: Subscription titled "Premium Monthly Plan"
```

**2. Custom Donation Subscriptions** (without `product_id` but with concept title)
```sql
-- Monthly donation with concept as subscription title
INSERT INTO subscriptions (
    customer_id, product_id, price_cents, currency,
    billing_interval, interval_multiplier, next_billing_date,
    concept, description, reference_code, category, tags, metadata
) VALUES (
    'cust_456', NULL, 2500, 'USD',
    'monthly', 1, '2024-02-15 00:00:00',
    'Monthly Animal Shelter Donation', 'Monthly $25 donation to support animal shelter',
    'donation_animal_shelter_monthly', 'donation', 'donation,monthly,animal,charity',
    '{"type": "monthly_donation", "cause": "animal_shelter"}'
);
-- Results in Stripe: Subscription titled "Monthly Animal Shelter Donation"
```

**3. Flexible Service Subscriptions** (without `product_id`)
```sql
-- Custom consulting service - $150 every 2 weeks
INSERT INTO subscriptions (
    customer_id, product_id, price_cents, currency,
    billing_interval, interval_multiplier, next_billing_date, metadata
) VALUES (
    'cust_789', NULL, 15000, 'USD',
    'weekly', 2, '2024-02-15 00:00:00',
    '{"type": "consulting", "hours_included": 2, "service": "web_development"}'
);
```

**4. Guest Donation Subscriptions**
```sql
-- Guest quarterly donation ($30 every 3 months)
INSERT INTO subscriptions (
    customer_id, product_id, price_cents, currency,
    billing_interval, interval_multiplier, next_billing_date, metadata
) VALUES (
    'cust_guest_012', NULL, 3000, 'USD',
    'monthly', 3, '2024-05-15 00:00:00',
    '{"type": "guest_donation", "anonymous": true, "frequency": "quarterly"}'
);
```

**5. Advanced Billing Examples**
```sql
-- Biweekly subscription (every 2 weeks)
INSERT INTO subscriptions (
    customer_id, price_cents, currency,
    billing_interval, interval_multiplier, next_billing_date
) VALUES (
    'cust_biweekly', 1999, 'USD',
    'weekly', 2, '2024-02-15 00:00:00'
);

-- Semiannual subscription (every 6 months)
INSERT INTO subscriptions (
    customer_id, price_cents, currency,
    billing_interval, interval_multiplier, next_billing_date
) VALUES (
    'cust_semiannual', 29999, 'USD',
    'monthly', 6, '2024-08-15 00:00:00'
);

-- Custom frequency: Every 5 weeks
INSERT INTO subscriptions (
    customer_id, price_cents, currency,
    billing_interval, interval_multiplier, next_billing_date, metadata
) VALUES (
    'cust_custom', 4999, 'USD',
    'weekly', 5, '2024-03-21 00:00:00',
    '{"type": "custom_frequency", "description": "Every 5 weeks special plan"}'
);
```

### Invoices (Enhanced with Guest Support and Payment Links)

```sql
CREATE TABLE invoices (
    id VARCHAR(255) PRIMARY KEY,
    invoice_number VARCHAR(255) UNIQUE NOT NULL,
    order_id VARCHAR(255),
    subscription_id VARCHAR(255),
    payment_id VARCHAR(255), -- Optional reference to payment (updated after payment completion)
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255), -- References external_entities table (supports both users and guests)

    status VARCHAR(50) NOT NULL, -- 'draft', 'sent', 'paid', 'overdue', 'cancelled', 'void'

    -- Unified pricing system
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
    -- These columns enable integration with optional features when implemented
    billing_schedule_id VARCHAR(255), -- Link to billing schedule if invoice was auto-generated (Billing Schedules feature)
    account_balance_id VARCHAR(255), -- Link to account balance if payment uses balance (Account Balance feature)

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

    CHECK (total_cents = subtotal_cents + tax_cents - discount_cents),
    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL OR is_guest_invoice = true)
);
```

**Key Features:**
- **Guest Support**: `customer_id` and `is_guest_invoice` fields enable invoices for guests without user accounts
- **Payment Links**: Generate unique payment URLs with expiration support
- **Line Items**: Detailed breakdown of invoice items in JSON format
- **Coupon Support**: Track applied coupons and discounts
- **Status Tracking**: Complete invoice lifecycle (draft → sent → paid/overdue/cancelled/void)
- **Unified Customer Management**: Links to `external_entities` table for both users and guests
- **Flexible Ownership**: Can belong to users, organizations, or guests
- **Provider Integration**: Supports provider-generated invoices with external URLs
- **Complete Audit Trail**: Tracks all invoice states and payment dates
- **Multi-Currency Support**: Handles invoices in different currencies
- **Notes Support**: Add custom notes to invoices
- **Optional Features Integration**:
  - `billing_schedule_id` - Links to billing schedule for auto-generated invoices
  - `account_balance_id` - Tracks which account balance was used for payment

### Webhooks and Events

```sql
CREATE TABLE payment_webhooks (
    id VARCHAR(255) PRIMARY KEY,
    provider_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- 'payment.succeeded', 'subscription.created', etc.
    payload JSON NOT NULL,
    processed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    FOREIGN KEY (provider_id) REFERENCES payment_providers(id) ON DELETE CASCADE
);

CREATE TABLE payment_events (
    id VARCHAR(255) PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL, -- 'payment', 'subscription', 'order', etc.
    entity_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL, -- 'created', 'updated', 'failed', etc.
    data JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

---

## Optional Features

The following features are optional and can be added independently based on your business needs. Each feature is self-contained and can be implemented without the others.

### Cost Tracking (Optional Feature)

Track product costs and calculate profit margins for orders and subscriptions.

**Tables:**
- `product_costs` - Define base costs for products
- `order_costs` - Track actual costs per transaction
- `order_profitability` (view) - Order profitability analysis
- `subscription_profitability` (view) - Subscription profitability analysis

**Documentation:** See [Cost Tracking Guide](./cost-tracking.md) for complete API documentation and usage examples.

```sql
-- Product costs table
CREATE TABLE IF NOT EXISTS product_costs (
    id VARCHAR(255) PRIMARY KEY,
    product_id VARCHAR(255) NOT NULL,

    -- Cost type
    cost_type VARCHAR(50) NOT NULL, -- 'fixed', 'per_unit', 'per_hour', 'percentage'

    -- Cost values (use appropriate one based on cost_type)
    cost_per_unit_cents BIGINT,
    cost_per_hour_cents BIGINT,
    cost_percentage DECIMAL(5,2),
    fixed_cost_cents BIGINT,

    -- Overhead
    overhead_percentage DECIMAL(5,2) DEFAULT 0,

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Effective dates (for historical tracking)
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
);

-- Order costs table
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
    quantity DECIMAL(10,2),
    unit_type VARCHAR(50), -- 'units', 'hours', 'percentage'

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Reference to cost used
    product_cost_id VARCHAR(255),
    cost_breakdown JSON, -- Detailed breakdown

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE CASCADE,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE,
    FOREIGN KEY (product_cost_id) REFERENCES product_costs(id) ON DELETE SET NULL,

    CHECK (total_cost_cents = base_cost_cents + overhead_cost_cents)
);

-- Profitability views
CREATE VIEW order_profitability AS
SELECT
    o.id AS order_id,
    o.total_cents AS revenue_cents,
    COALESCE(SUM(oc.total_cost_cents), 0) AS cost_cents,
    o.total_cents - COALESCE(SUM(oc.total_cost_cents), 0) AS profit_cents,
    CASE
        WHEN o.total_cents > 0 THEN
            ((o.total_cents - COALESCE(SUM(oc.total_cost_cents), 0)) * 100.0 / o.total_cents)
        ELSE 0
    END AS profit_margin_percentage
FROM orders o
LEFT JOIN order_costs oc ON o.id = oc.order_id
GROUP BY o.id, o.total_cents;

CREATE VIEW subscription_profitability AS
SELECT
    s.id AS subscription_id,
    s.total_cents AS revenue_cents,
    COALESCE(SUM(oc.total_cost_cents), 0) AS cost_cents,
    s.total_cents - COALESCE(SUM(oc.total_cost_cents), 0) AS profit_cents,
    CASE
        WHEN s.total_cents > 0 THEN
            ((s.total_cents - COALESCE(SUM(oc.total_cost_cents), 0)) * 100.0 / s.total_cents)
        ELSE 0
    END AS profit_margin_percentage
FROM subscriptions s
LEFT JOIN order_costs oc ON s.id = oc.subscription_id
GROUP BY s.id, s.total_cents;
```

### Account Balance (Optional Feature)

Customer wallets, credits, and prepayment systems with support for multiple balance types per customer.

**Tables:**
- `account_balances` - Track customer balances
- `account_transactions` - Record all balance movements

**Documentation:** See [Account Balance Guide](./account-balance.md) for complete API documentation and usage examples.

```sql
-- Account balances table
CREATE TABLE IF NOT EXISTS account_balances (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255),

    -- NEW: Segment balances by context/purpose
    reference_code VARCHAR(100), -- 'main_wallet', 'promo_credits', 'refund_balance', 'subscription_prepaid'
    balance_type VARCHAR(50) NOT NULL DEFAULT 'general', -- 'general', 'promotional', 'refund', 'prepaid'

    -- Current balance
    current_balance_cents BIGINT NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Limits
    credit_limit_cents BIGINT DEFAULT 0,
    minimum_balance_cents BIGINT DEFAULT 0,

    -- Expiration (for promotional credits)
    expires_at TIMESTAMP,

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'active',

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_transaction_at TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE CASCADE,

    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL),
    UNIQUE (user_id, organization_id, customer_id, currency, reference_code)
);

-- Account transactions table
CREATE TABLE IF NOT EXISTS account_transactions (
    id VARCHAR(255) PRIMARY KEY,
    account_balance_id VARCHAR(255) NOT NULL,

    -- Transaction details
    transaction_type VARCHAR(50) NOT NULL, -- 'credit', 'debit', 'refund', 'adjustment', 'fee'
    amount_cents BIGINT NOT NULL,

    -- Balance tracking
    balance_before_cents BIGINT NOT NULL,
    balance_after_cents BIGINT NOT NULL,

    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- References
    invoice_id VARCHAR(255),
    payment_id VARCHAR(255),
    subscription_id VARCHAR(255),
    order_id VARCHAR(255),

    -- Description
    description TEXT NOT NULL,
    reference_code VARCHAR(100),

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
);
```

### Billing Schedules (Optional Feature)

Automated recurring billing with flexible payment sources and retry logic.

**Tables:**
- `billing_schedules` - Configure recurring charges
- `billing_schedule_executions` - Track execution history

**Documentation:** See [Billing Schedules Guide](./billing-schedules.md) for complete API documentation and usage examples.

```sql
-- Billing schedules table
CREATE TABLE IF NOT EXISTS billing_schedules (
    id VARCHAR(255) PRIMARY KEY,

    -- Who to charge
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255),

    -- Schedule configuration
    schedule_type VARCHAR(50) NOT NULL, -- 'recurring', 'one_time', 'metered'

    -- Amounts
    amount_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Recurrence
    billing_interval VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
    interval_multiplier INTEGER DEFAULT 1, -- Every X intervals

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
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    last_failure_reason TEXT,

    -- Description
    description TEXT NOT NULL,
    reference_code VARCHAR(100),
    category VARCHAR(50), -- 'subscription', 'installment', 'fee', 'custom'

    -- Notifications
    notify_before_days INTEGER DEFAULT 3,
    last_notification_sent TIMESTAMP,

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    FOREIGN KEY (account_balance_id) REFERENCES account_balances(id) ON DELETE SET NULL,

    CHECK (user_id IS NOT NULL OR organization_id IS NOT NULL OR customer_id IS NOT NULL)
);

-- Billing schedule executions table
CREATE TABLE IF NOT EXISTS billing_schedule_executions (
    id VARCHAR(255) PRIMARY KEY,
    billing_schedule_id VARCHAR(255) NOT NULL,

    -- Execution details
    scheduled_date TIMESTAMP NOT NULL,
    executed_at TIMESTAMP,

    -- Result
    status VARCHAR(50) NOT NULL, -- 'pending', 'success', 'failed', 'skipped'
    amount_charged_cents BIGINT,

    -- Payment tracking
    payment_id VARCHAR(255),
    invoice_id VARCHAR(255),
    payment_source VARCHAR(50), -- 'account_balance', 'payment_method', 'mixed'

    -- Error handling
    error_message TEXT,
    retry_attempt INTEGER DEFAULT 0,

    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (billing_schedule_id) REFERENCES billing_schedules(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE SET NULL,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL
);
```

### Receipts (Optional Feature)

Post-payment receipts for complete billing documentation.

**Tables:**
- `receipts` - Post-payment proof documents

**Documentation:** See [Invoices & Receipts Guide](./invoices-receipts.md) for complete API documentation and usage examples.

**Note:** Invoices table already exists in core schema. This feature adds receipts for post-payment documentation.

```sql
-- Receipts table
CREATE TABLE IF NOT EXISTS receipts (
    id VARCHAR(255) PRIMARY KEY,
    receipt_number VARCHAR(255) UNIQUE NOT NULL,

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
    customer_address JSON,

    -- Status
    status VARCHAR(50) NOT NULL DEFAULT 'issued', -- 'issued', 'void'

    -- Guest support
    is_guest_receipt BOOLEAN NOT NULL DEFAULT false,
    guest_data JSON,
    guest_email VARCHAR(255),

    -- URLs and documents
    receipt_url VARCHAR(500),
    receipt_pdf_url VARCHAR(500),

    -- Metadata
    line_items JSON, -- JSON with item breakdown
    applied_coupons JSON,
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
);
```

**Key Features of Optional Features:**
- **Modular Design**: Each feature can be implemented independently
- **No Dependencies**: Features work standalone or together
- **Complete Documentation**: Each feature has dedicated guide with API docs and examples
- **Production Ready**: Fully tested schemas with proper constraints and indexes

---

## Membership System

### Membership Types

```sql
CREATE TABLE membership_types (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    duration_type VARCHAR(50) NOT NULL, -- 'recurring', 'fixed', 'lifetime'
    duration_days INTEGER, -- NULL for 'lifetime' memberships
    price_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    features JSON, -- JSON array of features included in this membership
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**Key Features:**
- `duration_type`: Supports recurring, fixed-term, and lifetime memberships
- `features`: JSON array defining what features are included
- Flexible pricing in cents for precise control

### User Memberships

```sql
CREATE TABLE user_memberships (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    membership_type_id VARCHAR(255) NOT NULL,
    subscription_id VARCHAR(255), -- For recurring memberships
    order_id VARCHAR(255), -- For one-time purchases
    status VARCHAR(50) NOT NULL, -- 'active', 'expired', 'cancelled', 'pending'
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP, -- NULL for lifetime memberships
    auto_renew BOOLEAN NOT NULL DEFAULT false,
    addons JSON, -- JSON array of purchased addons with their expiration dates
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (membership_type_id) REFERENCES membership_types(id) ON DELETE RESTRICT,
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE SET NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);
```

**Key Features:**
- Links to both subscriptions (recurring) and orders (one-time)
- `addons`: JSON array for purchased add-on features
- Flexible date handling for lifetime memberships
- Status tracking throughout membership lifecycle

## Database Relationships

### Entity Relationship Overview

1. **Users & Organizations**: Many-to-many relationship through `organization_users`
2. **External Entities**: Hierarchical entity management with context-based classification
   - **Guest Entities** (context_type='guest'): Parent entities for guest users
   - **Payment Entities** (context_type='payment'): Child entities for payment processing
   - **Newsletter Entities** (context_type='newsletter'): Child entities for subscriptions
   - **Event Entities** (context_type='events'): Child entities for event management
3. **Entity Relationships**: `provider_entity_id` creates parent-child relationships between entities
4. **Addresses**: Belong to users, organizations, or external entities
5. **Payment Methods**: Linked to payment entities (context_type='payment') via `customer_id`
6. **Subscriptions**: Connected to payment entities via `customer_id` (supports guests seamlessly)
7. **Orders**: Reference payment entities for billing and shipping addresses
8. **Memberships**: Tied to users and can be linked to subscriptions or orders
9. **Products**: Organized in categories with support for variations

### Key Design Principles

1. **Multi-tenancy**: Support for individual users, organizations, and guests
2. **Guest-Friendly**: Complete guest checkout and subscription support without requiring accounts
3. **Provider Agnostic**: Works with multiple payment providers (Stripe, PayPal, Authorize.net)
4. **Unified Entity Management**: Single `external_entities` table handles all entity types with hierarchical relationships
5. **Flexible Pricing**: Supports various business models (SaaS, eCommerce, memberships)
6. **Audit Trail**: Comprehensive event and webhook logging
7. **Data Integrity**: Proper foreign key constraints and optimized CHECK constraints
8. **Performance Optimized**: Efficient indexes and normalized design

## Performance Considerations

### Recommended Indexes

```sql
-- User and organization lookups
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_user_name ON users(user_name);

-- Address lookups
CREATE INDEX idx_addresses_user_id ON addresses(user_id);
CREATE INDEX idx_addresses_organization_id ON addresses(organization_id);
CREATE INDEX idx_addresses_type ON addresses(address_type);
CREATE INDEX idx_addresses_alias ON addresses(alias);

-- Payment method lookups
CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX idx_payment_methods_organization_id ON payment_methods(organization_id);
CREATE INDEX idx_payment_methods_provider_id ON payment_methods(provider_id);
CREATE INDEX idx_payment_methods_provider_customer_id ON payment_methods(provider_customer_id);
CREATE INDEX idx_payment_methods_alias ON payment_methods(alias);

-- Order and payment tracking
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_order_id ON payments(order_id);

-- Enhanced payment tracking indexes
CREATE INDEX idx_payments_reference_code ON payments(reference_code);
CREATE INDEX idx_payments_category ON payments(category);
CREATE INDEX idx_payments_concept ON payments(concept);

-- Subscription management
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_organization_id ON subscriptions(organization_id);
CREATE INDEX idx_subscriptions_customer_id ON subscriptions(customer_id);
CREATE INDEX idx_subscriptions_provider_id ON subscriptions(provider_id);

-- Billing automation indexes
CREATE INDEX idx_subscriptions_next_billing ON subscriptions(next_billing_date, billing_status);
CREATE INDEX idx_subscriptions_billing_status ON subscriptions(billing_status);
CREATE INDEX idx_subscriptions_retry_billing ON subscriptions(last_billing_attempt, billing_retry_count);

-- Enhanced subscription tracking indexes
CREATE INDEX idx_subscriptions_reference_code ON subscriptions(reference_code);
CREATE INDEX idx_subscriptions_category ON subscriptions(category);
CREATE INDEX idx_subscriptions_concept ON subscriptions(concept);

-- Membership lookups
CREATE INDEX idx_user_memberships_user_id ON user_memberships(user_id);
CREATE INDEX idx_user_memberships_status ON user_memberships(status);
CREATE INDEX idx_membership_types_is_active ON membership_types(is_active);

-- Webhook processing
CREATE INDEX idx_payment_webhooks_processed ON payment_webhooks(processed);
CREATE INDEX idx_payment_events_entity_type_entity_id ON payment_events(entity_type, entity_id);

-- Analytics (Optional)
CREATE INDEX idx_analytics_snapshots_date_type ON analytics_snapshots(snapshot_date, metric_type);
CREATE INDEX idx_analytics_snapshots_currency ON analytics_snapshots(currency);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX idx_user_cohorts_month ON user_cohorts(cohort_month);
```

## Analytics Tables (Optional Feature)

The Analytics System is an optional feature that adds advanced reporting and insights capabilities. These tables can be added to enable comprehensive analytics.

### Analytics Snapshots

```sql
CREATE TABLE analytics_snapshots (
    id VARCHAR(255) PRIMARY KEY,
    snapshot_date DATE NOT NULL,
    metric_type VARCHAR(50) NOT NULL, -- 'daily_revenue', 'active_subscriptions', etc.
    metric_value DECIMAL(20, 2) NOT NULL,
    currency VARCHAR(3),
    breakdown JSON, -- Detailed breakdown of the metric
    calculation_method VARCHAR(50) DEFAULT 'scheduled', -- 'scheduled', 'on_demand', 'manual'
    calculation_duration_ms INTEGER, -- How long the calculation took
    data_freshness VARCHAR(50) DEFAULT 'historical', -- 'historical', 'recent', 'real_time'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_snapshot (snapshot_date, metric_type, currency)
);
```

**Key Features:**
- Smart caching system for analytics data
- Tracks calculation method and performance
- JSON breakdown for detailed insights
- Automatic deduplication by date, type, and currency

### Analytics Events (Optional)

```sql
CREATE TABLE analytics_events (
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
```

**Key Features:**
- Detailed event tracking for advanced analytics
- Revenue attribution per event
- Flexible properties for custom data
- Session tracking for user journey analysis

### User Cohorts (Optional)

```sql
CREATE TABLE user_cohorts (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    cohort_month DATE NOT NULL, -- Month when user first made a purchase
    cohort_type VARCHAR(50) NOT NULL, -- 'first_purchase', 'first_subscription'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_cohort (user_id, cohort_type)
);
```

**Key Features:**
- Cohort analysis for customer retention
- Multiple cohort types for different analyses
- Automatic customer segmentation

## Guest Support Architecture

### Overview

The payment system provides comprehensive guest support, allowing users to make purchases and subscribe to services without creating accounts. This is achieved through a unified customer management approach.

### Guest Entity Flow

1. **Guest Checkout**: Guest provides email and basic info
2. **Entity Creation**:
   - **Simple Case**: Payment entity created directly (context_type='payment')
   - **Complex Case**: Guest entity created as parent (context_type='guest'), then payment entity as child
3. **Payment Processing**: Normal payment flow using payment entity
4. **Multi-Context Support**: Same guest can have newsletter, events, and other entities
5. **Hierarchical Relationships**: All entities linked via `provider_entity_id`
6. **Guest Conversion**: When guest registers, all related entities are seamlessly transferred

### Key Tables for Guest Support

#### External Entities (Hierarchical Entity Management)
```sql
-- Get all guest entities (parent entities)
SELECT * FROM external_entities WHERE context_type = 'guest';

-- Get all payment entities for guests
SELECT * FROM external_entities WHERE context_type = 'payment' AND is_external = true;

-- Get all contexts for a specific guest
SELECT
  parent.external_name as guest_name,
  parent.external_email as guest_email,
  child.context_type,
  child.context_id,
  child.payment_provider_id
FROM external_entities parent
JOIN external_entities child ON child.provider_entity_id = parent.id
WHERE parent.context_type = 'guest'
AND parent.external_email = 'guest@example.com';
```

#### Guest Subscriptions
```sql
-- Get all guest subscriptions with payment entity info
SELECT
  s.*,
  pe.external_email,
  pe.external_name,
  ge.external_name as guest_name
FROM subscriptions s
JOIN external_entities pe ON s.customer_id = pe.id
LEFT JOIN external_entities ge ON pe.provider_entity_id = ge.id
WHERE pe.context_type = 'payment' AND pe.is_external = true;
```

#### Guest Payment Methods
```sql
-- Get saved payment methods for guests
SELECT
  pm.*,
  pe.external_email,
  pe.external_name,
  ge.external_name as guest_name
FROM payment_methods pm
JOIN external_entities pe ON pm.customer_id = pe.id
LEFT JOIN external_entities ge ON pe.provider_entity_id = ge.id
WHERE pe.context_type = 'payment' AND pe.is_external = true;
```

### Guest to User Conversion

When a guest creates an account:

1. **Update Entity Records**: Convert `is_external = false`, add `user_id` to all related entities
2. **Update Subscriptions**: Link to `user_id` (automatic via foreign keys)
3. **Update Payment Methods**: Link to `user_id` (automatic via foreign keys)
4. **Maintain Relationships**: All entity relationships are preserved
5. **Maintain History**: All transaction history is preserved

```sql
-- Example conversion process for hierarchical entities
-- Update guest parent entity
UPDATE external_entities
SET is_external = false, user_id = 'new_user_123'
WHERE external_email = 'guest@example.com' AND context_type = 'guest';

-- Update all child entities (payment, newsletter, events, etc.)
UPDATE external_entities
SET is_external = false, user_id = 'new_user_123'
WHERE provider_entity_id IN (
  SELECT id FROM external_entities
  WHERE user_id = 'new_user_123' AND context_type = 'guest'
);

-- Update subscriptions (automatic via customer_id relationship)
UPDATE subscriptions
SET user_id = 'new_user_123'
WHERE customer_id IN (
  SELECT id FROM external_entities
  WHERE user_id = 'new_user_123' AND context_type = 'payment'
);
```

### Benefits of This Architecture

1. **Seamless Experience**: Guests can use all features without accounts
2. **Easy Conversion**: Simple process to convert guests to users
3. **Data Integrity**: No data loss during conversion
4. **Performance**: Efficient queries with proper indexing
5. **Flexibility**: Supports any business model requiring guest checkout

## Tax Rates System (Optional)

### Tax Rates

```sql
CREATE TABLE tax_rates (
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
```

**Key Features:**
- **Dynamic Tax Calculation**: Tax rates calculated at purchase time based on location and product category
- **Geographic Targeting**: Support for country, state/province, city, and postal code specific rates
- **Product Category Filtering**: Apply different tax rates to different product categories
- **Priority System**: Handle overlapping tax rules with priority-based resolution
- **Time-based Activation**: Tax rates can be scheduled to activate/deactivate at specific times
- **Flexible Configuration**: Support for both percentage and fixed amount taxes

**Usage Examples:**
```sql
-- California Sales Tax (8.75%)
INSERT INTO tax_rates (name, rate, country, state_province)
VALUES ('California Sales Tax', 0.0875, 'US', 'CA');

-- NYC Clothing Tax (4% for clothing only)
INSERT INTO tax_rates (name, rate, country, state_province, city, applicable_categories)
VALUES ('NYC Clothing Tax', 0.0400, 'US', 'NY', 'New York', '["clothing", "accessories"]');

-- European VAT (21%)
INSERT INTO tax_rates (name, rate, country)
VALUES ('Spain VAT', 0.2100, 'ES');
```

**Dynamic Tax Calculation Flow:**
1. **Product Selection**: User adds T-shirt (category: "clothing") to cart
2. **Location Detection**: System detects user location (e.g., California, US)
3. **Tax Rate Resolution**: Query tax_rates table for applicable rates
4. **Priority Resolution**: If multiple rates match, use highest priority
5. **Tax Calculation**: Apply rate to product subtotal_cents
6. **Order Creation**: Store calculated tax_cents in order/payment
