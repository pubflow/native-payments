-- =====================================================
-- MIGRATION: Fix Payments Table Constraint for Direct Payments
-- =====================================================
-- 
-- This migration fixes the CHECK constraint on the payments table
-- to allow direct payments (donations) that don't belong to orders
-- or subscriptions and are not manual payments.
--
-- Issue: The original constraint required payments to have either:
-- - order_id (for order payments)
-- - subscription_id (for subscription payments) 
-- - is_manual_payment = true (for manual payments)
--
-- Fix: Allow direct payments where both order_id and subscription_id are NULL
-- and is_manual_payment is false (for donations, standalone payments, etc.)
--
-- Date: 2025-06-21
-- =====================================================

-- PostgreSQL Migration
-- =====================================================
-- Note: PostgreSQL doesn't support modifying CHECK constraints directly
-- We need to drop and recreate the constraint

-- Drop the existing constraint (if it exists)
DO $$ 
BEGIN
    -- Try to drop the constraint, ignore if it doesn't exist
    BEGIN
        ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_check;
    EXCEPTION
        WHEN undefined_object THEN
            -- Constraint doesn't exist, continue
            NULL;
    END;
    
    -- Try alternative constraint names that might exist
    BEGIN
        ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_order_subscription_manual_check;
    EXCEPTION
        WHEN undefined_object THEN
            NULL;
    END;
END $$;

-- Add the new constraint that allows direct payments
ALTER TABLE payments ADD CONSTRAINT payments_payment_type_check 
CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL OR is_manual_payment = true OR (order_id IS NULL AND subscription_id IS NULL));

-- =====================================================
-- MySQL Migration
-- =====================================================
-- Note: MySQL also requires dropping and recreating CHECK constraints

-- Drop existing constraint (MySQL 8.0+)
-- Note: In older MySQL versions, CHECK constraints were ignored
-- This will only work in MySQL 8.0.16+

-- First, let's try to find and drop the existing constraint
-- MySQL doesn't have a simple way to drop CHECK constraints by condition
-- We'll need to recreate the table or use ALTER TABLE

-- For MySQL 8.0.16+, try to drop the constraint
-- ALTER TABLE payments DROP CHECK payments_chk_1; -- This might vary

-- Add the new constraint
-- ALTER TABLE payments ADD CONSTRAINT payments_payment_type_check 
-- CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL OR is_manual_payment = true OR (order_id IS NULL AND subscription_id IS NULL));

-- =====================================================
-- SQLite Migration
-- =====================================================
-- Note: SQLite doesn't support dropping CHECK constraints
-- We need to recreate the table with the new constraint

-- For SQLite, we need to:
-- 1. Create a new table with the correct constraint
-- 2. Copy data from old table
-- 3. Drop old table
-- 4. Rename new table

-- This is complex and risky, so we'll provide the steps but recommend
-- recreating the database with the new schema instead

/*
-- SQLite Migration Steps (ADVANCED - USE WITH CAUTION):

-- 1. Create backup table
CREATE TABLE payments_backup AS SELECT * FROM payments;

-- 2. Drop the original table
DROP TABLE payments;

-- 3. Recreate table with new constraint (copy the full CREATE TABLE statement from schema.sql)
-- [Include the full CREATE TABLE statement here with the new constraint]

-- 4. Copy data back
INSERT INTO payments SELECT * FROM payments_backup;

-- 5. Drop backup table
DROP TABLE payments_backup;

-- 6. Recreate indexes and triggers
-- [Include all CREATE INDEX and CREATE TRIGGER statements for payments table]
*/

-- =====================================================
-- Verification Queries
-- =====================================================

-- Test that the new constraint works correctly:

-- This should work (direct payment - donation):
-- INSERT INTO payments (id, user_id, subtotal_cents, tax_cents, discount_cents, total_cents, currency, status, provider_id, is_guest_payment, is_manual_payment) 
-- VALUES ('test_direct_payment', 'user123', 1000, 0, 0, 1000, 'USD', 'pending', 'stripe', false, false);

-- This should work (order payment):
-- INSERT INTO payments (id, order_id, user_id, subtotal_cents, tax_cents, discount_cents, total_cents, currency, status, provider_id, is_guest_payment, is_manual_payment) 
-- VALUES ('test_order_payment', 'order123', 'user123', 1000, 0, 0, 1000, 'USD', 'pending', 'stripe', false, false);

-- This should work (subscription payment):
-- INSERT INTO payments (id, subscription_id, user_id, subtotal_cents, tax_cents, discount_cents, total_cents, currency, status, provider_id, is_guest_payment, is_manual_payment) 
-- VALUES ('test_subscription_payment', 'sub123', 'user123', 1000, 0, 0, 1000, 'USD', 'pending', 'stripe', false, false);

-- This should work (manual payment):
-- INSERT INTO payments (id, user_id, subtotal_cents, tax_cents, discount_cents, total_cents, currency, status, provider_id, is_guest_payment, is_manual_payment) 
-- VALUES ('test_manual_payment', 'user123', 1000, 0, 0, 1000, 'USD', 'pending', 'stripe', false, true);

-- Clean up test data:
-- DELETE FROM payments WHERE id LIKE 'test_%';

-- =====================================================
-- Notes for Implementation
-- =====================================================

-- 1. BACKUP YOUR DATABASE before running this migration
-- 2. Test in a development environment first
-- 3. For production, consider maintenance windows
-- 4. SQLite users should recreate the database with new schema
-- 5. Verify that existing payments still work after migration
-- 6. Monitor application logs for any constraint violations

-- =====================================================
-- Rollback Plan
-- =====================================================

-- If you need to rollback to the original constraint:

-- PostgreSQL Rollback:
-- ALTER TABLE payments DROP CONSTRAINT payments_payment_type_check;
-- ALTER TABLE payments ADD CONSTRAINT payments_payment_type_check 
-- CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL OR is_manual_payment = true);

-- MySQL Rollback:
-- ALTER TABLE payments DROP CHECK payments_payment_type_check;
-- ALTER TABLE payments ADD CONSTRAINT payments_payment_type_check 
-- CHECK (order_id IS NOT NULL OR subscription_id IS NOT NULL OR is_manual_payment = true);

-- SQLite Rollback:
-- Recreate table with original constraint (complex process)
