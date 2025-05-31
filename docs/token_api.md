# Token Authentication API

This document provides comprehensive documentation for the token-based authentication system, including magic links, password reset, and verification tokens.

## Overview

The Token API provides a secure, unified system for handling various authentication flows:
- **Magic Links**: Passwordless authentication
- **Password Reset**: Secure password recovery
- **Email Verification**: Email address confirmation
- **Phone Verification**: Phone number confirmation

## Security Features

- **Hashed Storage**: All tokens are stored as secure hashes, never in plain text
- **Built-in Rate Limiting**: Attempt system prevents brute force attacks
- **Automatic Expiration**: Configurable token lifetimes
- **Guest Support**: Works for both authenticated users and guests
- **Audit Trail**: Complete logging of token usage

## API Endpoints

### 1. Create Magic Link

**Endpoint:** `POST /auth/magic-link`

**Description:** Creates a magic link for passwordless authentication.

**Request Body:**
```json
{
  "identifier": "samuel@gmail.com",
  "redirect_url": "https://app.example.com/dashboard", // Optional
  "expires_in": 900 // Optional, seconds (default: 15 minutes)
}
```

**Response:**
```json
{
  "success": true,
  "message": "Magic link sent successfully",
  "token_id": "tok_abc123...",
  "expires_at": "2024-01-15T10:30:00Z",
  "attempts_remaining": 4
}
```

**Example Usage:**
```bash
curl -X POST https://api.example.com/auth/magic-link \
  -H "Content-Type: application/json" \
  -d '{"identifier": "samuel@gmail.com"}'
```

### 2. Create Password Reset Token

**Endpoint:** `POST /auth/password-reset`

**Description:** Creates a token for password reset functionality.

**Request Body:**
```json
{
  "identifier": "samuel@gmail.com",
  "expires_in": 3600 // Optional, seconds (default: 1 hour)
}
```

**Response:**
```json
{
  "success": true,
  "message": "Password reset link sent successfully",
  "token_id": "tok_def456...",
  "expires_at": "2024-01-15T11:00:00Z",
  "attempts_remaining": 3
}
```

### 3. Verify Token

**Endpoint:** `POST /auth/verify`

**Description:** Validates and optionally consumes a token.

**Request Body:**
```json
{
  "token": "abc123def456...", // The actual token (not hashed)
  "consume": true, // Optional, default: false
  "action": "authenticate" // Optional, for logging purposes
}
```

**Response (Success):**
```json
{
  "success": true,
  "valid": true,
  "token_type": "magic_link",
  "type": "email",
  "identifier_value": "samuel@gmail.com",
  "user_id": "user_123", // null for guest tokens
  "consumed": true,
  "metadata": {
    "redirect_url": "https://app.example.com/dashboard"
  }
}
```

**Response (Invalid/Expired):**
```json
{
  "success": false,
  "valid": false,
  "error": "token_expired",
  "message": "Token has expired",
  "attempts_remaining": 0
}
```

### 4. Create Email Verification Token

**Endpoint:** `POST /auth/email-verification`

**Description:** Creates a token for email address verification.

**Request Body:**
```json
{
  "identifier": "samuel@gmail.com",
  "user_id": "user_123", // Optional, for registered users
  "expires_in": 1800 // Optional, seconds (default: 30 minutes)
}
```

**Response:**
```json
{
  "success": true,
  "message": "Verification email sent successfully",
  "token_id": "tok_ghi789...",
  "expires_at": "2024-01-15T10:45:00Z",
  "attempts_remaining": 5
}
```

### 5. Revoke Token

**Endpoint:** `DELETE /auth/tokens/{token_id}`

**Description:** Revokes an active token before expiration.

**Response:**
```json
{
  "success": true,
  "message": "Token revoked successfully",
  "revoked_at": "2024-01-15T10:15:00Z"
}
```

### 6. Get Token Status

**Endpoint:** `GET /auth/tokens/{token_id}/status`

**Description:** Check the current status of a token without consuming it.

**Response:**
```json
{
  "success": true,
  "token_id": "tok_abc123...",
  "status": "active",
  "token_type": "magic_link",
  "expires_at": "2024-01-15T10:30:00Z",
  "attempts_remaining": 3,
  "created_at": "2024-01-15T10:15:00Z"
}
```

## Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `token_not_found` | Token does not exist | 404 |
| `token_expired` | Token has expired | 400 |
| `token_consumed` | Token already used | 400 |
| `token_revoked` | Token was revoked | 400 |
| `attempts_exceeded` | Too many failed attempts | 429 |
| `invalid_identifier` | Invalid email/phone/username | 400 |
| `rate_limit_exceeded` | Too many requests | 429 |

## Implementation Examples

### Backend Token Creation

```javascript
// Create and hash token
import crypto from 'crypto';

function createToken(identifierType, identifierValue, tokenType, userId = null) {
  // Generate secure random token
  const rawToken = crypto.randomBytes(32).toString('hex');

  // Hash token for storage
  const hashedToken = crypto.createHash('sha256')
    .update(rawToken + process.env.TOKEN_SALT)
    .digest('hex');

  // Calculate expiration
  const expiresAt = new Date();
  expiresAt.setMinutes(expiresAt.getMinutes() + 15); // 15 minutes

  // Store in database
  const tokenRecord = {
    id: generateId(),
    token: hashedToken,
    type: identifierType,
    identifier_value: identifierValue,
    token_type: tokenType,
    user_id: userId,
    attempts_remaining: 4,
    status: 'active',
    expires_at: expiresAt,
    created_at: new Date()
  };

  // Return raw token to send to user (never store this)
  return { tokenRecord, rawToken };
}
```

### Token Validation

```javascript
function validateToken(rawToken, consume = false) {
  // Hash the provided token
  const hashedToken = crypto.createHash('sha256')
    .update(rawToken + process.env.TOKEN_SALT)
    .digest('hex');

  // Find token in database
  const token = findTokenByHash(hashedToken);

  if (!token) {
    return { valid: false, error: 'token_not_found' };
  }

  // Check expiration
  if (new Date() > token.expires_at) {
    updateTokenStatus(token.id, 'expired');
    return { valid: false, error: 'token_expired' };
  }

  // Check status
  if (token.status !== 'active') {
    return { valid: false, error: `token_${token.status}` };
  }

  // Check attempts
  if (token.attempts_remaining <= 0) {
    return { valid: false, error: 'attempts_exceeded' };
  }

  // Consume token if requested
  if (consume) {
    updateTokenStatus(token.id, 'consumed', { consumed_at: new Date() });
  }

  return {
    valid: true,
    token: token,
    user_id: token.user_id,
    identifier: token.identifier_value
  };
}
```

## Configuration

### Environment Variables

```bash
# Token security
TOKEN_SALT=your-secure-random-salt-here
TOKEN_DEFAULT_EXPIRY_MINUTES=15

# Rate limiting
TOKEN_MAX_ATTEMPTS=4
TOKEN_CLEANUP_INTERVAL_HOURS=24

# Email settings (for magic links)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=noreply@example.com
SMTP_PASS=your-smtp-password
```

### Default Expiration Times

- **Magic Links**: 15 minutes
- **Password Reset**: 1 hour
- **Email Verification**: 30 minutes
- **Phone Verification**: 10 minutes

## Best Practices

1. **Always Hash Tokens**: Never store raw tokens in the database
2. **Use HTTPS**: All token endpoints must use secure connections
3. **Set Appropriate Expiry**: Short-lived tokens are more secure
4. **Implement Cleanup**: Regularly remove expired tokens
5. **Log Usage**: Track token creation and consumption for security
6. **Rate Limiting**: Implement additional rate limiting at the API level
7. **Validate Input**: Always validate identifier formats
8. **Secure Transport**: Use secure email/SMS providers for token delivery

## Rate Limiting Strategy

The token system includes built-in rate limiting through the `attempts_remaining` field, but additional API-level rate limiting is recommended:

- **Token Creation**: 5 requests per minute per IP
- **Token Verification**: 10 requests per minute per IP
- **Global Limits**: 1000 tokens per hour per identifier

## Monitoring and Alerts

Monitor these metrics for security and performance:

- Token creation rate
- Failed verification attempts
- Expired token cleanup frequency
- Average token consumption time
- Suspicious patterns (multiple failed attempts)

## Database Cleanup

### Automatic Cleanup Script

```sql
-- Clean up expired tokens (run daily)
DELETE FROM tokens
WHERE expires_at < NOW()
AND status IN ('expired', 'consumed');

-- Clean up old revoked tokens (run weekly)
DELETE FROM tokens
WHERE status = 'revoked'
AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY);
```

### Cleanup API Endpoint

**Endpoint:** `POST /auth/cleanup`

**Description:** Manually trigger token cleanup (admin only).

**Response:**
```json
{
  "success": true,
  "cleaned_tokens": 1247,
  "cleanup_time": "2024-01-15T10:15:00Z"
}
```

## Integration Examples

### Frontend Magic Link Flow

```javascript
// 1. Request magic link
async function requestMagicLink(email) {
  const response = await fetch('/auth/magic-link', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      identifier: email,
      redirect_url: window.location.origin + '/dashboard'
    })
  });

  const result = await response.json();
  if (result.success) {
    showMessage('Magic link sent! Check your email.');
  }
}

// 2. Verify token from URL
async function verifyMagicLink() {
  const urlParams = new URLSearchParams(window.location.search);
  const token = urlParams.get('token');

  if (!token) return;

  const response = await fetch('/auth/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      token: token,
      consume: true,
      action: 'authenticate'
    })
  });

  const result = await response.json();
  if (result.success && result.valid) {
    // Store session or redirect
    localStorage.setItem('user_id', result.user_id);
    window.location.href = '/dashboard';
  } else {
    showError('Invalid or expired magic link');
  }
}
```

### Email Template Examples

#### Magic Link Email

```html
<!DOCTYPE html>
<html>
<head>
  <title>Your Magic Link</title>
</head>
<body>
  <h2>Sign in to Your Account</h2>
  <p>Click the button below to sign in securely:</p>

  <a href="{{magic_link_url}}"
     style="background: #007bff; color: white; padding: 12px 24px;
            text-decoration: none; border-radius: 4px; display: inline-block;">
    Sign In Securely
  </a>

  <p>This link will expire in 15 minutes for your security.</p>
  <p>If you didn't request this, please ignore this email.</p>

  <small>
    Or copy and paste this URL: {{magic_link_url}}
  </small>
</body>
</html>
```

#### Password Reset Email

```html
<!DOCTYPE html>
<html>
<head>
  <title>Reset Your Password</title>
</head>
<body>
  <h2>Password Reset Request</h2>
  <p>We received a request to reset your password.</p>

  <a href="{{reset_link_url}}"
     style="background: #dc3545; color: white; padding: 12px 24px;
            text-decoration: none; border-radius: 4px; display: inline-block;">
    Reset Password
  </a>

  <p>This link will expire in 1 hour for your security.</p>
  <p>If you didn't request this, please ignore this email.</p>
</body>
</html>
```

## Advanced Features

### Token Metadata Usage

```javascript
// Store additional context in token metadata
const tokenData = {
  identifier: 'samuel@gmail.com',
  metadata: {
    ip_address: req.ip,
    user_agent: req.headers['user-agent'],
    redirect_url: '/dashboard',
    source: 'mobile_app',
    campaign: 'welcome_series'
  }
};
```

### Multi-Factor Authentication

```javascript
// Create verification token for 2FA
async function createTwoFactorToken(userId, method = 'email') {
  const user = await getUserById(userId);
  const identifier = method === 'email' ? user.email : user.phone;

  return createToken(method, identifier, 'two_factor_verification', userId);
}
```

### Bulk Token Operations

**Endpoint:** `POST /auth/tokens/bulk-revoke`

**Description:** Revoke multiple tokens (useful for security incidents).

**Request Body:**
```json
{
  "user_id": "user_123", // Optional: revoke all tokens for user
  "token_type": "magic_link", // Optional: revoke specific type
  "reason": "security_incident"
}
```

## Troubleshooting

### Common Issues

1. **Token Not Found**
   - Check if token was properly hashed
   - Verify token hasn't been cleaned up
   - Ensure correct salt is being used

2. **Token Expired**
   - Check system clock synchronization
   - Verify expiration time calculation
   - Consider extending default expiry times

3. **Attempts Exceeded**
   - Implement proper error handling
   - Consider resetting attempts for legitimate users
   - Monitor for brute force attacks

4. **Email Delivery Issues**
   - Verify SMTP configuration
   - Check spam folders
   - Monitor email delivery rates

### Debug Queries

```sql
-- Find tokens for specific user
SELECT * FROM tokens
WHERE identifier_value = 'samuel@gmail.com'
ORDER BY created_at DESC;

-- Check token attempt patterns
SELECT identifier_value, COUNT(*) as failed_attempts
FROM tokens
WHERE status = 'active' AND attempts_remaining = 0
GROUP BY identifier_value
HAVING failed_attempts > 5;

-- Monitor token creation rate
SELECT DATE(created_at) as date,
       token_type,
       COUNT(*) as tokens_created
FROM tokens
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(created_at), token_type
ORDER BY date DESC;
```

## Security Considerations

### Token Generation
- Use cryptographically secure random number generators
- Minimum token length of 32 bytes (64 hex characters)
- Include sufficient entropy to prevent guessing attacks

### Storage Security
- Always hash tokens before database storage
- Use a unique salt for your application
- Consider using bcrypt or Argon2 for additional security

### Transport Security
- Always use HTTPS for token-related endpoints
- Implement proper CORS policies
- Use secure email/SMS providers for token delivery

### Monitoring
- Log all token creation and verification attempts
- Monitor for unusual patterns or high failure rates
- Implement alerting for potential security incidents
- Regular security audits of token usage patterns
