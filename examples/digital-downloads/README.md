# Digital Downloads Implementation

This example demonstrates how to implement a payment flow for a digital downloads platform using the Native Payments system. It covers the complete process from purchase to delivery of digital content.

## Use Case

A platform selling digital products such as:
- E-books and PDFs
- Music and audio files
- Software and applications
- Digital art and graphics
- Video courses

Key requirements:
- Instant delivery after payment
- Secure download links
- License management
- Optional subscription access

## Implementation Flow

### 1. Digital Product Setup

First, set up your digital products in your database:

```javascript
// Example product categories
const categories = [
  {
    id: 'cat_ebooks',
    name: 'E-Books',
    description: 'Digital books and guides',
    image: 'https://example.com/images/categories/ebooks.jpg',
    is_active: true,
    sort_order: 1
  },
  {
    id: 'cat_programming',
    name: 'Programming',
    description: 'Programming and development resources',
    parent_id: 'cat_ebooks',
    image: 'https://example.com/images/categories/programming.jpg',
    is_active: true,
    sort_order: 1
  },
  // More categories...
];

// Create categories in your database
for (const category of categories) {
  await db.product_categories.create(category);
}

// Example digital product data structure
const digitalProducts = [
  {
    id: 'prod_ebook1',
    name: 'Complete Guide to JavaScript',
    description: 'Comprehensive e-book covering modern JavaScript development',
    price_cents: 1999, // $19.99
    currency: 'USD',
    product_type: 'digital',
    category_id: 'cat_programming',
    image: 'https://example.com/images/products/js-guide-cover.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/products/js-guide-preview1.jpg',
      'https://example.com/images/products/js-guide-preview2.jpg',
      'https://example.com/images/products/js-guide-toc.jpg'
    ]),
    file_type: 'pdf',
    file_size_bytes: 15000000, // 15MB
    preview_url: 'https://example.com/previews/js-guide-sample.pdf',
    download_url: 'https://secure-downloads.example.com/files/js-guide-full.pdf',
    license_type: 'single_user',
    is_active: true
  },
  // More products...
];

// Create products in your database
for (const product of digitalProducts) {
  await db.products.create(product);
}
```

### 2. Purchase Flow

When a user wants to purchase a digital product:

```javascript
// 1. Create an order
const orderResponse = await fetch('/api/payment/orders', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    user_id: userId,
    items: [
      {
        product_id: 'prod_ebook1',
        quantity: 1
      }
    ],
    // For digital products, shipping address is optional
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

if (paymentResult.status === 'completed') {
  // Payment successful, proceed to delivery
  const deliveryResult = await deliverDigitalProducts(order.id);

  // Show download instructions
  showDownloadInstructions(deliveryResult.downloads);
}
```

### 3. Digital Product Delivery

After successful payment, deliver the digital products:

```javascript
// Backend function to deliver digital products
async function deliverDigitalProducts(orderId) {
  // 1. Get order details
  const order = await db.orders.findById(orderId);
  const payment = await db.payments.findOne({ order_id: orderId });

  if (payment.status !== 'completed') {
    throw new Error('Cannot deliver products for incomplete payment');
  }

  // 2. Generate secure download links for each item
  const downloads = [];
  for (const item of order.items) {
    const product = await db.products.findById(item.product_id);

    if (product.product_type !== 'digital') {
      continue; // Skip non-digital products
    }

    // Generate a unique, time-limited download token
    const downloadToken = generateSecureToken();
    const expiryTime = new Date();
    expiryTime.setHours(expiryTime.getHours() + 72); // Links expire after 72 hours

    // Create download record
    const download = await db.downloads.create({
      order_id: orderId,
      user_id: order.user_id,
      product_id: product.id,
      token: downloadToken,
      expires_at: expiryTime.toISOString(),
      max_downloads: 5, // Limit number of downloads
      download_count: 0,
      status: 'active'
    });

    // Generate download URL
    const downloadUrl = `https://your-app.com/download/${downloadToken}`;

    downloads.push({
      product_name: product.name,
      download_url: downloadUrl,
      expires_at: expiryTime,
      file_type: product.file_type,
      file_size_bytes: product.file_size_bytes
    });

    // Create license if applicable
    if (product.license_type) {
      const license = await generateLicense(product, order.user_id);
      await db.licenses.create({
        user_id: order.user_id,
        product_id: product.id,
        order_id: orderId,
        license_key: license.key,
        license_type: product.license_type,
        issued_at: new Date().toISOString(),
        is_active: true
      });
    }
  }

  // 3. Update order status
  await db.orders.update(orderId, {
    status: 'completed',
    completed_at: new Date().toISOString()
  });

  // 4. Send email with download links
  await sendDownloadEmail(order.user_id, downloads);

  return { success: true, downloads };
}

// Function to handle download requests
async function handleDownload(downloadToken) {
  // 1. Find the download record
  const download = await db.downloads.findOne({ token: downloadToken });

  if (!download) {
    throw new Error('Invalid download token');
  }

  // 2. Check if download is still valid
  const now = new Date();
  if (new Date(download.expires_at) < now) {
    throw new Error('Download link has expired');
  }

  if (download.download_count >= download.max_downloads) {
    throw new Error('Maximum number of downloads reached');
  }

  // 3. Get the product
  const product = await db.products.findById(download.product_id);

  // 4. Update download count
  await db.downloads.update(download.id, {
    download_count: download.download_count + 1,
    last_downloaded_at: now.toISOString()
  });

  // 5. Return the secure file URL (typically a signed URL with short expiration)
  const fileUrl = await generateSignedUrl(product.download_url, 15); // 15 minutes expiry

  return {
    file_url: fileUrl,
    file_name: product.name + getFileExtension(product.file_type),
    content_type: getContentType(product.file_type)
  };
}

// Helper function to generate a secure download token
function generateSecureToken() {
  return crypto.randomBytes(32).toString('hex');
}

// Helper function to generate a license key
async function generateLicense(product, userId) {
  const user = await db.users.findById(userId);
  const licenseKey = `${product.id.substring(0, 8)}-${crypto.randomBytes(4).toString('hex')}-${crypto.randomBytes(4).toString('hex')}-${crypto.randomBytes(4).toString('hex')}`;

  return {
    key: licenseKey,
    user_name: user.name,
    user_email: user.email,
    issued_date: new Date().toISOString()
  };
}
```

### 4. User Library and Download Management

Provide users with a library to access their purchased digital products:

```javascript
// Function to get user's library of purchased digital products
async function getUserLibrary(userId) {
  // 1. Get all completed orders for the user
  const orders = await db.orders.findAll({
    user_id: userId,
    status: 'completed'
  });

  // 2. Get all digital products from these orders
  const libraryItems = [];
  for (const order of orders) {
    for (const item of order.items) {
      const product = await db.products.findById(item.product_id);

      if (product.product_type !== 'digital') {
        continue;
      }

      // Get the most recent download record
      const download = await db.downloads.findOne({
        user_id: userId,
        product_id: product.id,
        status: 'active'
      }, { order_by: 'created_at', direction: 'desc' });

      // Get license if available
      const license = await db.licenses.findOne({
        user_id: userId,
        product_id: product.id,
        is_active: true
      });

      libraryItems.push({
        id: product.id,
        name: product.name,
        description: product.description,
        file_type: product.file_type,
        file_size_bytes: product.file_size_bytes,
        purchase_date: order.completed_at,
        can_download: download && new Date(download.expires_at) > new Date() && download.download_count < download.max_downloads,
        download_url: download ? `/download/${download.token}` : null,
        download_expiry: download ? download.expires_at : null,
        downloads_remaining: download ? download.max_downloads - download.download_count : 0,
        license_key: license ? license.license_key : null,
        license_type: license ? license.license_type : null
      });
    }
  }

  return libraryItems;
}

// Function to generate a new download link if expired
async function regenerateDownloadLink(userId, productId) {
  // 1. Verify the user owns this product
  const license = await db.licenses.findOne({
    user_id: userId,
    product_id: productId,
    is_active: true
  });

  if (!license) {
    throw new Error('You do not own this product');
  }

  // 2. Generate a new download token
  const downloadToken = generateSecureToken();
  const expiryTime = new Date();
  expiryTime.setHours(expiryTime.getHours() + 72);

  // 3. Create a new download record
  const download = await db.downloads.create({
    user_id: userId,
    product_id: productId,
    order_id: license.order_id,
    token: downloadToken,
    expires_at: expiryTime.toISOString(),
    max_downloads: 5,
    download_count: 0,
    status: 'active'
  });

  // 4. Return the new download URL
  return {
    download_url: `/download/${downloadToken}`,
    expires_at: download.expires_at,
    max_downloads: download.max_downloads
  };
}
```

## Sequence Diagram

```
┌─────┐          ┌─────────┐          ┌───────────────┐          ┌─────────────────┐
│User │          │Your App │          │Native Payments│          │Payment Provider │
└──┬──┘          └────┬────┘          └───────┬───────┘          └────────┬────────┘
   │  Browse Products │                       │                           │
   │─────────────────>│                       │                           │
   │                  │                       │                           │
   │  Purchase Product│                       │                           │
   │─────────────────>│                       │                           │
   │                  │                       │                           │
   │                  │  Create Order         │                           │
   │                  │──────────────────────>│                           │
   │                  │<──────────────────────│                           │
   │                  │                       │                           │
   │  Enter Payment   │                       │                           │
   │─────────────────>│                       │                           │
   │                  │                       │                           │
   │                  │  Process Payment      │                           │
   │                  │──────────────────────>│                           │
   │                  │                       │  Create Payment Intent    │
   │                  │                       │─────────────────────────>│
   │                  │                       │<─────────────────────────│
   │                  │<──────────────────────│                           │
   │                  │                       │                           │
   │                  │  Generate Download    │                           │
   │                  │  Links                │                           │
   │                  │──────┐                │                           │
   │                  │      │                │                           │
   │                  │<─────┘                │                           │
   │                  │                       │                           │
   │  Download Links  │                       │                           │
   │<─────────────────│                       │                           │
   │                  │                       │                           │
   │  Access Download │                       │                           │
   │─────────────────>│                       │                           │
   │                  │                       │                           │
   │                  │  Verify Token         │                           │
   │                  │──────┐                │                           │
   │                  │      │                │                           │
   │                  │<─────┘                │                           │
   │                  │                       │                           │
   │  File Download   │                       │                           │
   │<─────────────────│                       │                           │
   │                  │                       │                           │
```

## Best Practices

1. **Secure Downloads**: Use signed URLs or token-based authentication for downloads.
2. **Download Limits**: Implement reasonable limits on download attempts and expiration times.
3. **License Management**: Provide clear license terms and easy access to license keys.
4. **Preview Content**: Offer previews or samples before purchase.
5. **Instant Delivery**: Deliver content immediately after payment confirmation.
6. **Redownload Access**: Allow customers to redownload purchases from their account.
7. **File Hosting**: Use a reliable CDN or file hosting service for large files.

## Common Issues and Solutions

1. **Download Failures**: Implement resumable downloads for large files.
2. **License Activation**: Provide clear instructions for activating software licenses.
3. **File Compatibility**: Clearly communicate system requirements and file formats.
4. **Piracy Protection**: Consider implementing watermarking or other anti-piracy measures.
5. **Updates**: Establish a system for delivering updates to digital products.
6. **Support Access**: Provide easy access to support for installation or usage issues.
