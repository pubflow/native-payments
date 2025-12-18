# 🧾 Invoices & Receipts Feature (Optional)

## Overview

The **Invoices & Receipts** feature provides a universal billing system with pre-payment invoices and post-payment receipts. This optional feature helps you manage billing documents for all types of transactions.

## Key Concepts

- **Invoice** = Pre-payment document (request for payment)
- **Receipt** = Post-payment proof (confirmation of payment)

## When to Use This Feature

✅ **Use Invoices & Receipts if you:**
- Need to send invoices before payment
- Want to generate receipts after payment
- Need payment links for invoices
- Handle guest payments with billing documents
- Need detailed line items and breakdowns
- Want professional billing documents (PDF generation)
- Need to track invoice status (paid, unpaid, overdue)

❌ **Skip this feature if you:**
- Only need basic payment processing
- Don't send invoices or receipts
- Don't need billing documents

---

## Database Tables

### `invoices` (Already exists in core schema)
Pre-payment documents requesting payment.

**Key Fields:**
- `invoice_number` - Unique invoice number
- `user_id` / `organization_id` / `customer_id` - Who to bill
- `subtotal_cents` / `tax_cents` / `discount_cents` / `total_cents` - Amounts
- `currency` - Currency code
- `status` - Status: `'draft'`, `'sent'`, `'paid'`, `'overdue'`, `'cancelled'`, `'void'`
- `due_date` - Payment due date
- `payment_link_url` - URL for customer to pay
- `is_guest_invoice` - For guest customers
- `line_items` - JSON with item breakdown
- `applied_coupons` - JSON with applied coupons

### `receipts` (New table added by this feature)
Post-payment proof generated after successful payment.

**Key Fields:**
- `receipt_number` - Unique receipt number
- `invoice_id` - Related invoice (optional)
- `payment_id` - Related payment (required)
- `order_id` / `subscription_id` - Related entities
- `user_id` / `organization_id` / `customer_id` - Customer
- `subtotal_cents` / `tax_cents` / `discount_cents` / `total_cents` - Amounts paid
- `payment_method_id` / `payment_method_type` - Payment method used
- `customer_name` / `customer_email` / `customer_address` - Customer snapshot
- `status` - Status: `'issued'`, `'void'`
- `is_guest_receipt` - For guest customers
- `receipt_url` / `receipt_pdf_url` - Document URLs
- `line_items` - JSON with item breakdown
- `issue_date` - When receipt was issued

---

## API Endpoints

### Invoices

#### `POST /api/v1/invoices`
Create a new invoice.

**Request Body:**
```json
{
  "user_id": "user_123",
  "line_items": [
    {
      "description": "Premium Subscription",
      "quantity": 1,
      "unit_price_cents": 2999,
      "total_cents": 2999
    }
  ],
  "subtotal_cents": 2999,
  "tax_cents": 240,
  "total_cents": 3239,
  "currency": "USD",
  "due_date": "2024-02-15T23:59:59Z",
  "notes": "Thank you for your business!"
}
```

**Response:**
```json
{
  "id": "inv_123",
  "invoice_number": "INV-2024-001",
  "status": "draft",
  "payment_link_url": "https://pay.example.com/invoice/inv_123",
  "created_at": "2024-01-15T10:00:00Z"
}
```

#### `GET /api/v1/invoices/:id`
Get an invoice by ID.

#### `GET /api/v1/invoices/user/:user_id`
Get all invoices for a user.

**Query Parameters:**
- `status` - Filter by status
- `start_date` / `end_date` - Date range
- `limit` / `offset` - Pagination

#### `PATCH /api/v1/invoices/:id`
Update an invoice.

**Request Body:**
```json
{
  "status": "sent",
  "due_date": "2024-02-20T23:59:59Z"
}
```

#### `POST /api/v1/invoices/:id/send`
Send an invoice to the customer (email).

#### `POST /api/v1/invoices/:id/mark-paid`
Mark an invoice as paid (creates a receipt).

**Request Body:**
```json
{
  "payment_id": "pay_456",
  "payment_method_type": "credit_card"
}
```

#### `POST /api/v1/invoices/:id/void`
Void an invoice (cancel it).

### Receipts

#### `POST /api/v1/receipts`
Create a new receipt (usually automatic after payment).

**Request Body:**
```json
{
  "payment_id": "pay_456",
  "invoice_id": "inv_123",
  "user_id": "user_123",
  "subtotal_cents": 2999,
  "tax_cents": 240,
  "total_cents": 3239,
  "currency": "USD",
  "payment_method_type": "credit_card",
  "customer_name": "John Doe",
  "customer_email": "john@example.com",
  "line_items": [...]
}
```

**Response:**
```json
{
  "id": "rcpt_789",
  "receipt_number": "RCPT-2024-001",
  "status": "issued",
  "receipt_url": "https://receipts.example.com/rcpt_789",
  "receipt_pdf_url": "https://receipts.example.com/rcpt_789.pdf",
  "issue_date": "2024-01-15T10:30:00Z"
}
```

#### `GET /api/v1/receipts/:id`
Get a receipt by ID.

#### `GET /api/v1/receipts/payment/:payment_id`
Get receipt for a specific payment.

#### `GET /api/v1/receipts/user/:user_id`
Get all receipts for a user.

**Query Parameters:**
- `start_date` / `end_date` - Date range
- `limit` / `offset` - Pagination

#### `POST /api/v1/receipts/:id/void`
Void a receipt (for refunds).

### Guest Invoices & Receipts

#### `POST /api/v1/invoices/guest`
Create an invoice for a guest customer.

**Request Body:**
```json
{
  "guest_email": "guest@example.com",
  "guest_data": {
    "name": "Guest User",
    "address": "123 Main St"
  },
  "line_items": [...],
  "total_cents": 5000
}
```

---

## Usage Examples

### Example 1: Create and Send Invoice

```javascript
// Create an invoice
const invoiceResponse = await fetch('/api/v1/invoices', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: 'user_123',
    line_items: [
      {
        description: 'Web Development Services',
        quantity: 10,
        unit_price_cents: 5000,  // $50/hour
        total_cents: 50000       // $500 total
      }
    ],
    subtotal_cents: 50000,
    tax_cents: 4000,  // 8% tax
    total_cents: 54000,
    currency: 'USD',
    due_date: '2024-02-15T23:59:59Z'
  })
});

const invoice = await invoiceResponse.json();

// Send invoice to customer
await fetch(`/api/v1/invoices/${invoice.id}/send`, {
  method: 'POST'
});

console.log(`Invoice sent: ${invoice.payment_link_url}`);
```

### Example 2: Automatic Receipt Generation After Payment

```javascript
// After successful payment, automatically create receipt
async function processPayment(paymentData) {
  // Process payment
  const payment = await createPayment(paymentData);

  if (payment.status === 'succeeded') {
    // Automatically create receipt
    const receipt = await fetch('/api/v1/receipts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        payment_id: payment.id,
        invoice_id: payment.invoice_id,
        user_id: payment.user_id,
        subtotal_cents: payment.subtotal_cents,
        tax_cents: payment.tax_cents,
        total_cents: payment.total_cents,
        currency: payment.currency,
        payment_method_type: payment.payment_method_type,
        customer_name: payment.customer_name,
        customer_email: payment.customer_email,
        line_items: payment.line_items
      })
    }).then(r => r.json());

    console.log(`Receipt generated: ${receipt.receipt_url}`);

    // Send receipt to customer via email
    await sendReceiptEmail(receipt);
  }
}
```

### Example 3: Guest Invoice with Payment Link

```javascript
// Create invoice for guest customer
const guestInvoice = await fetch('/api/v1/invoices/guest', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    guest_email: 'customer@example.com',
    guest_data: {
      name: 'Jane Smith',
      company: 'Acme Corp',
      address: {
        street: '456 Business Ave',
        city: 'New York',
        state: 'NY',
        zip: '10001',
        country: 'US'
      }
    },
    line_items: [
      {
        description: 'Consulting Services',
        quantity: 1,
        unit_price_cents: 150000,
        total_cents: 150000
      }
    ],
    subtotal_cents: 150000,
    tax_cents: 12000,
    total_cents: 162000,
    currency: 'USD',
    due_date: '2024-02-28T23:59:59Z',
    notes: 'Payment due within 30 days'
  })
}).then(r => r.json());

// Email payment link to guest
console.log(`Payment link: ${guestInvoice.payment_link_url}`);
```

### Example 4: Mark Invoice as Paid

```javascript
// When payment is received, mark invoice as paid
await fetch('/api/v1/invoices/inv_123/mark-paid', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    payment_id: 'pay_456',
    payment_method_type: 'bank_transfer'
  })
});

// This automatically:
// 1. Updates invoice status to 'paid'
// 2. Creates a receipt
// 3. Links receipt to invoice and payment
```

### Example 5: Get Customer's Invoices and Receipts

```javascript
// Get all invoices for a user
const invoicesResponse = await fetch('/api/v1/invoices/user/user_123?status=paid');
const { invoices } = await invoicesResponse.json();

// Get all receipts for a user
const receiptsResponse = await fetch('/api/v1/receipts/user/user_123');
const { receipts } = await receiptsResponse.json();

console.log(`Invoices: ${invoices.length}, Receipts: ${receipts.length}`);
```

### Example 6: Void Invoice and Receipt (Refund Scenario)

```javascript
// Void the receipt (for refund)
await fetch('/api/v1/receipts/rcpt_789/void', {
  method: 'POST'
});

// Void the invoice
await fetch('/api/v1/invoices/inv_123/void', {
  method: 'POST'
});

// Process refund
await processRefund(payment_id);
```

---

## Best Practices

### 1. **Always Generate Receipts After Payment**
Automatically create receipts when payments succeed:

```javascript
// In your payment webhook handler
if (payment.status === 'succeeded') {
  await createReceipt(payment);
}
```

### 2. **Use Detailed Line Items**
Include comprehensive line item breakdowns:

```javascript
{
  line_items: [
    {
      description: 'Premium Plan - Monthly',
      quantity: 1,
      unit_price_cents: 2999,
      total_cents: 2999,
      metadata: {
        product_id: 'prod_123',
        sku: 'PREMIUM-MONTHLY'
      }
    },
    {
      description: 'Additional User Seats',
      quantity: 5,
      unit_price_cents: 500,
      total_cents: 2500
    }
  ]
}
```

### 3. **Set Appropriate Due Dates**
For invoices, set realistic due dates:

```javascript
// Net 30 (30 days from now)
const dueDate = new Date();
dueDate.setDate(dueDate.getDate() + 30);

{
  due_date: dueDate.toISOString(),
  notes: 'Payment due within 30 days (Net 30)'
}
```

### 4. **Include Customer Information**
Always capture customer details in receipts:

```javascript
{
  customer_name: 'John Doe',
  customer_email: 'john@example.com',
  customer_address: {
    street: '123 Main St',
    city: 'San Francisco',
    state: 'CA',
    zip: '94102',
    country: 'US'
  }
}
```

### 5. **Generate PDF Receipts**
Provide PDF versions for professional documentation:

```javascript
// After creating receipt, generate PDF
const receipt = await createReceipt(data);

// Generate PDF (implement with your PDF library)
const pdfUrl = await generateReceiptPDF(receipt);

// Update receipt with PDF URL
await updateReceipt(receipt.id, { receipt_pdf_url: pdfUrl });
```

### 6. **Track Invoice Status**
Monitor invoice status and send reminders:

```javascript
// Get overdue invoices
const overdueInvoices = await fetch('/api/v1/invoices?status=overdue');

// Send reminders
for (const invoice of overdueInvoices) {
  await sendPaymentReminder(invoice);
}
```

---

## Invoice Lifecycle

```
draft → sent → paid
  ↓       ↓      ↓
cancelled  overdue  void
```

1. **Draft** - Invoice created but not sent
2. **Sent** - Invoice sent to customer
3. **Paid** - Payment received (receipt generated)
4. **Overdue** - Past due date without payment
5. **Cancelled** - Invoice cancelled before payment
6. **Void** - Invoice voided after creation

---

## Receipt Lifecycle

```
issued → void
```

1. **Issued** - Receipt generated after payment
2. **Void** - Receipt voided (usually for refunds)

---

## Integration with Other Features

### With Payments
Receipts are automatically linked to payments for complete audit trail.

### With Orders & Subscriptions
Invoices and receipts can be linked to orders and subscriptions.

### With Account Balance (Optional)
Invoices can be paid using account balance, and receipts reflect the payment source.

### With Billing Schedules (Optional)
Automatically create invoices before scheduled charges and receipts after successful execution.

---

## Common Use Cases

### 1. **Service Invoicing**
Send invoices for services rendered (consulting, freelance work, etc.).

### 2. **Subscription Billing**
Generate invoices before subscription renewals.

### 3. **Guest Checkout**
Allow guest customers to receive invoices and receipts without accounts.

### 4. **B2B Payments**
Professional invoicing for business customers with NET payment terms.

### 5. **Installment Plans**
Create invoices for each installment payment.

### 6. **Refund Documentation**
Void receipts and invoices when processing refunds.

---

## Email Templates

### Invoice Email Template

```
Subject: Invoice #INV-2024-001 from [Your Company]

Hi [Customer Name],

You have a new invoice from [Your Company].

Invoice Number: INV-2024-001
Amount Due: $54.00
Due Date: February 15, 2024

[View Invoice] [Pay Now]

Thank you for your business!
```

### Receipt Email Template

```
Subject: Receipt #RCPT-2024-001 from [Your Company]

Hi [Customer Name],

Thank you for your payment!

Receipt Number: RCPT-2024-001
Amount Paid: $54.00
Payment Method: Visa ending in 4242
Date: January 15, 2024

[View Receipt] [Download PDF]

Questions? Contact us at support@example.com
```

---

## Migration Guide

To enable this feature in your existing database:

### MySQL
```sql
SOURCE /path/to/native-payments/mysql/schema.sql;
-- Note: invoices table already exists, only receipts will be added
```

### PostgreSQL
```sql
\i /path/to/native-payments/postgresql/schema.sql
```

### SQLite
```sql
.read /path/to/native-payments/sqlite/schema.sql
```

---

## Support

For questions or issues with the Invoices & Receipts feature:
- Check the main [Native-Payments Documentation](../README.md)
- Review [API Routes](./api-routes.md)
- See [Use Cases](./use-cases.md) for more examples


