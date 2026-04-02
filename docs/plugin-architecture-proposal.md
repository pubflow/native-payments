# Plugin & Extension Architecture — native-payments
> Multi-dialect modular structure proposal  
> Date: March 2026 | Status: Proposal for approval

---

## The problem this solves

The current schemas (`postgresql/schema.sql`, `mysql/schema.sql`, `sqlite/schema.sql`) are monolithic files of roughly 1,500–1,700 lines each. That creates several issues:

1. **All or nothing**: to use `native-payments` you must install all 35 tables even if you only need auth and basic payments
2. **No selectivity**: a project like a “landing page with subscriptions” does not need `membership_types`, analytics, `tax_rates`, `product_costs`, etc.
3. **Diffs are hard**: with ~1,700 lines per dialect, comparing changes across PG/MySQL/SQLite is confusing
4. **No split between CORE and OPTIONAL**: the current schema mixes critical tables with “nice to have” tables in the same file
5. **Implicit ALTERs**: columns such as `invoices.billing_schedule_id` or `invoices.account_balance_id` depend on optional features but are hardcoded in the core

---

## Proposed layout

```
canary/native-payments/
  ├── core/                   ← Always required — 16 base tables
  │   ├── postgresql.sql
  │   ├── mysql.sql
  │   └── sqlite.sql
  │
  ├── plugins/                ← Optional modules, install selectively
  │   ├── invoices/
  │   ├── receipts/
  │   ├── memberships/
  │   ├── analytics/
  │   ├── coupons/
  │   ├── tax/
  │   ├── cost-tracking/
  │   ├── account-balance/
  │   ├── billing-schedules/
  │   └── subscription-usage/ ← New (Reporter system)
  │
  ├── install/               ← Installation tooling
  │   ├── installer.ts       ← Interactive CLI
  │   ├── config.example.json
  │   └── README.md
  │
  └── migrations/            ← Versioned migrations (existing layout)
```

Each plugin is **self-contained**: it owns its tables and indexes, and if it must change the core, it ships the corresponding `ALTER TABLE` statements.

---

## 1. CORE tables — always required

These 16 tables are the system nucleus. They cannot be omitted because everything else depends on them.

| Table | Purpose |
|-------|---------|
| `users` | System users |
| `tokens` | Auth tokens (magic link, password reset, 2FA) |
| `organizations` | Multi-tenant organizations |
| `organization_users` | User membership in organizations |
| `projects` | Hierarchical billing entity |
| `project_members` | Project access control |
| `addresses` | Billing and shipping addresses |
| `payment_providers` | Provider catalog (Stripe, PayPal, etc.) |
| `external_entities` | Unified external clients / guests |
| `payment_methods` | Saved payment methods |
| `product_categories` | Product categories |
| `products` | Products / plans (one-time or recurring) |
| `orders` + `order_items` | Purchase orders |
| `subscriptions` | Recurring subscriptions |
| `payments` | Charge records |
| `payment_webhooks` + `payment_events` | Webhooks and event audit trail |

### Dialect differences in CORE

| Feature | PostgreSQL | MySQL | SQLite |
|---------|-----------|-------|--------|
| JSON field | `JSONB` | `JSON` | `TEXT` (JSON as string) |
| Boolean | `BOOLEAN` | `BOOLEAN` (tinyint) | `INTEGER` (0/1) |
| Timestamps | `TIMESTAMP` | `TIMESTAMP` + `ON UPDATE CURRENT_TIMESTAMP` | `TEXT` (ISO 8601) |
| Auto `updated_at` | `CREATE TRIGGER` + `FUNCTION` | column with `ON UPDATE` | `CREATE TRIGGER` (no shared function) |
| Partial indexes | `WHERE deleted_at IS NULL` ✅ | ❌ not supported | ✅ supported |
| Charset config | n/a | `ENGINE=InnoDB CHARSET=utf8mb4` | n/a |
| CURRENT_TIMESTAMP | `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP` | `(datetime('now'))` |

---

## 2. Full plugin inventory

### Plugin: `invoices`
**New tables:** `invoices`  
**Core ALTERs:** `subscriptions` (add `has_invoicing`), `payments` (add `invoice_id`)  
**Depends on:** core  
**Who needs it?** Any B2B, recurring, or regulated billing system

### Plugin: `receipts`
**New tables:** `receipts`  
**Core ALTERs:** none  
**Depends on:** core, `invoices`  
**Who needs it?** E-commerce, subscriptions, any flow with a payment receipt

### Plugin: `memberships`
**New tables:** `membership_types`, `entity_memberships`  
**Core ALTERs:** none  
**Depends on:** core  
**Who needs it?** Platforms with memberships (gym, club, seat-based SaaS)

### Plugin: `analytics`
**New tables:** `analytics_snapshots`, `analytics_events`, `user_cohorts`  
**Core ALTERs:** none  
**Depends on:** core  
**Who needs it?** Platforms that want business metrics in the same database

### Plugin: `coupons`
**New tables:** `discount_coupons`, `coupon_usage`  
**Core ALTERs:** `payments.applied_coupons`, `invoices.applied_coupons` (already JSONB in core — validate in plugin)  
**Depends on:** core  
**Who needs it?** Stores, SaaS with promotions, marketing campaigns

### Plugin: `tax`
**New tables:** `tax_rates`  
**Core ALTERs:** none (`tax_cents` already exists on core tables)  
**Depends on:** core  
**Who needs it?** Multi-jurisdiction operations, tax compliance

### Plugin: `cost-tracking`
**New tables:** `product_costs`, `order_costs`  
**Core ALTERs:** none  
**Depends on:** core  
**Who needs it?** Margin and profitability tracking per product/order

### Plugin: `account-balance`
**New tables:** `account_balances`, `account_transactions`  
**Core ALTERs:** 
- `invoices` → ADD `account_balance_id VARCHAR(255)` + FK  
- `payments` → ADD `account_balance_id VARCHAR(255)` + FK  
**Depends on:** core  
**Who needs it?** Wallets, prepaid credits, postpaid plans with debt tracking

### Plugin: `billing-schedules`
**New tables:** `billing_schedules`, `billing_schedule_executions`  
**Core ALTERs:**
- `invoices` → ADD `billing_schedule_id VARCHAR(255)` + FK  
**Depends on:** core, `invoices`  
**Optional but recommended with:** `account-balance`  
**Who needs it?** Automated recurring billing, overages, installments

### Plugin: `subscription-usage` *(new — Reporter system)*  
**New tables:** `subscription_usage`  
**Core ALTERs:** none  
**Depends on:** core, `billing-schedules`  
**Who needs it?** Usage-metering systems for overages (see `reporter-usage-system.md`)

---

## 3. File layout per plugin

All plugins share the same structure:

```
plugins/billing-schedules/
  ├── plugin.json          ← Plugin manifest
  ├── postgresql.sql       ← DDL for PostgreSQL
  ├── mysql.sql            ← DDL for MySQL
  ├── sqlite.sql           ← DDL for SQLite
  └── README.md            ← Plugin documentation
```

### `plugin.json` — manifest

```json
{
  "id": "billing-schedules",
  "name": "Billing Schedules",
  "version": "1.0.0",
  "description": "Automated recurring billing with retry logic and execution history",
  "tables": [
    "billing_schedules",
    "billing_schedule_executions"
  ],
  "alter_core": {
    "invoices": [
      "ADD COLUMN IF NOT EXISTS billing_schedule_id VARCHAR(255)",
      "ADD CONSTRAINT fk_invoices_billing_schedule FOREIGN KEY (billing_schedule_id) REFERENCES billing_schedules(id) ON DELETE SET NULL"
    ]
  },
  "depends_on": ["core", "invoices"],
  "optional_with": ["account-balance"],
  "dialects": ["postgresql", "mysql", "sqlite"],
  "tags": ["billing", "automation", "recurring"]
}
```

---

## 4. SQL structure per plugin (example: `billing-schedules`)

### `plugins/billing-schedules/postgresql.sql`

```sql
-- Plugin: billing-schedules (PostgreSQL)
-- Depends on: core, invoices
-- ============================================================

-- Billing Schedules
CREATE TABLE IF NOT EXISTS billing_schedules (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    organization_id VARCHAR(255),
    customer_id VARCHAR(255),
    schedule_type VARCHAR(50) NOT NULL,
    amount_cents BIGINT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    billing_interval VARCHAR(50) NOT NULL,
    interval_multiplier INT DEFAULT 1,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    next_billing_date TIMESTAMP NOT NULL,
    last_billed_at TIMESTAMP,
    payment_method_id VARCHAR(255),
    account_balance_id VARCHAR(255),
    payment_priority VARCHAR(50) DEFAULT 'balance_first',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    retry_count INT DEFAULT 0,
    max_retries INT DEFAULT 3,
    last_failure_reason TEXT,
    description TEXT NOT NULL,
    reference_code VARCHAR(100),
    category VARCHAR(50),
    notify_before_days INT DEFAULT 3,
    last_notification_sent TIMESTAMP,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES external_entities(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL,
    CHECK (schedule_type IN ('recurring', 'one_time', 'metered')),
    CHECK (billing_interval IN ('daily', 'weekly', 'monthly', 'yearly'))
);

CREATE TRIGGER update_billing_schedules_timestamp
BEFORE UPDATE ON billing_schedules
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Billing Schedule Executions
CREATE TABLE IF NOT EXISTS billing_schedule_executions (
    id VARCHAR(255) PRIMARY KEY,
    billing_schedule_id VARCHAR(255) NOT NULL,
    execution_status VARCHAR(50) NOT NULL,
    attempted_amount_cents BIGINT NOT NULL,
    charged_amount_cents BIGINT,
    payment_id VARCHAR(255),
    invoice_id VARCHAR(255),
    account_transaction_id VARCHAR(255),
    payment_source VARCHAR(50),
    error_message TEXT,
    executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (billing_schedule_id) REFERENCES billing_schedules(id) ON DELETE CASCADE
);

-- Indexes
CREATE INDEX idx_billing_schedules_next ON billing_schedules(next_billing_date, status);
CREATE INDEX idx_billing_schedules_user ON billing_schedules(user_id);
CREATE INDEX idx_billing_schedules_org ON billing_schedules(organization_id);
CREATE INDEX idx_billing_schedule_executions_schedule ON billing_schedule_executions(billing_schedule_id);

-- ALTER CORE: Add billing_schedule_id to invoices (if invoices plugin is installed)
ALTER TABLE invoices
    ADD COLUMN IF NOT EXISTS billing_schedule_id VARCHAR(255),
    ADD CONSTRAINT IF NOT EXISTS fk_invoices_billing_schedule
        FOREIGN KEY (billing_schedule_id) REFERENCES billing_schedules(id) ON DELETE SET NULL;
```

### `plugins/billing-schedules/mysql.sql`

```sql
-- Plugin: billing-schedules (MySQL)
-- Differences vs PostgreSQL:
--   - JSON instead of JSONB
--   - ON UPDATE CURRENT_TIMESTAMP instead of a trigger
--   - No IF NOT EXISTS on ALTER TABLE (check before running)
--   - No partial indexes (WHERE clause)

CREATE TABLE IF NOT EXISTS billing_schedules (
    id VARCHAR(255) PRIMARY KEY,
    -- [... remaining columns identical ...]
    metadata JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- constraints...
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- MySQL: manual trigger for updated_at (alternative if ON UPDATE is not used)
-- Not required when using ON UPDATE CURRENT_TIMESTAMP

-- ALTER CORE: MySQL does NOT support IF NOT EXISTS on ALTER TABLE
-- The installer checks INFORMATION_SCHEMA before executing:
-- ALTER TABLE invoices ADD COLUMN billing_schedule_id VARCHAR(255);
-- ALTER TABLE invoices ADD CONSTRAINT fk_invoices_billing_schedule
--     FOREIGN KEY (billing_schedule_id) REFERENCES billing_schedules(id) ON DELETE SET NULL;
```

### `plugins/billing-schedules/sqlite.sql`

```sql
-- Plugin: billing-schedules (SQLite)
-- Differences vs PostgreSQL:
--   - TEXT instead of VARCHAR
--   - INTEGER for booleans
--   - TEXT for datetimes (ISO 8601)
--   - datetime('now') instead of CURRENT_TIMESTAMP
--   - Triggers without CREATE FUNCTION (inline)
--   - ALTER TABLE only supports ADD COLUMN (not ADD CONSTRAINT)
--   - FKs cannot be added to existing tables via ALTER TABLE

CREATE TABLE IF NOT EXISTS billing_schedules (
    id TEXT PRIMARY KEY,
    -- [... columns as TEXT/INTEGER ...]
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Inline trigger for updated_at (SQLite has no reusable functions)
CREATE TRIGGER IF NOT EXISTS update_billing_schedules_timestamp
AFTER UPDATE ON billing_schedules
BEGIN
    UPDATE billing_schedules SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ALTER CORE: SQLite only supports ADD COLUMN, not ADD CONSTRAINT
-- SQLite FK enforcement uses PRAGMA foreign_keys=ON at table creation time
-- For existing tables: the installer may use a table-rebuild strategy if an FK is required
ALTER TABLE invoices ADD COLUMN billing_schedule_id TEXT;
-- NOTE: In SQLite you cannot add an FK to an existing table without recreating it.
-- Installer strategy: record the FK in metadata; enforce in the application layer.
```

---

## 5. Dialect differences — reference guide

| Concept | PostgreSQL | MySQL 8+ | SQLite 3.x |
|----------|-----------|----------|-----------|
| **JSON type** | `JSONB` (binary, indexable) | `JSON` (text) | `TEXT` (app validates) |
| **Boolean** | `BOOLEAN` (`true`/`false`) | `BOOLEAN` (tinyint alias) | `INTEGER` (`1`/`0`) |
| **Auto timestamp** | Trigger + `EXECUTE FUNCTION` | `ON UPDATE CURRENT_TIMESTAMP` | Inline trigger with `datetime('now')` |
| **Default timestamp** | `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP` | `(datetime('now'))` |
| **Partial index** | `WHERE condition` ✅ | ❌ not supported | `WHERE condition` ✅ |
| **ALTER + FK** | `ADD CONSTRAINT IF NOT EXISTS` ✅ | No `IF NOT EXISTS` on ALTER ❌ | `ADD COLUMN` only, no FK in ALTER ❌ |
| **Long text** | `TEXT` | `TEXT` / `LONGTEXT` | `TEXT` |
| **Charset** | not required | `ENGINE=InnoDB CHARSET=utf8mb4` | n/a |
| **Sequences** | manual (nanoid IDs) | manual (nanoid IDs) | manual (nanoid IDs) |
| **Trigger function** | `CREATE OR REPLACE FUNCTION` + `CREATE TRIGGER` | `DELIMITER $$ CREATE TRIGGER` | `CREATE TRIGGER ... BEGIN ... END` |
| **JSON indexing** | GIN on JSONB ✅ | Virtual column + index | ❌ not natively indexable |

### `ALTER TABLE` strategy per dialect

```typescript
// In the installer, for ALTER TABLE that adds a column + FK:

async function applyAlterTable(dialect: 'postgresql' | 'mysql' | 'sqlite', db, alteration) {
  switch (dialect) {
    case 'postgresql':
      // Supports ADD COLUMN IF NOT EXISTS and ADD CONSTRAINT IF NOT EXISTS
      await db.execute(alteration.postgresql);
      break;

    case 'mysql':
      // MySQL has no IF NOT EXISTS on ALTER TABLE
      // Check INFORMATION_SCHEMA before executing
      const existing = await db.execute(`
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '${alteration.table}'
        AND COLUMN_NAME = '${alteration.column}'
        AND TABLE_SCHEMA = DATABASE()
      `);
      if (existing.rows.length === 0) {
        await db.execute(alteration.mysql);
      }
      break;

    case 'sqlite':
      // SQLite: ADD COLUMN only, no FK in ALTER
      // Check with PRAGMA table_info
      const tableInfo = await db.execute(`PRAGMA table_info(${alteration.table})`);
      const columnExists = tableInfo.rows.some(r => r.name === alteration.column);
      if (!columnExists) {
        await db.execute(alteration.sqlite); // ADD COLUMN only
      }
      // FK recorded in metadata for application-layer validation
      break;
  }
}
```

---

## 6. Installer CLI (`install/installer.ts`)

The installer is an interactive tool that:
1. Reads the configured dialect (`DIALECT=postgresql|mysql|sqlite`)
2. Reads `install-config.json` (or runs in interactive mode)
3. Resolves plugin dependencies
4. Runs in order: core → plugins (topologically sorted)
5. For each `ALTER TABLE`, checks whether the column already exists before executing

### `install/config.example.json`

```json
{
  "dialect": "postgresql",
  "plugins": [
    "invoices",
    "receipts",
    "account-balance",
    "billing-schedules",
    "subscription-usage"
  ],
  "options": {
    "skip_existing_tables": true,
    "dry_run": false,
    "verbose": true
  }
}
```

### Installer interfaces

```typescript
// install/installer.ts

export interface Plugin {
  id: string;
  name: string;
  version: string;
  tables: string[];
  alter_core: Record<string, string[]>; // table → array of ALTER statements
  depends_on: string[];
  optional_with?: string[];
  dialects: ('postgresql' | 'mysql' | 'sqlite')[];
}

export interface InstallConfig {
  dialect: 'postgresql' | 'mysql' | 'sqlite';
  plugins: string[];           // Plugin IDs to install
  options: {
    skip_existing_tables: boolean; // If the table exists, do not fail
    dry_run: boolean;              // Print SQL only, do not execute
    verbose: boolean;              // Detailed logging
  };
}

export class NativePaymentsInstaller {
  constructor(private config: InstallConfig, private db: DatabaseConnection) {}

  /**
   * Resolves install order respecting dependencies.
   * Uses a topological sort so dependencies install first.
   */
  resolveInstallOrder(plugins: Plugin[]): Plugin[] { /* ... */ }

  /**
   * Runs the full install:
   * 1. Core
   * 2. Plugins in dependency order
   * 3. Core ALTER TABLE for columns required by plugins
   */
  async install(): Promise<InstallReport> { /* ... */ }

  /**
   * Prints the SQL that would run without executing it.
   * Useful for review before production.
   */
  async dryRun(): Promise<string[]> { /* ... */ }

  /**
   * Lists which tables are installed in the current database.
   */
  async status(): Promise<InstalledTable[]> { /* ... */ }
}
```

### Command-line usage

```bash
# Interactive install
bun run install/installer.ts

# With config file
bun run install/installer.ts --config install/my-config.json

# Print SQL only (do not execute)
bun run install/installer.ts --config install/my-config.json --dry-run

# Current install status
bun run install/installer.ts --status

# Install a single plugin
bun run install/installer.ts --plugin billing-schedules --dialect postgresql
```

---

## 7. Plugin dependency map

```
core (always)
│
├── invoices         ← could be CORE too if billing is always required
│   └── receipts
│
├── memberships
│
├── analytics
│
├── coupons          ← benefits from invoices but does not require it
│
├── tax              ← standalone; adds calculation logic
│
├── cost-tracking
│
├── account-balance
│   └── billing-schedules ← requires invoices; may pair with account-balance
│       └── subscription-usage  ← requires billing-schedules
│
└── [future]
    ├── multi-currency-fx      → historical FX rates
    ├── payment-links          → unique payment URLs per invoice
    ├── fraud-detection        → risk scores per payment
    └── audit-log              → immutable log of all operations
```

---

## 8. Reorganizing the current schema

### Before (current state)
```
canary/native-payments/
  postgresql/schema.sql   ← 1,734 lines, everything mixed
  mysql/schema.sql        ← 1,530 lines, everything mixed
  sqlite/schema.sql       ← 1,694 lines, everything mixed
```

### After (proposal)
```
canary/native-payments/
  core/
    postgresql.sql        ← ~450 lines (16 base tables only)
    mysql.sql             ← ~400 lines
    sqlite.sql            ← ~420 lines

  plugins/
    invoices/
      postgresql.sql      ← ~120 lines
      mysql.sql
      sqlite.sql
      plugin.json
      README.md
    receipts/             ← ~80 lines each
    memberships/          ← ~120 lines
    analytics/            ← ~150 lines
    coupons/              ← ~180 lines
    tax/                  ← ~100 lines
    cost-tracking/        ← ~120 lines
    account-balance/      ← ~150 lines
    billing-schedules/    ← ~130 lines
    subscription-usage/   ← ~80 lines (new)

  install/
    installer.ts
    config.example.json
    README.md
    utils/
      dialect-helpers.ts  ← dialect-aware ALTER TABLE helpers
      dependency-resolver.ts
      schema-validator.ts

  migrations/             ← versioned migrations (already exists)
  docs/
    plugin-architecture-proposal.md  ← this file
```

---

## 9. Install scenarios by project type

### Case A: Basic SaaS (subscriptions + payments, no invoicing)
```json
{
  "dialect": "postgresql",
  "plugins": []
}
```
→ Core only: users, tokens, orgs, projects, payment_methods, products, subscriptions, payments, webhooks (16 tables)

---

### Case B: E-commerce (store with invoices, installments, and coupons)
```json
{
  "dialect": "mysql",
  "plugins": ["invoices", "receipts", "coupons", "tax"]
}
```
→ 16 + invoices + receipts + coupons (2 tables) + tax = 22 tables

---

### Case C: Full Pubflow (bridge-payments production)
```json
{
  "dialect": "postgresql",
  "plugins": [
    "invoices",
    "receipts",
    "account-balance",
    "billing-schedules",
    "subscription-usage",
    "analytics",
    "coupons",
    "tax"
  ]
}
```
→ 16 + 1 + 1 + 2 + 2 + 1 + 3 + 2 + 1 = **29 tables** (of 35 possible — no memberships or cost-tracking)

---

### Case D: Simple mobile app (local SQLite, auth + one-off payments)
```json
{
  "dialect": "sqlite",
  "plugins": ["invoices"]
}
```
→ 17 tables, embedded SQLite file, no server

---

## 10. Notes on migrating from the current schema

The current monolithic schema **must not break** — the reorganization is additive:

1. Existing `postgresql/schema.sql`, `mysql/schema.sql`, and `sqlite/schema.sql` **stay** for backward compatibility
2. The new `core/` and `plugins/` layout is added alongside them
3. Content is **extracted** from existing schemas into the matching plugins without changing the DDL semantics
4. Each plugin gets a `CHANGELOG` to version future changes
5. Proposed new columns (e.g. `pdf_url` on invoices, or `subscription_usage`) **land as new plugin work**, not as edits to the monolith

---

## 11. Implementation checklist

```
Phase 1 — Extraction and reorganization
  [ ] Create folder layout: core/, plugins/, install/
  [ ] Extract CORE tables from each monolithic schema → core/*.sql
  [ ] Per plugin: folder + plugin.json + three SQL files + README
  [ ] Validate that core/ + all plugins together equals the full original schema
  [ ] Keep existing monolithic schemas (backward compatible)

Phase 2 — Installer
  [ ] Add install/installer.ts with NativePaymentsInstaller
  [ ] Implement dependency resolver (topological sort)
  [ ] Implement dialect-aware ALTER TABLE helpers
  [ ] Tests: install all combinations without conflicts
  [ ] dry-run + verbose modes

Phase 3 — New plugins (from existing proposals)
  [ ] subscription-usage plugin (Reporter system)
      → postgresql.sql + mysql.sql + sqlite.sql
      → depends_on: ["core", "billing-schedules"]
  [ ] pdf_url + pdf_generated_at on invoices + receipts
      → as ALTER in billing-schedules or in the invoices plugin itself

Phase 4 — Documentation
  [ ] README.md per plugin
  [ ] install/README.md with CLI usage
  [ ] Update repo root README.md
  [ ] Comparative plugin table in index.md
```

---

*Related: `invoice-overage-pdf-implementation.md`, `reporter-usage-system.md` in bridge-payments/to-do/*
