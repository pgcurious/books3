# Chapter 20: Authentication & Authorization (AuthN & AuthZ)

> *"Trust, but verify."*
> — Russian proverb (and the core principle of security)

---

## The Fundamental Problem

### Why Does This Exist?

You've built a beautiful application. Users can view their data, make purchases, send messages. Then someone realizes:

- Anyone can access anyone else's profile by guessing URLs
- The admin panel is protected by... nothing
- Deleted users can still use their old API keys
- An employee quit but still has access to production systems

Security wasn't an afterthought—it was a never-thought.

Two fundamental questions every system must answer:
1. **Who are you?** (Authentication)
2. **What are you allowed to do?** (Authorization)

The raw, primitive problem is this: **How do you verify identity and control access in a system where anyone can send requests claiming to be anyone?**

### The Real-World Analogy

Consider entering a secure building.

**Authentication**: You show your ID badge at the entrance. The guard checks if you're who you claim to be (face matches photo, badge is valid). This proves your identity.

**Authorization**: Your badge grants access to certain floors. You can enter floors 1-3, but not the executive suite on floor 10. Same building, same badge, different access levels.

The badge is your token. The card reader authenticates it. The access control list authorizes specific doors.

---

## The Naive Solution

### What Would a Beginner Try First?

"Store username and password, check on every request!"

```java
// DON'T DO THIS
public boolean authenticate(String username, String password) {
    User user = database.findByUsername(username);
    return user.password.equals(password);  // Plaintext comparison
}
```

### Why Does It Break Down?

**1. Plaintext passwords**

Storing passwords as-is means a database breach exposes every password. Users reuse passwords—you've compromised their bank accounts too.

**2. Passing credentials with every request**

Every API call sends username/password. More transmission = more chances for interception.

**3. No session management**

User logs in but you don't remember. They re-authenticate every request. Slow and bad UX.

**4. No revocation**

Once a password works, it works until changed. No way to say "log out all sessions" or "this session is compromised."

**5. No granularity**

Either you're authenticated or you're not. No concept of "can read but not write" or "can access their own data but not others'."

### The Flawed Assumption

The naive approach assumes **identity is binary and permissions are implicit**. Real systems need stateful sessions, granular permissions, and defense in depth.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **Authentication establishes trust; authorization enforces boundaries. They're related but distinct problems requiring distinct solutions.**

**Authentication** answers: "Are you really Alice?"
- Verify credentials (password, biometrics, keys)
- Issue a token proving verification happened

**Authorization** answers: "Can Alice do this action?"
- Check Alice's roles/permissions
- Evaluate against access control policies
- Allow or deny the specific action

### The Trade-off Acceptance

Security systems accept:
- **User friction**: Extra login steps, password requirements
- **Complexity**: Multiple systems, protocols, token management
- **Performance overhead**: Every request needs authorization checks
- **Operational burden**: Key rotation, audit logs, compliance

We accept these because the alternative—unauthorized access—is worse.

### The Sticky Metaphor

**Authentication is like checking into a hotel. Authorization is like your room key.**

You show ID at check-in (authentication). The hotel gives you a key card (token). That card opens your room, the gym, and the pool (authorization). It doesn't open other guests' rooms or the manager's office.

The key card proves you authenticated. The access programmed into it authorizes specific doors.

---

## The Mechanism

### Password Authentication (Done Right)

```java
public class SecurePasswordService {
    // Password hashing with bcrypt
    public String hashPassword(String plainPassword) {
        // BCrypt: slow hash + random salt + configurable work factor
        return BCrypt.hashpw(plainPassword, BCrypt.gensalt(12));
    }

    public boolean verifyPassword(String plainPassword, String hashedPassword) {
        // BCrypt.checkpw handles timing-attack-safe comparison
        return BCrypt.checkpw(plainPassword, hashedPassword);
    }
}

// Storage
// NEVER store: password = "alice123"
// ALWAYS store: password_hash = "$2a$12$LQv3c1y..."
```

**Why BCrypt?**

- **Slow**: Takes ~100ms to compute (attacker can't try billions of guesses)
- **Salted**: Each password has a unique salt (rainbow tables don't work)
- **Configurable**: Increase work factor as hardware improves

### Session-Based Authentication

```java
public class SessionAuthService {
    private final Map<String, Session> sessions = new ConcurrentHashMap<>();

    public String login(String username, String password) {
        User user = userRepository.findByUsername(username);

        if (user == null || !passwordService.verify(password, user.getPasswordHash())) {
            throw new AuthenticationException("Invalid credentials");
        }

        // Create session
        String sessionId = generateSecureRandom();
        Session session = new Session(user.getId(), Instant.now().plus(Duration.ofHours(24)));
        sessions.put(sessionId, session);

        return sessionId;  // Client stores this as cookie
    }

    public User authenticate(String sessionId) {
        Session session = sessions.get(sessionId);

        if (session == null || session.isExpired()) {
            throw new AuthenticationException("Invalid session");
        }

        return userRepository.findById(session.getUserId());
    }

    public void logout(String sessionId) {
        sessions.remove(sessionId);
    }
}
```

### Token-Based Authentication (JWT)

Stateless tokens that contain claims:

```java
public class JWTAuthService {
    private final String secretKey;

    public String createToken(User user) {
        return Jwts.builder()
            .setSubject(user.getId())
            .claim("roles", user.getRoles())
            .setIssuedAt(new Date())
            .setExpiration(Date.from(Instant.now().plus(Duration.ofHours(24))))
            .signWith(Keys.hmacShaKeyFor(secretKey.getBytes()), SignatureAlgorithm.HS256)
            .compact();
    }

    public Claims validateToken(String token) {
        try {
            return Jwts.parserBuilder()
                .setSigningKey(Keys.hmacShaKeyFor(secretKey.getBytes()))
                .build()
                .parseClaimsJws(token)
                .getBody();
        } catch (JwtException e) {
            throw new AuthenticationException("Invalid token");
        }
    }
}

// JWT structure:
// Header.Payload.Signature
// eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzIiwicm9sZXMiOlsiYWRtaW4iXX0.signature

// Payload (base64 decoded):
// {"sub":"user123","roles":["admin"],"exp":1705312800}
```

**Session vs. JWT:**

| Aspect | Session | JWT |
|--------|---------|-----|
| State | Server stores sessions | Stateless (info in token) |
| Scalability | Need shared session store | Any server can validate |
| Revocation | Easy (delete session) | Hard (token valid until expiry) |
| Size | Small ID | Larger (contains claims) |

### OAuth 2.0 and OpenID Connect

For "Login with Google/GitHub":

```
┌────────┐                              ┌─────────────┐
│  User  │                              │ Your App    │
└───┬────┘                              └──────┬──────┘
    │  1. Click "Login with Google"           │
    │  ─────────────────────────────────────► │
    │                                         │
    │  2. Redirect to Google                  │
    │  ◄───────────────────────────────────── │
    │                                         │
    │         ┌──────────────────┐            │
    │         │      Google      │            │
    │  ──────►│  (Auth Server)   │            │
    │         └────────┬─────────┘            │
    │                  │                      │
    │  3. Login at Google                     │
    │  4. Approve permissions                 │
    │                  │                      │
    │  5. Redirect back with auth code        │
    │  ◄───────────────┘                      │
    │  ─────────────────────────────────────► │
    │                                         │
    │         6. Exchange code for tokens     │
    │         (Your App → Google)             │
    │                                         │
    │         7. Get user info                │
    │         (Your App → Google)             │
    │                                         │
    │  8. Create session/JWT                  │
    │  ◄───────────────────────────────────── │
    │     User is now logged in               │
    │                                         │
```

### Authorization Models

**Role-Based Access Control (RBAC)**

```java
public enum Role {
    USER, EDITOR, ADMIN
}

public class RBACAuthorization {
    private final Map<Role, Set<Permission>> rolePermissions = Map.of(
        Role.USER, Set.of(Permission.READ_OWN_DATA),
        Role.EDITOR, Set.of(Permission.READ_OWN_DATA, Permission.EDIT_CONTENT),
        Role.ADMIN, Set.of(Permission.READ_ALL, Permission.EDIT_ALL, Permission.DELETE_ALL)
    );

    public boolean authorize(User user, Permission permission) {
        return user.getRoles().stream()
            .flatMap(role -> rolePermissions.get(role).stream())
            .anyMatch(p -> p == permission);
    }
}
```

**Attribute-Based Access Control (ABAC)**

```java
public class ABACAuthorization {
    // Policy: Users can edit documents they own OR are in the same department
    public boolean canEditDocument(User user, Document document) {
        // Check ownership
        if (document.getOwnerId().equals(user.getId())) {
            return true;
        }

        // Check department
        if (document.getDepartment().equals(user.getDepartment())) {
            return true;
        }

        // Check explicit share
        if (document.getSharedWith().contains(user.getId())) {
            return true;
        }

        return false;
    }
}
```

### Multi-Factor Authentication (MFA)

Something you know + something you have + something you are:

```java
public class MFAService {
    public LoginResult loginWithMFA(String username, String password, String totpCode) {
        // Factor 1: Password (something you know)
        User user = validatePassword(username, password);

        // Factor 2: TOTP code (something you have - phone)
        if (!validateTOTP(user.getTotpSecret(), totpCode)) {
            throw new AuthenticationException("Invalid MFA code");
        }

        return createSession(user);
    }

    private boolean validateTOTP(String secret, String code) {
        // TOTP: Time-based One-Time Password
        // Changes every 30 seconds, based on shared secret
        GoogleAuthenticator gAuth = new GoogleAuthenticator();
        return gAuth.authorize(secret, Integer.parseInt(code));
    }
}
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. User experience**

More security = more friction. Password requirements, MFA steps, session timeouts.

**2. Complexity**

OAuth flows, token management, key rotation—significant engineering investment.

**3. Performance**

Every request needs auth checks. JWT validation, permission lookups add latency.

**4. Recovery challenges**

Lost MFA device? Forgotten password? Account recovery is hard without weakening security.

### Security vs. Convenience Spectrum

```
←── More Secure                       More Convenient ──→
|                                                       |
MFA required    MFA optional    Password only    No auth
for everything  for sensitive   everywhere       public
```

Choose based on what you're protecting.

### Connection to Other Concepts

- **API Gateway** (Chapter 9): Often handles authentication centrally
- **Microservices** (Chapter 10): Service-to-service authentication
- **Rate Limiting** (Chapter 8): Authenticated users get higher limits
- **Monitoring** (Chapter 19): Audit logs for security events

---

## The Evolution

### Brief History

**1960s**: Passwords invented at MIT
**1990s**: SSL/TLS for encrypted transport
**2000s**: OAuth emerges (Twitter, 2007)
**2010s**: OAuth 2.0, OpenID Connect, JWT proliferation
**2020s**: Passwordless, passkeys, zero-trust architecture

### Modern Trends

**Passwordless Authentication**

- Magic links (email)
- Passkeys (WebAuthn/FIDO2)
- Biometrics

**Zero Trust Architecture**

"Never trust, always verify"—even inside the network.

```java
// Zero trust: verify every request, even internal
@PreAuthorize("hasPermission(#resourceId, 'read')")
public Resource getResource(String resourceId) {
    // Even authenticated users need permission checked per-request
}
```

### Where It's Heading

**Passkeys replacing passwords**: Platform-stored credentials, biometric unlock.

**Continuous authentication**: Not just "authenticated at login" but "authenticated now" based on behavior.

**Decentralized identity**: User-controlled identity rather than platform-controlled.

---

## Interview Lens

### Common Interview Questions

1. **"How would you design user authentication?"**
   - Password hashing (bcrypt/argon2)
   - Session or JWT-based
   - MFA for sensitive operations
   - OAuth for social login

2. **"Explain the difference between authentication and authorization"**
   - AuthN: Who are you? (identity verification)
   - AuthZ: What can you do? (permission checking)
   - Different solutions (tokens vs. RBAC/ABAC)

3. **"How do you secure microservices communication?"**
   - Service-to-service tokens (JWT)
   - Mutual TLS (mTLS)
   - API keys with scopes

### Red Flags (Shallow Understanding)

❌ "Store passwords in the database"

❌ Doesn't distinguish authentication from authorization

❌ Can't explain JWT structure or security

❌ No awareness of OAuth/OIDC

### How to Demonstrate Deep Understanding

✅ Explain password hashing (bcrypt, salt, work factor)

✅ Compare session vs. token-based auth trade-offs

✅ Discuss RBAC vs. ABAC for authorization

✅ Know OAuth 2.0 flows

✅ Mention security best practices (MFA, secure cookies, HTTPS)

---

## Summary

**The Problem**: Systems must verify who users are (authentication) and what they're allowed to do (authorization). Without this, anyone can access anything.

**The Insight**: Authentication and authorization are distinct problems. Authentication issues tokens proving identity; authorization evaluates permissions per-action.

**The Mechanism**: Password hashing for credential storage, sessions or JWTs for stateful/stateless auth, RBAC/ABAC for authorization, OAuth for federated identity.

**The Trade-off**: User friction and implementation complexity for security and access control.

**The Evolution**: From passwords → sessions → tokens → OAuth → passwordless. Security evolves as threats evolve.

**The First Principle**: Trust no one by default. Verify identity, check permissions, log everything. Security is not a feature—it's a requirement.

---

*Next: We conclude with Part 7—synthesizing everything we've learned. [Connecting the Dots](../PART-7-SYNTHESIS/connecting-the-dots.md)*
