# Chapter 32: SAML and OpenID Connect

## Federated Identity for Enterprises and the Web

---

> *"I don't want another password. Just let me sign in with my work account."*
> — Every enterprise user ever

---

## The Frustration

A company has 50 internal applications. Each has its own login:

```
App 1: username/password
App 2: username/password
App 3: username/password
...
App 50: username/password

Users: 50 passwords to manage
IT: 50 user databases to maintain
Security: 50 attack surfaces
```

When an employee leaves, IT must revoke access in 50 systems.

What if everyone could use ONE identity, managed in ONE place?

## The World Before Federation

Each application managed its own users:

```
HR System:    [User Database A]
Email:        [User Database B]
CRM:          [User Database C]
Intranet:     [User Database D]

Inconsistent passwords, roles, access.
Employee leaves → manual cleanup everywhere.
```

## The Insight: Centralized Identity Provider

Federation introduces a single source of truth:

```
Identity Provider (IdP): Manages users, credentials, attributes
Service Providers (SPs): Applications that trust the IdP

Employee logs into IdP ONCE.
All SPs accept that authentication.
```

## SAML: Enterprise Federation

SAML (Security Assertion Markup Language) was the enterprise answer (2002-2005).

### SAML Actors

**Identity Provider (IdP)**: Authenticates users (e.g., Okta, Azure AD, Ping Identity)

**Service Provider (SP)**: The application trusting the IdP

**User Agent**: The browser

### SAML Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User accesses SP (e.g., Salesforce)                          │
│                                                                 │
│ 2. SP doesn't know user. Redirects to IdP with SAML Request    │
│    (Where should I authenticate?)                              │
│                                                                 │
│ 3. User authenticates at IdP (company SSO)                      │
│    - Username/password                                          │
│    - MFA                                                        │
│    - Whatever IdP requires                                      │
│                                                                 │
│ 4. IdP sends SAML Response (assertion) back to SP               │
│    - Signed XML containing:                                     │
│      - Who the user is                                          │
│      - Their attributes (email, groups, roles)                  │
│      - Validity period                                          │
│                                                                 │
│ 5. SP validates signature, creates session                      │
│                                                                 │
│ 6. User is logged in!                                           │
└─────────────────────────────────────────────────────────────────┘
```

### SAML Assertion

```xml
<saml:Assertion>
    <saml:Issuer>https://idp.company.com</saml:Issuer>

    <saml:Subject>
        <saml:NameID>alice@company.com</saml:NameID>
    </saml:Subject>

    <saml:Conditions NotBefore="..." NotOnOrAfter="...">
        <saml:AudienceRestriction>
            <saml:Audience>https://salesforce.com</saml:Audience>
        </saml:AudienceRestriction>
    </saml:Conditions>

    <saml:AuthnStatement AuthnInstant="...">
        <!-- How the user authenticated -->
    </saml:AuthnStatement>

    <saml:AttributeStatement>
        <saml:Attribute Name="email">
            <saml:AttributeValue>alice@company.com</saml:AttributeValue>
        </saml:Attribute>
        <saml:Attribute Name="groups">
            <saml:AttributeValue>sales</saml:AttributeValue>
            <saml:AttributeValue>managers</saml:AttributeValue>
        </saml:Attribute>
    </saml:AttributeStatement>

    <ds:Signature>...</ds:Signature>
</saml:Assertion>
```

### Why SAML is Verbose

SAML predates JSON's popularity. It's XML-based, designed for enterprise security requirements:

- Extensive namespacing
- Multiple signature options
- Complex attribute statements

Powerful, but heavy.

## OpenID Connect: Modern Web Federation

OpenID Connect (OIDC) is the modern alternative, built on OAuth 2.0.

### OIDC = OAuth 2.0 + Identity

```
OAuth 2.0:          Authorization (what can you access?)
OpenID Connect:     + Authentication (who are you?)
```

OIDC adds an ID Token to OAuth:

```
OAuth response:
{
    "access_token": "..."
}

OIDC response:
{
    "access_token": "...",
    "id_token": "eyJhbGciOiJS..."  // JWT with identity claims
}
```

### OIDC Flow

```
1. App redirects to IdP with scope=openid
   GET /authorize?client_id=...&scope=openid email profile&...

2. User authenticates at IdP

3. IdP returns authorization code

4. App exchanges code for tokens:
   {
       "access_token": "...",      // For API access
       "id_token": "...",          // JWT with identity
       "refresh_token": "..."
   }

5. App validates id_token, extracts user info
```

### ID Token Claims

```json
{
    "iss": "https://accounts.google.com",
    "sub": "1234567890",
    "aud": "your-app-client-id",
    "exp": 1516242622,
    "iat": 1516239022,
    "email": "alice@gmail.com",
    "email_verified": true,
    "name": "Alice Smith",
    "picture": "https://..."
}
```

Standard claims. Additional claims via UserInfo endpoint.

### UserInfo Endpoint

For more user details:

```
GET /userinfo
Authorization: Bearer access_token

{
    "sub": "1234567890",
    "name": "Alice Smith",
    "email": "alice@gmail.com",
    "phone_number": "+1-555-123-4567",
    ...
}
```

## SAML vs OpenID Connect

| Aspect | SAML | OpenID Connect |
|--------|------|----------------|
| Format | XML | JSON/JWT |
| Transport | Browser redirects/POST | OAuth 2.0 flows |
| Token type | SAML Assertion | ID Token (JWT) |
| Mobile support | Poor | Excellent |
| Complexity | High | Medium |
| Adoption | Enterprise legacy | Modern web/mobile |
| Age | 2005 | 2014 |

### When to Use SAML

- Enterprise environments
- Existing SAML infrastructure
- Regulatory requirements specifying SAML
- Integration with legacy systems

### When to Use OIDC

- New applications
- Mobile applications
- Consumer-facing identity
- Modern infrastructure

## Discovery: How Do Apps Find IdPs?

### SAML Metadata

```xml
<!-- IdP publishes metadata -->
<EntityDescriptor entityID="https://idp.company.com">
    <IDPSSODescriptor>
        <KeyDescriptor>
            <ds:KeyInfo>...</ds:KeyInfo>  <!-- Signing certificate -->
        </KeyDescriptor>
        <SingleSignOnService Location="https://idp.company.com/sso"/>
    </IDPSSODescriptor>
</EntityDescriptor>
```

### OIDC Discovery

```
GET /.well-known/openid-configuration

{
    "issuer": "https://accounts.google.com",
    "authorization_endpoint": "https://accounts.google.com/o/oauth2/v2/auth",
    "token_endpoint": "https://oauth2.googleapis.com/token",
    "userinfo_endpoint": "https://openidconnect.googleapis.com/v1/userinfo",
    "jwks_uri": "https://www.googleapis.com/oauth2/v3/certs"
}
```

Standard endpoints. Auto-configuration possible.

## Single Sign-On (SSO) and Single Logout (SLO)

### SSO

```
Login to App A → Session at IdP created
Access App B → IdP session exists, no re-auth needed
Access App C → Same, instant access

One login, access to all.
```

### SLO (Single Logout)

```
Logout from App A → IdP notifies all SPs → All sessions terminated

Harder to implement. Often optional.
SAML has better SLO support than OIDC.
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Centralized IdP | Single user management | IdP is critical |
| Federation | No password sharing | Protocol complexity |
| SAML (XML) | Enterprise features | Simplicity |
| OIDC (JSON) | Modern, mobile-friendly | Some enterprise features |

## The Principle

> **SAML and OpenID Connect both solve federated identity—letting users authenticate once to access many applications. SAML came from enterprise XML culture; OIDC modernized federation with OAuth and JSON.**

Choose SAML for enterprise legacy integration. Choose OIDC for modern applications.

---

## Summary

- Federation centralizes identity management
- SAML: XML-based, enterprise-focused, powerful but verbose
- OpenID Connect: JSON/JWT-based, built on OAuth 2.0, modern
- Both enable SSO across applications
- SAML for enterprise legacy; OIDC for modern web/mobile
- Discovery protocols enable auto-configuration

---

*We've covered how to secure communication and identity. Now let's look at how applications talk to databases.*
