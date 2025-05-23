# E-Commerce Store Implementation

This example demonstrates how to implement a payment flow for an e-commerce store using the Native Payments system. It covers the complete checkout process from cart to order confirmation.

## Use Case

An online store selling physical products with the following requirements:
- Process one-time payments for orders
- Support multiple payment methods (credit cards, PayPal, etc.)
- Handle shipping and billing addresses
- Calculate taxes and shipping costs
- Process refunds when necessary

## Implementation Flow

### 1. Product Catalog Setup

First, set up your product catalog in your database:

```javascript
// Example product categories
const categories = [
  {
    id: 'cat_electronics',
    name: 'Electronics',
    description: 'Electronic devices and accessories',
    image: 'https://example.com/images/categories/electronics.jpg',
    is_active: true,
    sort_order: 1
  },
  {
    id: 'cat_audio',
    name: 'Audio',
    description: 'Headphones, speakers, and audio accessories',
    parent_id: 'cat_electronics',
    image: 'https://example.com/images/categories/audio.jpg',
    is_active: true,
    sort_order: 1
  },
  // More categories...
];

// Create categories in your database
for (const category of categories) {
  await db.product_categories.create(category);
}

// Example product data structure
const products = [
  {
    id: 'prod_1',
    name: 'Wireless Headphones',
    description: 'Premium wireless headphones with noise cancellation',
    price_cents: 12999, // $129.99
    currency: 'USD',
    inventory_count: 100,
    product_type: 'physical',
    category_id: 'cat_audio',
    image: 'https://example.com/images/products/headphones-main.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/products/headphones-1.jpg',
      'https://example.com/images/products/headphones-2.jpg',
      'https://example.com/images/products/headphones-3.jpg'
    ]),
    weight_grams: 350,
    dimensions: {
      length_cm: 18,
      width_cm: 15,
      height_cm: 8
    }
  },
  // More products...
];

// Example product variations
const productVariations = [
  {
    id: 'prod_1_black',
    name: 'Wireless Headphones - Black',
    description: 'Premium wireless headphones with noise cancellation - Black color',
    price_cents: 12999, // $129.99
    currency: 'USD',
    inventory_count: 50,
    product_type: 'physical',
    category_id: 'cat_audio',
    parent_product_id: 'prod_1', // Reference to the parent product
    variations: JSON.stringify({
      color: 'Black'
    }),
    image: 'https://example.com/images/products/headphones-black-main.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/products/headphones-black-1.jpg',
      'https://example.com/images/products/headphones-black-2.jpg'
    ]),
    weight_grams: 350,
    dimensions: {
      length_cm: 18,
      width_cm: 15,
      height_cm: 8
    }
  },
  {
    id: 'prod_1_white',
    name: 'Wireless Headphones - White',
    description: 'Premium wireless headphones with noise cancellation - White color',
    price_cents: 12999, // $129.99
    currency: 'USD',
    inventory_count: 50,
    product_type: 'physical',
    category_id: 'cat_audio',
    parent_product_id: 'prod_1', // Reference to the parent product
    variations: JSON.stringify({
      color: 'White'
    }),
    image: 'https://example.com/images/products/headphones-white-main.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/products/headphones-white-1.jpg',
      'https://example.com/images/products/headphones-white-2.jpg'
    ]),
    weight_grams: 350,
    dimensions: {
      length_cm: 18,
      width_cm: 15,
      height_cm: 8
    }
  }
];

// Create products and variations in your database
for (const product of products) {
  await db.products.create(product);
}

for (const variation of productVariations) {
  await db.products.create(variation);
}
```

### 2. Shopping Cart Implementation

Implement a shopping cart to track items the user wants to purchase:

```javascript
// Add item to cart (client-side)
function addToCart(productId, quantity = 1) {
  let cart = JSON.parse(localStorage.getItem('cart') || '{"items":[]}');

  // Check if product already exists in cart
  const existingItemIndex = cart.items.findIndex(item => item.product_id === productId);

  if (existingItemIndex >= 0) {
    // Update quantity if product already in cart
    cart.items[existingItemIndex].quantity += quantity;
  } else {
    // Add new item to cart
    cart.items.push({
      product_id: productId,
      quantity: quantity
    });
  }

  // Save updated cart
  localStorage.setItem('cart', JSON.stringify(cart));
  updateCartUI();
}

// Calculate cart totals (can be done client-side or server-side)
async function calculateCartTotals(cart, shippingAddress) {
  // Fetch product details for all items in cart
  const productIds = cart.items.map(item => item.product_id);
  const products = await fetchProducts(productIds);

  // Calculate subtotal
  let subtotal_cents = 0;
  const items = cart.items.map(item => {
    const product = products.find(p => p.id === item.product_id);
    const item_total = product.price_cents * item.quantity;
    subtotal_cents += item_total;

    return {
      product_id: item.product_id,
      quantity: item.quantity,
      unit_price_cents: product.price_cents,
      total_cents: item_total,
      name: product.name
    };
  });

  // Calculate tax (this would typically call a tax service)
  const tax_cents = await calculateTax(subtotal_cents, shippingAddress);

  // Calculate shipping (this would typically call a shipping service)
  const shipping_cents = await calculateShipping(items, shippingAddress);

  // Calculate total
  const total_cents = subtotal_cents + tax_cents + shipping_cents;

  return {
    items,
    subtotal_cents,
    tax_cents,
    shipping_cents,
    total_cents
  };
}
```

### 3. Checkout Process

When the user proceeds to checkout:

```javascript
// 1. Collect shipping and billing addresses
const addressResponse = await fetch('/api/payment/addresses', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: userId,
    address_type: 'shipping', // or 'billing' or 'both'
    name: 'John Doe',
    line1: '123 Main St',
    line2: 'Apt 4B',
    city: 'San Francisco',
    state: 'CA',
    postal_code: '94103',
    country: 'US',
    phone: '+14155551234',
    is_default: true
  })
});

const shippingAddress = await addressResponse.json();

// 2. Create an order
const cart = JSON.parse(localStorage.getItem('cart'));
const cartTotals = await calculateCartTotals(cart, shippingAddress);

const orderResponse = await fetch('/api/payment/orders', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: userId,
    items: cartTotals.items.map(item => ({
      product_id: item.product_id,
      quantity: item.quantity
    })),
    shipping_address_id: shippingAddress.id,
    billing_address_id: billingAddressId || shippingAddress.id, // Use shipping address as billing if not provided
    subtotal_cents: cartTotals.subtotal_cents,
    tax_cents: cartTotals.tax_cents,
    shipping_cents: cartTotals.shipping_cents,
    total_cents: cartTotals.total_cents,
    currency: 'USD'
  })
});

const order = await orderResponse.json();
```

### 4. Payment Collection

Collect payment information and process the payment:

```javascript
// 1. Collect payment method (using Stripe Elements as an example)
const stripe = Stripe('your_publishable_key');
const elements = stripe.elements();
const cardElement = elements.create('card');
cardElement.mount('#card-element');

// When the user submits the payment form
const { paymentMethod, error } = await stripe.createPaymentMethod({
  type: 'card',
  card: cardElement,
});

if (error) {
  // Handle error
  displayError(error.message);
} else {
  // 2. Save the payment method (optional, for future use)
  const paymentMethodResponse = await fetch('/api/payment/methods', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_id: userId,
      provider_id: 'stripe',
      payment_type: 'credit_card',
      token: paymentMethod.id,
      is_default: true,
      billing_address_id: billingAddressId,
      // Add card brand icon based on the card type
      picture: `https://example.com/images/payment-methods/${paymentMethod.card.brand}.png`
    })
  });

  const savedPaymentMethod = await paymentMethodResponse.json();

  // 3. Process the payment
  const paymentResponse = await fetch(`/api/payment/orders/${order.id}/pay`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      payment_method_id: savedPaymentMethod.id
    })
  });

  const paymentResult = await paymentResponse.json();

  if (paymentResult.status === 'completed') {
    // Payment successful, show confirmation
    showOrderConfirmation(order.id);
    // Clear the cart
    localStorage.removeItem('cart');
  } else {
    // Payment failed, show error
    displayError('Payment failed. Please try again.');
  }
}
```

### 5. Order Fulfillment

After successful payment, handle order fulfillment:

```javascript
// Backend code to handle order fulfillment
async function fulfillOrder(orderId) {
  // 1. Get order details
  const order = await db.orders.findById(orderId);

  if (order.status !== 'paid') {
    throw new Error('Cannot fulfill unpaid order');
  }

  // 2. Update inventory
  for (const item of order.items) {
    await db.products.updateInventory(item.product_id, -item.quantity);
  }

  // 3. Create shipping label (integration with shipping provider)
  const shippingLabel = await createShippingLabel(order);

  // 4. Update order status
  await db.orders.update(orderId, {
    status: 'processing',
    tracking_number: shippingLabel.tracking_number,
    shipping_label_url: shippingLabel.label_url
  });

  // 5. Send confirmation email to customer
  await sendOrderConfirmationEmail(order);

  return { success: true, order };
}
```

### 6. Handling Refunds

When a customer requests a refund:

```javascript
// Process a refund
async function processRefund(orderId, reason, amount_cents = null) {
  // 1. Get order details
  const order = await db.orders.findById(orderId);
  const payment = await db.payments.findOne({ order_id: orderId });

  if (!payment) {
    throw new Error('No payment found for this order');
  }

  // 2. Process the refund through the payment system
  const refundResponse = await fetch(`/api/payment/intents/${payment.id}/refund`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount_cents: amount_cents || payment.amount_cents, // Full refund if amount not specified
      reason: reason
    })
  });

  const refund = await refundResponse.json();

  // 3. Update order status
  await db.orders.update(orderId, {
    status: amount_cents && amount_cents < payment.amount_cents ? 'partially_refunded' : 'refunded',
    refund_id: refund.id,
    refund_amount_cents: refund.amount_cents,
    refund_reason: reason
  });

  // 4. Update inventory if necessary
  if (reason === 'return' || reason === 'damaged') {
    for (const item of order.items) {
      await db.products.updateInventory(item.product_id, item.quantity);
    }
  }

  // 5. Send refund confirmation email
  await sendRefundConfirmationEmail(order, refund);

  return { success: true, refund };
}
```

## Sequence Diagram

```
┌─────┐          ┌─────────┐          ┌───────────────┐          ┌─────────────────┐
│User │          │Your App │          │Native Payments│          │Payment Provider │
└──┬──┘          └────┬────┘          └───────┬───────┘          └────────┬────────┘
   │  Add to Cart   │                         │                           │
   │─────────────────>                        │                           │
   │                │                         │                           │
   │  Checkout      │                         │                           │
   │─────────────────>                        │                           │
   │                │                         │                           │
   │  Enter Address │                         │                           │
   │─────────────────>                        │                           │
   │                │                         │                           │
   │                │  Create Address         │                           │
   │                │────────────────────────>│                           │
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │                │  Create Order           │                           │
   │                │────────────────────────>│                           │
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │  Enter Payment │                         │                           │
   │─────────────────>                        │                           │
   │                │                         │                           │
   │                │  Create Payment Method  │                           │
   │                │────────────────────────>│                           │
   │                │                         │  Create Payment Method    │
   │                │                         │─────────────────────────>│
   │                │                         │<─────────────────────────│
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │                │  Process Payment        │                           │
   │                │────────────────────────>│                           │
   │                │                         │  Create Payment Intent    │
   │                │                         │─────────────────────────>│
   │                │                         │<─────────────────────────│
   │                │<────────────────────────│                           │
   │                │                         │                           │
   │  Order         │                         │                           │
   │  Confirmation  │                         │                           │
   │<─────────────────                        │                           │
   │                │                         │                           │
   │                │  Fulfill Order          │                           │
   │                │───────────┐             │                           │
   │                │           │             │                           │
   │                │<──────────┘             │                           │
   │                │                         │                           │
   │  Shipping      │                         │                           │
   │  Confirmation  │                         │                           │
   │<─────────────────                        │                           │
```

## Best Practices

1. **Address Validation**: Validate shipping addresses to reduce delivery issues.
2. **Inventory Management**: Check inventory before accepting orders to avoid backorders.
3. **Order Confirmation**: Send immediate confirmation emails after successful payment.
4. **Shipping Updates**: Provide tracking information and shipping updates.
5. **Secure Payment**: Use tokenization and never store raw credit card details.
6. **Guest Checkout**: Allow purchases without requiring account creation.
7. **Mobile Optimization**: Ensure the checkout process works well on mobile devices.

## Common Issues and Solutions

1. **Cart Abandonment**: Implement cart recovery emails and simplified checkout.
2. **Payment Failures**: Provide clear error messages and alternative payment options.
3. **Fraud Prevention**: Implement basic fraud checks (address verification, CVV).
4. **International Orders**: Handle different currencies, taxes, and shipping requirements.
5. **Returns and Refunds**: Create a clear policy and streamlined process for returns.
