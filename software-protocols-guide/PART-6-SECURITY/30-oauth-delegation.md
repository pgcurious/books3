# Chapter 30: OAuth—Delegated Authorization

## Granting Access Without Sharing Passwords

---

> *"OAuth is about authorization, not authentication. People confuse these constantly."*
> — OAuth Working Group

---

## The Frustration

It's 2006. You're building an app that needs to access a user's Twitter posts. The only way?

```
User: "Here's my Twitter password"
App:  [Stores password, logs in as user]

Problems:
1. User trusts you with full account access
2. You store their password (security risk)
3. User can't revoke access without changing password
4. If you're compromised, their Twitter is compromised
```

This password-sharing pattern was everywhere: photo printing services asked for your Flickr password, email importers asked for your Gmail password.

## The World Before OAuth

Authorization meant password sharing:

```
"Give us your bank password to analyze your spending"
"Give us your email password to find your contacts"

Users either:
- Refused (missed features)
- Shared passwords (security nightmare)
```

There was no standard way to grant limited access.

## The Insight: Delegated Authorization

OAuth introduced delegated, scoped access:

```
App: "I need to read your Twitter posts"
User: [Redirected to Twitter]
Twitter: "This app wants to read your posts. Allow?"
User: "Yes"
Twitter: [Gives app a token with limited access]
App: [Uses token, never sees password]
```

Key innovations:
- User authorizes at the provider (Twitter), not the app
- App gets a token, not a password
- Scope limits what the token can do
- User can revoke anytime

## OAuth 2.0 Roles

### Resource Owner
The user who owns the data:
```
You own your Google Drive files.
```

### Client
The application requesting access:
```
The photo editor app that wants your Drive photos.
```

### Authorization Server
Issues tokens after user consent:
```
Google's OAuth server.
```

### Resource Server
Hosts the protected resources:
```
Google Drive API.
```

## The Authorization Code Flow

The most secure flow for web applications:

```
┌────────────────────────────────────────────────────────────────┐
│                                                                 │
│ 1. User clicks "Connect with Google"                           │
│                                                                 │
│ 2. App redirects to Google:                                    │
│    https://accounts.google.com/authorize?                      │
│      client_id=abc123&                                         │
│      redirect_uri=https://app.com/callback&                    │
│      scope=read:photos&                                        │
│      response_type=code&                                       │
│      state=xyz789                                              │
│                                                                 │
│ 3. User logs in to Google, sees consent screen                 │
│    "App wants to read your photos. Allow?"                     │
│                                                                 │
│ 4. User approves. Google redirects back:                       │
│    https://app.com/callback?code=AUTH_CODE&state=xyz789        │
│                                                                 │
│ 5. App exchanges code for tokens (server-to-server):           │
│    POST https://oauth.googleapis.com/token                     │
│      grant_type=authorization_code&                            │
│      code=AUTH_CODE&                                           │
│      client_id=abc123&                                         │
│      client_secret=SECRET                                      │
│                                                                 │
│ 6. Google returns:                                             │
│    {"access_token": "TOKEN", "refresh_token": "REFRESH"}       │
│                                                                 │
│ 7. App uses access_token to call Google Photos API             │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Why the Code Exchange?

The authorization code is exchanged for tokens server-to-server:

```
Authorization code: Visible in URL (less secure)
Access token:       Exchanged privately (more secure)

The exchange uses client_secret, proving the app's identity.
```

## Other OAuth Flows

### Implicit Flow (Deprecated)
For JavaScript apps without backends:

```
No code exchange—token returned directly in URL.
Problem: Token visible in browser history, URL.
Deprecated in favor of PKCE.
```

### Client Credentials
App authenticating as itself (no user):

```
POST /token
  grant_type=client_credentials&
  client_id=abc123&
  client_secret=SECRET

Used for server-to-server, no user context.
```

### PKCE (Proof Key for Code Exchange)
For mobile/SPA apps without client secrets:

```
1. App generates random code_verifier
2. Sends hash (code_challenge) in authorization request
3. Sends original code_verifier in token exchange
4. Server verifies: hash(code_verifier) == code_challenge

Prevents stolen authorization codes from being exchanged.
```

## Access Tokens and Refresh Tokens

### Access Token
Short-lived credential for API calls:

```
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6...

Typical lifetime: 1 hour
Include in every API request
```

### Refresh Token
Long-lived credential to get new access tokens:

```
POST /token
  grant_type=refresh_token&
  refresh_token=REFRESH_TOKEN&
  client_id=abc123

Returns new access_token (and possibly new refresh_token)
```

Why separate?
- Access tokens are used frequently, sent to many servers
- Refresh tokens are used rarely, sent only to auth server
- If access token is stolen, damage is time-limited

## Scopes

Limit what tokens can do:

```
scope=read:photos    → Can read photos
scope=write:photos   → Can read and write photos
scope=admin          → Full access

User sees: "App wants to read your photos"
```

Users can deny scopes. Apps should request minimum needed.

## OAuth is NOT Authentication

OAuth tells you: "This token can access these resources."

OAuth does NOT tell you: "Who is the user?"

```
OAuth token: "Can read photos"
But: Which user's photos? Who granted this?

For authentication (identity), use OpenID Connect (next chapter).
```

## OAuth Security Considerations

### State Parameter
Prevents CSRF attacks:

```
1. App generates random state=xyz789
2. Includes in authorization request
3. Verifies state in callback matches

Without state, attacker could inject their own authorization code.
```

### Redirect URI Validation
```
Register exact redirect URIs.
https://app.com/callback ✓
https://attacker.com/steal ✗

Open redirects are a major vulnerability class.
```

### Token Storage
```
Access tokens: Memory (not localStorage)
Refresh tokens: Secure HTTP-only cookies or secure storage
```

## Common OAuth Mistakes

### Mistake: Using Implicit Flow
```
Old: token directly in URL fragment
New: Authorization code + PKCE
```

### Mistake: Ignoring State Parameter
```
Without state: CSRF attacks possible
Always generate and verify state.
```

### Mistake: Over-Scoped Tokens
```
Bad:  scope=*  (everything)
Good: scope=read:profile (minimum needed)
```

### Mistake: Token in URL
```
GET /api?token=SECRET → Shows in logs, history
Authorization: Bearer SECRET → Header is better
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Delegation | No password sharing | Complexity |
| Tokens | Revocable, scoped | Token management |
| Refresh tokens | Short-lived access tokens | More moving parts |
| Scopes | Least privilege | User must understand |

## The Principle

> **OAuth solved the password anti-pattern by introducing delegated, scoped, revocable access tokens. Users authorize at the provider, apps get limited access, and no passwords are shared.**

OAuth is about authorization (what can you do?), not authentication (who are you?).

---

## Summary

- OAuth enables delegated authorization without password sharing
- Authorization Code flow is the standard for web apps
- PKCE extends security to mobile/SPA apps
- Access tokens are short-lived; refresh tokens renew them
- Scopes limit what tokens can do
- OAuth is for authorization, not authentication
- Always use state parameter to prevent CSRF

---

*Tokens need to be portable and verifiable. That's where JWT comes in.*
