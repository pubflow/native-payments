# Marketplace Payment Implementation

This example demonstrates how to implement a payment flow for a marketplace platform that connects buyers and sellers, using the Native Payments system.

## Use Case

A marketplace platform where:
- Sellers list products or services
- Buyers purchase from multiple sellers
- The platform takes a commission on each sale
- Funds are distributed to sellers after deducting the platform fee

## Implementation Flow

### 1. Seller Onboarding

When a seller joins your marketplace:

```javascript
// 1. Create a user in your system
const seller = await db.users.create({
  name: 'Jane Smith',
  email: 'jane@example.com',
  user_type: 'seller',
  // other user details
});

// 2. Create a customer in the payment system
const customerResponse = await fetch('/api/payment/customers', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: seller.id,
    provider_id: 'stripe', // or your preferred payment provider
    email: seller.email,
    name: seller.name
  })
});

const customer = await customerResponse.json();

// 3. Collect seller-specific information
const sellerProfileResponse = await fetch('/api/sellers', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: seller.id,
    business_name: 'Jane\'s Boutique',
    tax_id: '123456789',
    business_type: 'individual',
    // other business details
  })
});

// 4. Set up payout method (bank account)
const payoutMethodResponse = await fetch('/api/payment/methods', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: seller.id,
    provider_id: 'stripe',
    payment_type: 'bank_account',
    token: bankAccountToken, // Obtained from Stripe.js or similar
    is_default: true
  })
});

const payoutMethod = await payoutMethodResponse.json();
```

### 2. Product Listing

Sellers can list their products on the marketplace:

```javascript
// Create product categories
const categoriesResponse = await fetch('/api/product-categories', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    id: 'cat_home_goods',
    name: 'Home Goods',
    description: 'Products for your home',
    image: 'https://example.com/images/categories/home-goods.jpg',
    is_active: true,
    sort_order: 1
  })
});

const category = await categoriesResponse.json();

// Create a product listing
const productResponse = await fetch('/api/products', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    seller_id: seller.id,
    name: 'Handmade Ceramic Mug',
    description: 'Beautiful handcrafted ceramic mug, perfect for your morning coffee',
    price_cents: 2500, // $25.00
    currency: 'USD',
    inventory_count: 10,
    category_id: 'cat_home_goods',
    image: 'https://example.com/images/products/mug-main.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/products/mug1.jpg',
      'https://example.com/images/products/mug2.jpg',
      'https://example.com/images/products/mug3.jpg'
    ]),
    shipping_weight_grams: 500,
    dimensions: {
      length_cm: 12,
      width_cm: 8,
      height_cm: 10
    }
  })
});

const product = await productResponse.json();
```

### 3. Buyer Purchase Flow

When a buyer makes a purchase:

```javascript
// 1. Create an order
const orderResponse = await fetch('/api/payment/orders', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: buyer.id,
    items: [
      {
        product_id: 'product_123',
        quantity: 2,
        seller_id: 'seller_456' // Important for marketplace to track seller
      },
      {
        product_id: 'product_789',
        quantity: 1,
        seller_id: 'seller_012'
      }
    ],
    shipping_address_id: shippingAddressId,
    billing_address_id: billingAddressId,
    // The system will calculate totals based on the items
  })
});

const order = await orderResponse.json();

// 2. Process payment
const paymentResponse = await fetch(`/api/payment/orders/${order.id}/pay`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    payment_method_id: paymentMethodId
  })
});

const paymentResult = await paymentResponse.json();
```

### 4. Commission Calculation and Seller Payouts

After a successful payment, calculate commissions and create payouts:

```javascript
// Backend function to process marketplace order
async function processMarketplaceOrder(orderId) {
  // 1. Get order details
  const order = await db.orders.findById(orderId);
  const payment = await db.payments.findOne({ order_id: orderId });

  if (payment.status !== 'completed') {
    throw new Error('Cannot process payouts for incomplete payment');
  }

  // 2. Group items by seller
  const sellerItems = {};
  for (const item of order.items) {
    if (!sellerItems[item.seller_id]) {
      sellerItems[item.seller_id] = [];
    }
    sellerItems[item.seller_id].push(item);
  }

  // 3. Calculate amounts for each seller
  const payouts = [];
  for (const sellerId in sellerItems) {
    const items = sellerItems[sellerId];

    // Calculate seller's total
    let sellerTotal = 0;
    for (const item of items) {
      sellerTotal += item.total_cents;
    }

    // Calculate platform fee (e.g., 10%)
    const platformFeePercent = 0.10;
    const platformFee = Math.round(sellerTotal * platformFeePercent);
    const sellerAmount = sellerTotal - platformFee;

    // Create payout record
    const payout = {
      seller_id: sellerId,
      order_id: orderId,
      amount_cents: sellerAmount,
      fee_cents: platformFee,
      currency: order.currency,
      items: items,
      status: 'pending'
    };

    payouts.push(await db.payouts.create(payout));
  }

  // 4. Update order with payout information
  await db.orders.update(orderId, {
    payouts: payouts.map(p => p.id),
    status: 'processing'
  });

  return payouts;
}

// Function to execute payouts to sellers
async function executePayouts(payoutIds) {
  for (const payoutId of payoutIds) {
    const payout = await db.payouts.findById(payoutId);
    const seller = await db.users.findById(payout.seller_id);

    // Get seller's payout method
    const payoutMethod = await db.paymentMethods.findOne({
      user_id: seller.id,
      is_default: true,
      payment_type: 'bank_account'
    });

    if (!payoutMethod) {
      // Handle missing payout method
      await db.payouts.update(payoutId, { status: 'failed', error: 'No payout method found' });
      continue;
    }

    try {
      // Create transfer through payment provider
      const transferResponse = await fetch('/api/payment/transfers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          destination_user_id: seller.id,
          payment_method_id: payoutMethod.id,
          amount_cents: payout.amount_cents,
          currency: payout.currency,
          description: `Payout for order #${payout.order_id}`,
          metadata: {
            payout_id: payout.id,
            order_id: payout.order_id
          }
        })
      });

      const transfer = await transferResponse.json();

      // Update payout status
      await db.payouts.update(payoutId, {
        status: 'completed',
        transfer_id: transfer.id,
        completed_at: new Date().toISOString()
      });

      // Notify seller
      await sendSellerPayoutNotification(seller, payout);

    } catch (error) {
      // Handle payout failure
      await db.payouts.update(payoutId, {
        status: 'failed',
        error: error.message
      });
    }
  }
}
```

### 5. Order Fulfillment by Sellers

Notify sellers of new orders and track fulfillment:

```javascript
// Function to notify sellers of new orders
async function notifySellers(orderId) {
  const order = await db.orders.findById(orderId);

  // Group items by seller
  const sellerItems = {};
  for (const item of order.items) {
    if (!sellerItems[item.seller_id]) {
      sellerItems[item.seller_id] = [];
    }
    sellerItems[item.seller_id].push(item);
  }

  // Notify each seller
  for (const sellerId in sellerItems) {
    const seller = await db.users.findById(sellerId);
    const items = sellerItems[sellerId];

    // Create seller order
    const sellerOrder = await db.sellerOrders.create({
      seller_id: sellerId,
      order_id: orderId,
      items: items,
      buyer_id: order.user_id,
      shipping_address_id: order.shipping_address_id,
      status: 'new',
      created_at: new Date().toISOString()
    });

    // Send notification
    await sendSellerOrderNotification(seller, sellerOrder);
  }
}

// Function for sellers to mark orders as shipped
async function markOrderShipped(sellerOrderId, trackingNumber, carrier) {
  const sellerOrder = await db.sellerOrders.findById(sellerOrderId);

  // Update seller order
  await db.sellerOrders.update(sellerOrderId, {
    status: 'shipped',
    tracking_number: trackingNumber,
    carrier: carrier,
    shipped_at: new Date().toISOString()
  });

  // Check if all seller orders for this order are shipped
  const allSellerOrders = await db.sellerOrders.findAll({ order_id: sellerOrder.order_id });
  const allShipped = allSellerOrders.every(so => so.status === 'shipped');

  if (allShipped) {
    // Update main order status
    await db.orders.update(sellerOrder.order_id, {
      status: 'shipped'
    });
  }

  // Notify buyer
  const order = await db.orders.findById(sellerOrder.order_id);
  const buyer = await db.users.findById(order.user_id);
  await sendShippingNotification(buyer, sellerOrder);

  return { success: true };
}
```

## Sequence Diagram

```
┌──────┐        ┌─────────┐        ┌───────────────┐        ┌─────────────────┐        ┌──────┐
│Buyer │        │Your App │        │Native Payments│        │Payment Provider │        │Seller│
└──┬───┘        └────┬────┘        └───────┬───────┘        └────────┬────────┘        └──┬───┘
   │  Purchase     │                       │                          │                   │
   │────────────────>                      │                          │                   │
   │                │                      │                          │                   │
   │                │  Create Order        │                          │                   │
   │                │─────────────────────>│                          │                   │
   │                │<─────────────────────│                          │                   │
   │                │                      │                          │                   │
   │                │  Process Payment     │                          │                   │
   │                │─────────────────────>│                          │                   │
   │                │                      │  Create Payment Intent   │                   │
   │                │                      │────────────────────────>│                   │
   │                │                      │<────────────────────────│                   │
   │                │<─────────────────────│                          │                   │
   │                │                      │                          │                   │
   │  Order         │                      │                          │                   │
   │  Confirmation  │                      │                          │                   │
   │<────────────────                      │                          │                   │
   │                │                      │                          │                   │
   │                │  Calculate           │                          │                   │
   │                │  Commissions         │                          │                   │
   │                │──────┐               │                          │                   │
   │                │      │               │                          │                   │
   │                │<─────┘               │                          │                   │
   │                │                      │                          │                   │
   │                │  Notify Seller       │                          │                   │
   │                │──────────────────────────────────────────────────────────────────>│
   │                │                      │                          │                   │
   │                │                      │                          │                   │  Fulfill
   │                │                      │                          │                   │  Order
   │                │                      │                          │                   │──────┐
   │                │                      │                          │                   │      │
   │                │                      │                          │                   │<─────┘
   │                │                      │                          │                   │
   │                │  Mark as Shipped     │                          │                   │
   │                │<──────────────────────────────────────────────────────────────────│
   │                │                      │                          │                   │
   │  Shipping      │                      │                          │                   │
   │  Notification  │                      │                          │                   │
   │<────────────────                      │                          │                   │
   │                │                      │                          │                   │
   │                │  Process Payout      │                          │                   │
   │                │─────────────────────>│                          │                   │
   │                │                      │  Create Transfer         │                   │
   │                │                      │────────────────────────>│                   │
   │                │                      │<────────────────────────│                   │
   │                │<─────────────────────│                          │                   │
   │                │                      │                          │                   │
   │                │  Payout Notification │                          │                   │
   │                │──────────────────────────────────────────────────────────────────>│
```

## Best Practices

1. **Clear Fee Structure**: Be transparent about platform fees and payment processing fees.
2. **Seller Verification**: Implement KYC (Know Your Customer) processes for sellers.
3. **Escrow Payments**: Hold funds until buyers confirm receipt or a set period passes.
4. **Dispute Resolution**: Create a clear process for handling disputes between buyers and sellers.
5. **Automated Payouts**: Set up regular, automated payouts to sellers.
6. **Tax Compliance**: Provide necessary tax documentation for sellers.
7. **Multi-Currency Support**: Allow transactions in different currencies if operating globally.

## Common Issues and Solutions

1. **Seller Onboarding Friction**: Simplify the onboarding process while maintaining necessary verification.
2. **Payment Delays**: Clearly communicate payout schedules and processing times.
3. **Fraud Prevention**: Implement systems to detect and prevent fraudulent transactions.
4. **Chargeback Management**: Create processes to handle chargebacks and protect sellers when appropriate.
5. **Cross-Border Payments**: Address currency conversion and international payment regulations.
6. **Scalability**: Ensure your payment system can handle growing transaction volumes.
