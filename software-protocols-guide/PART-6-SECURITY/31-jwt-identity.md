# Chapter 31: JWT—Portable Identity

## Self-Contained Tokens That Carry Their Own Proof

---

> *"JWT: the good, the bad, and the ugly. Know all three before using it."*
> — Security practitioners

---

## The Frustration

Traditional session tokens require server-side storage:

```
Session token: abc123
Server lookup: sessions[abc123] → {user_id: 42, name: "Alice", ...}

Every API server needs access to the session store.
Session store becomes a bottleneck and single point of failure.
```

In distributed systems with many services:

```
Service A → Session Store ← Service B
                ↑
            Service C

All services must connect to the same store.
Scaling is painful.
```

## The World Before JWT

Session management was centralized:

```
Options:
1. Sticky sessions (load balancer pins user to server)
   → Uneven load, failover problems

2. Shared session store (Redis, database)
   → Additional infrastructure, latency

3. Session in cookie
   → Cookie size limits, server-side data invisible
```

What if the token itself contained all needed information?

## The Insight: Self-Contained Tokens

JWT (JSON Web Token) embeds data in the token:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.
eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkFsaWNlIiwiaWF0IjoxNTE2MjM5MDIyfQ.
SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```

Three parts, base64-encoded, dot-separated:

### 1. Header
```json
{
    "alg": "HS256",
    "typ": "JWT"
}
```

### 2. Payload (Claims)
```json
{
    "sub": "1234567890",
    "name": "Alice",
    "iat": 1516239022,
    "exp": 1516242622
}
```

### 3. Signature
```
HMACSHA256(
    base64UrlEncode(header) + "." + base64UrlEncode(payload),
    secret
)
```

## How JWT Verification Works

```
1. Receive token
2. Split by dots: header.payload.signature
3. Recompute signature using secret
4. Compare: computed == received?
   Yes → Token is authentic and untampered
   No  → Reject
5. Check claims: Is it expired? Is issuer trusted?
6. Use the payload data
```

No database lookup required. The signature proves authenticity.

## JWT Claims

### Registered Claims (Standard)

```json
{
    "iss": "https://auth.example.com",  // Issuer
    "sub": "user123",                    // Subject (user ID)
    "aud": "api.example.com",            // Audience (intended recipient)
    "exp": 1516242622,                   // Expiration (Unix timestamp)
    "nbf": 1516239022,                   // Not Before
    "iat": 1516239022,                   // Issued At
    "jti": "unique-token-id"             // JWT ID (for revocation)
}
```

### Custom Claims

```json
{
    "name": "Alice",
    "email": "alice@example.com",
    "roles": ["admin", "user"],
    "tenant_id": "acme_corp"
}
```

Add what you need. But remember: payload is NOT encrypted.

## Signing Algorithms

### Symmetric (Shared Secret)

```
HS256, HS384, HS512

Same secret signs and verifies.
Simple, but secret must be shared with all verifiers.
```

### Asymmetric (Public/Private Keys)

```
RS256, RS384, RS512 (RSA)
ES256, ES384, ES512 (ECDSA)

Private key signs. Public key verifies.
Auth server keeps private key.
Services only need public key.
```

Asymmetric is preferred for distributed systems.

## JWT vs Session Tokens

| Aspect | JWT | Session Token |
|--------|-----|---------------|
| Storage | Client-side | Server-side |
| Server state | Stateless | Stateful |
| Scalability | Easy | Requires shared store |
| Revocation | Hard | Easy (delete from store) |
| Size | Larger | Small (just an ID) |
| Validation | Cryptographic | Database lookup |

## The JWT Controversy

JWT has vocal critics. Understand the issues:

### Problem 1: No Revocation

```
User logs out. JWT is still valid until expiration.
User is compromised. Can't invalidate existing tokens.

Mitigation:
- Short expiration times (15 min)
- Blacklist for critical revocations
- Refresh token rotation
```

### Problem 2: Algorithm Confusion

```
Attacker changes header:
{"alg": "HS256"} → {"alg": "none"}

Weak libraries might accept unsigned tokens!

Mitigation:
- Always specify expected algorithm
- Use well-maintained libraries
- Never accept "none" algorithm
```

### Problem 3: Payload is NOT Encrypted

```
base64Url is encoding, not encryption.
Anyone can decode the payload.

Don't put sensitive data in JWT!
```

### Problem 4: Token Size

```
Session ID: 32 bytes
JWT: 500+ bytes (grows with claims)

Sent with every request. Mobile data costs.
```

## When to Use JWT

**Good use cases:**
- Stateless authentication across services
- Short-lived access tokens (OAuth)
- Passing identity between microservices
- Single sign-on scenarios

**Bad use cases:**
- Storing sensitive data (not encrypted)
- Long-lived tokens (revocation problem)
- Replacing simple session cookies
- When you need immediate revocation

## JWT Best Practices

### 1. Short Expiration
```json
{
    "exp": 1516242622  // 15 minutes from now
}
```

### 2. Use Asymmetric Signing in Distributed Systems
```
Auth server: signs with private key
API servers: verify with public key
```

### 3. Validate Everything
```python
# Verify signature
# Check expiration
# Validate issuer
# Validate audience
# Check not-before
```

### 4. Don't Store Sensitive Data
```json
// Bad
{"ssn": "123-45-6789", "credit_card": "..."}

// Good
{"user_id": "123", "roles": ["user"]}
```

### 5. Use Standard Libraries
```
Don't implement JWT yourself.
jose, jsonwebtoken, PyJWT—use vetted libraries.
```

## JWS, JWE, and JWK

JWT is part of a family:

**JWS (JSON Web Signature)**: Signed tokens (what we've discussed)

**JWE (JSON Web Encryption)**: Encrypted tokens (payload is encrypted)

**JWK (JSON Web Key)**: Key format for sharing public keys

**JWKS (JSON Web Key Set)**: Endpoint providing multiple public keys

```
https://auth.example.com/.well-known/jwks.json

{
    "keys": [
        {"kty": "RSA", "n": "...", "e": "...", "kid": "key-1"},
        {"kty": "RSA", "n": "...", "e": "...", "kid": "key-2"}
    ]
}
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Self-contained | Stateless verification | Revocation difficulty |
| Signed (not encrypted) | Integrity | Confidentiality |
| Base64 encoding | URL-safe transport | Size inflation |
| Flexible claims | Customization | Potential misuse |

## The Principle

> **JWT solved the session store scalability problem by embedding claims in the token itself. Cryptographic signatures prove authenticity without server-side lookups. But this statelessness comes at the cost of revocation complexity.**

JWT is a tool. Use it for what it's good at (short-lived, stateless auth). Avoid it for what it's bad at (long-lived, revocable sessions).

---

## Summary

- JWT is a self-contained, signed token format
- Three parts: header, payload, signature
- Claims carry identity and authorization data
- Signature proves authenticity without database lookup
- Revocation is JWT's biggest weakness
- Use short expirations and asymmetric signing
- Payload is encoded, NOT encrypted

---

*For enterprise identity federation, SAML and OpenID Connect provide comprehensive solutions.*
