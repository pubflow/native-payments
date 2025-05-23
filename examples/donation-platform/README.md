# Donation Platform Implementation

This example demonstrates how to implement a payment flow for a donation platform using the Native Payments system. It covers one-time and recurring donations with variable amounts.

## Use Case

A donation platform that allows:
- One-time donations of any amount
- Recurring monthly/annual donations
- Donations to specific campaigns or general funds
- Optional donor information collection
- Tax receipts for donations

## Implementation Flow

### 1. Campaign Setup

First, set up your donation campaigns in your database:

```javascript
// Example campaign categories
const campaignCategories = [
  {
    id: 'cat_disaster_relief',
    name: 'Disaster Relief',
    description: 'Campaigns supporting disaster relief efforts',
    image: 'https://example.com/images/categories/disaster-relief.jpg',
    is_active: true,
    sort_order: 1
  },
  // More categories...
];

// Create campaign categories in your database
for (const category of campaignCategories) {
  await db.product_categories.create(category);
}

// Example campaign data structure
const campaigns = [
  {
    id: 'campaign_disaster_relief',
    name: 'Disaster Relief Fund',
    description: 'Emergency support for communities affected by natural disasters',
    goal_cents: 5000000, // $50,000
    current_cents: 1250000, // $12,500
    currency: 'USD',
    start_date: '2023-06-01T00:00:00Z',
    end_date: '2023-12-31T23:59:59Z',
    is_active: true,
    category_id: 'cat_disaster_relief',
    image: 'https://example.com/images/campaigns/disaster-relief-main.jpg',
    gallery: JSON.stringify([
      'https://example.com/images/campaigns/disaster-relief-1.jpg',
      'https://example.com/images/campaigns/disaster-relief-2.jpg',
      'https://example.com/images/campaigns/disaster-relief-3.jpg'
    ]),
    suggested_amounts: [1000, 2500, 5000, 10000] // $10, $25, $50, $100
  },
  // More campaigns...
];

// Create campaigns in your database
for (const campaign of campaigns) {
  await db.campaigns.create(campaign);
}
```

### 2. One-Time Donation Flow

When a user wants to make a one-time donation:

```javascript
// 1. Collect donation details
const donationForm = document.getElementById('donation-form');
donationForm.addEventListener('submit', async (event) => {
  event.preventDefault();

  const formData = new FormData(donationForm);
  const donationData = {
    campaign_id: formData.get('campaign_id'),
    amount_cents: parseFloat(formData.get('amount')) * 100, // Convert dollars to cents
    currency: 'USD',
    donor_name: formData.get('name'),
    donor_email: formData.get('email'),
    is_anonymous: formData.get('anonymous') === 'on',
    comment: formData.get('comment')
  };

  // 2. Create a donation order
  const orderResponse = await fetch('/api/payment/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      // User ID is optional for donations
      user_id: userId || null,
      items: [
        {
          product_id: donationData.campaign_id,
          quantity: 1,
          unit_price_cents: donationData.amount_cents,
          metadata: {
            donation_type: 'one_time',
            donor_name: donationData.donor_name,
            donor_email: donationData.donor_email,
            is_anonymous: donationData.is_anonymous,
            comment: donationData.comment
          }
        }
      ],
      currency: donationData.currency,
      metadata: {
        donation_type: 'one_time',
        campaign_id: donationData.campaign_id
      }
    })
  });

  const order = await orderResponse.json();

  // 3. Collect payment information
  const stripe = Stripe('your_publishable_key');
  const elements = stripe.elements();
  const cardElement = elements.create('card');
  cardElement.mount('#card-element');

  const { paymentMethod, error } = await stripe.createPaymentMethod({
    type: 'card',
    card: cardElement,
  });

  if (error) {
    // Handle error
    displayError(error.message);
    return;
  }

  // 4. Save the payment method
  const paymentMethodResponse = await fetch('/api/payment/methods', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_id: userId || null, // Optional for guest donations
      provider_id: 'stripe',
      payment_type: 'credit_card',
      token: paymentMethod.id,
      is_default: true
    })
  });

  const savedPaymentMethod = await paymentMethodResponse.json();

  // 5. Process the payment
  const paymentResponse = await fetch(`/api/payment/orders/${order.id}/pay`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      payment_method_id: savedPaymentMethod.id
    })
  });

  const paymentResult = await paymentResponse.json();

  if (paymentResult.status === 'completed') {
    // 6. Show donation confirmation
    showDonationConfirmation(order, donationData);

    // 7. Send thank you email
    await sendDonationThankYouEmail(donationData);
  } else {
    // Handle payment failure
    displayError('Payment failed. Please try again.');
  }
});
```

### 3. Recurring Donation Flow

For recurring donations:

```javascript
// 1. Collect recurring donation details
const recurringDonationForm = document.getElementById('recurring-donation-form');
recurringDonationForm.addEventListener('submit', async (event) => {
  event.preventDefault();

  const formData = new FormData(recurringDonationForm);
  const donationData = {
    campaign_id: formData.get('campaign_id'),
    amount_cents: parseFloat(formData.get('amount')) * 100,
    currency: 'USD',
    interval: formData.get('interval'), // 'monthly' or 'yearly'
    donor_name: formData.get('name'),
    donor_email: formData.get('email'),
    is_anonymous: formData.get('anonymous') === 'on'
  };

  // 2. Create a subscription product if it doesn't exist
  let productId = `donation_${donationData.interval}_${donationData.campaign_id}`;
  let product = await db.products.findOne({ id: productId });

  if (!product) {
    const campaign = await db.campaigns.findById(donationData.campaign_id);

    const productResponse = await fetch('/api/payment/products', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: productId,
        name: `${campaign.name} - ${donationData.interval.charAt(0).toUpperCase() + donationData.interval.slice(1)} Donation`,
        description: `Recurring ${donationData.interval} donation to ${campaign.name}`,
        product_type: 'subscription',
        is_recurring: true,
        price_cents: donationData.amount_cents,
        currency: donationData.currency,
        billing_interval: donationData.interval,
        metadata: {
          donation_type: 'recurring',
          campaign_id: donationData.campaign_id
        }
      })
    });

    product = await productResponse.json();
  }

  // 3. Collect payment information
  const stripe = Stripe('your_publishable_key');
  const elements = stripe.elements();
  const cardElement = elements.create('card');
  cardElement.mount('#card-element');

  const { paymentMethod, error } = await stripe.createPaymentMethod({
    type: 'card',
    card: cardElement,
  });

  if (error) {
    // Handle error
    displayError(error.message);
    return;
  }

  // 4. Create or get user (required for subscriptions)
  let user = null;
  if (userId) {
    user = await db.users.findById(userId);
  } else {
    // Create a new user for the donor
    const userResponse = await fetch('/api/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: donationData.donor_name,
        email: donationData.donor_email,
        user_type: 'donor'
      })
    });

    user = await userResponse.json();
    userId = user.id;

    // Create a customer in the payment system
    await fetch('/api/payment/customers', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: userId,
        provider_id: 'stripe',
        email: user.email,
        name: user.name
      })
    });
  }

  // 5. Save the payment method
  const paymentMethodResponse = await fetch('/api/payment/methods', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_id: userId,
      provider_id: 'stripe',
      payment_type: 'credit_card',
      token: paymentMethod.id,
      is_default: true
    })
  });

  const savedPaymentMethod = await paymentMethodResponse.json();

  // 6. Create the subscription
  const subscriptionResponse = await fetch('/api/payment/subscriptions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      user_id: userId,
      product_id: productId,
      payment_method_id: savedPaymentMethod.id,
      metadata: {
        donation_type: 'recurring',
        campaign_id: donationData.campaign_id,
        donor_name: donationData.donor_name,
        donor_email: donationData.donor_email,
        is_anonymous: donationData.is_anonymous
      }
    })
  });

  const subscription = await subscriptionResponse.json();

  // 7. Show confirmation
  showRecurringDonationConfirmation(subscription, donationData);

  // 8. Send thank you email
  await sendRecurringDonationThankYouEmail(donationData, subscription);
});
```

### 4. Donation Management

Backend functions to manage donations:

```javascript
// Function to process a successful donation
async function processDonation(orderId) {
  // 1. Get order details
  const order = await db.orders.findById(orderId);
  const payment = await db.payments.findOne({ order_id: orderId });

  if (payment.status !== 'completed') {
    return; // Only process completed payments
  }

  // 2. Extract donation details
  const donationItem = order.items[0];
  const campaignId = order.metadata.campaign_id;
  const donationType = order.metadata.donation_type;
  const donorInfo = donationItem.metadata;

  // 3. Update campaign totals
  await db.campaigns.updateOne(
    { id: campaignId },
    { $inc: { current_cents: donationItem.total_cents } }
  );

  // 4. Create donation record
  const donation = await db.donations.create({
    order_id: orderId,
    payment_id: payment.id,
    campaign_id: campaignId,
    user_id: order.user_id,
    amount_cents: donationItem.total_cents,
    currency: order.currency,
    donation_type: donationType,
    donor_name: donorInfo.donor_name,
    donor_email: donorInfo.donor_email,
    is_anonymous: donorInfo.is_anonymous,
    comment: donorInfo.comment,
    donation_date: new Date().toISOString()
  });

  // 5. Generate tax receipt if applicable
  if (donorInfo.donor_email) {
    const taxReceipt = await generateTaxReceipt(donation);
    await sendTaxReceiptEmail(donorInfo.donor_email, taxReceipt);
  }

  return donation;
}

// Function to handle recurring donation payments
async function processRecurringDonation(subscriptionId, paymentId) {
  // 1. Get subscription and payment details
  const subscription = await db.subscriptions.findById(subscriptionId);
  const payment = await db.payments.findById(paymentId);

  if (payment.status !== 'completed') {
    return; // Only process completed payments
  }

  // 2. Extract donation details
  const campaignId = subscription.metadata.campaign_id;
  const donorInfo = subscription.metadata;

  // 3. Update campaign totals
  await db.campaigns.updateOne(
    { id: campaignId },
    { $inc: { current_cents: payment.amount_cents } }
  );

  // 4. Create donation record
  const donation = await db.donations.create({
    subscription_id: subscriptionId,
    payment_id: paymentId,
    campaign_id: campaignId,
    user_id: subscription.user_id,
    amount_cents: payment.amount_cents,
    currency: payment.currency,
    donation_type: 'recurring',
    donor_name: donorInfo.donor_name,
    donor_email: donorInfo.donor_email,
    is_anonymous: donorInfo.is_anonymous,
    donation_date: new Date().toISOString()
  });

  // 5. Generate tax receipt if applicable
  if (donorInfo.donor_email) {
    const taxReceipt = await generateTaxReceipt(donation);
    await sendTaxReceiptEmail(donorInfo.donor_email, taxReceipt);
  }

  return donation;
}

// Function to generate a tax receipt
async function generateTaxReceipt(donation) {
  const organization = await db.organizations.findOne({ is_default: true });
  const campaign = await db.campaigns.findById(donation.campaign_id);

  const receiptNumber = `R-${new Date().getFullYear()}-${String(donation.id).substring(0, 8)}`;

  const taxReceipt = {
    receipt_number: receiptNumber,
    organization_name: organization.name,
    organization_tax_id: organization.tax_id,
    donor_name: donation.donor_name,
    donor_email: donation.donor_email,
    donation_amount: donation.amount_cents / 100,
    donation_currency: donation.currency,
    donation_date: donation.donation_date,
    campaign_name: campaign.name,
    is_tax_deductible: true,
    pdf_url: null // Will be generated later
  };

  // Generate PDF receipt (implementation depends on your PDF generation library)
  const pdfUrl = await generateReceiptPDF(taxReceipt);
  taxReceipt.pdf_url = pdfUrl;

  // Save receipt to database
  await db.taxReceipts.create({
    ...taxReceipt,
    donation_id: donation.id
  });

  return taxReceipt;
}
```

### 5. Donation Reporting

Functions to generate donation reports:

```javascript
// Function to get campaign statistics
async function getCampaignStats(campaignId) {
  const campaign = await db.campaigns.findById(campaignId);

  // Get all donations for this campaign
  const donations = await db.donations.findAll({ campaign_id: campaignId });

  // Calculate statistics
  const totalDonations = donations.length;
  const totalAmount = donations.reduce((sum, donation) => sum + donation.amount_cents, 0) / 100;
  const averageDonation = totalAmount / totalDonations;

  // Count one-time vs recurring
  const oneTimeDonations = donations.filter(d => d.donation_type === 'one_time').length;
  const recurringDonations = donations.filter(d => d.donation_type === 'recurring').length;

  // Get unique donors
  const uniqueDonors = new Set();
  donations.forEach(d => {
    if (d.user_id) {
      uniqueDonors.add(d.user_id);
    } else if (d.donor_email) {
      uniqueDonors.add(d.donor_email);
    }
  });

  return {
    campaign_name: campaign.name,
    goal_amount: campaign.goal_cents / 100,
    current_amount: campaign.current_cents / 100,
    progress_percentage: (campaign.current_cents / campaign.goal_cents) * 100,
    total_donations: totalDonations,
    unique_donors: uniqueDonors.size,
    average_donation: averageDonation,
    one_time_donations: oneTimeDonations,
    recurring_donations: recurringDonations,
    currency: campaign.currency
  };
}

// Function to generate donor report
async function generateDonorReport(campaignId, startDate, endDate) {
  // Query donations within date range
  const query = { campaign_id: campaignId };
  if (startDate || endDate) {
    query.donation_date = {};
    if (startDate) query.donation_date.$gte = startDate;
    if (endDate) query.donation_date.$lte = endDate;
  }

  const donations = await db.donations.findAll(query);

  // Group by donor
  const donorMap = {};
  donations.forEach(donation => {
    const donorKey = donation.user_id || donation.donor_email;
    if (!donorKey) return; // Skip anonymous donations without user ID

    if (!donorMap[donorKey]) {
      donorMap[donorKey] = {
        donor_name: donation.donor_name,
        donor_email: donation.donor_email,
        user_id: donation.user_id,
        total_amount: 0,
        donation_count: 0,
        first_donation: donation.donation_date,
        last_donation: donation.donation_date,
        donations: []
      };
    }

    const donor = donorMap[donorKey];
    donor.total_amount += donation.amount_cents;
    donor.donation_count += 1;

    if (new Date(donation.donation_date) < new Date(donor.first_donation)) {
      donor.first_donation = donation.donation_date;
    }

    if (new Date(donation.donation_date) > new Date(donor.last_donation)) {
      donor.last_donation = donation.donation_date;
    }

    donor.donations.push({
      id: donation.id,
      amount: donation.amount_cents / 100,
      date: donation.donation_date,
      type: donation.donation_type
    });
  });

  // Convert to array and sort by total amount
  const donors = Object.values(donorMap).map(donor => ({
    ...donor,
    total_amount: donor.total_amount / 100
  }));

  donors.sort((a, b) => b.total_amount - a.total_amount);

  return donors;
}
```

## Sequence Diagram

```
┌─────┐          ┌─────────┐          ┌───────────────┐          ┌─────────────────┐
│Donor│          │Your App │          │Native Payments│          │Payment Provider │
└──┬──┘          └────┬────┘          └───────┬───────┘          └────────┬────────┘
   │  Select Campaign │                       │                           │
   │─────────────────>│                       │                           │
   │                  │                       │                           │
   │  Enter Donation  │                       │                           │
   │  Amount & Info   │                       │                           │
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
   │                  │  Process Donation     │                           │
   │                  │──────┐                │                           │
   │                  │      │                │                           │
   │                  │<─────┘                │                           │
   │                  │                       │                           │
   │  Thank You &     │                       │                           │
   │  Receipt         │                       │                           │
   │<─────────────────│                       │                           │
   │                  │                       │                           │
```

## Best Practices

1. **Transparency**: Clearly communicate how donations are used.
2. **Suggested Amounts**: Offer suggested donation amounts but allow custom amounts.
3. **Recurring Options**: Make it easy to set up recurring donations.
4. **Tax Receipts**: Automatically generate and send tax receipts.
5. **Donor Recognition**: Allow donors to choose whether to be recognized publicly.
6. **Campaign Progress**: Show progress towards fundraising goals.
7. **Mobile Optimization**: Ensure the donation process works well on mobile devices.

## Common Issues and Solutions

1. **Donation Abandonment**: Simplify the donation form to reduce abandonment.
2. **Payment Failures**: Provide clear error messages and alternative payment options.
3. **Recurring Donation Management**: Make it easy for donors to update or cancel recurring donations.
4. **International Donations**: Handle different currencies and international payment methods.
5. **Tax Compliance**: Ensure tax receipts comply with local regulations.
6. **Donor Communication**: Balance thanking donors without overwhelming them with emails.
