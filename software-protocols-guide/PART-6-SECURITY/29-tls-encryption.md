# Chapter 29: TLS/SSL—Encrypted Channels

## Protecting Data in Transit

---

> *"HTTPS is not just for banks anymore. It's for everything."*
> — Security community consensus, 2010s

---

## The Frustration

You're building a web application. Users send passwords, credit cards, personal data. But HTTP is plaintext:

```
POST /login HTTP/1.1
Host: example.com

username=alice&password=secret123
```

Anyone on the network path can read this:
- Your ISP
- The coffee shop WiFi
- Any compromised router
- Government surveillance

You need encryption. But encryption alone isn't enough—you also need to verify you're talking to the right server.

## The World Before TLS

Early encryption attempts were fragmented:

- **S-HTTP**: Encrypted HTTP (lost to HTTPS)
- **PCT**: Microsoft's alternative to SSL (abandoned)
- **Custom encryption**: Per-application, often flawed

SSL (Secure Sockets Layer) emerged from Netscape in 1995. TLS (Transport Layer Security) is its successor and modern name.

## What TLS Provides

### 1. Confidentiality
Data encrypted; eavesdroppers see gibberish:

```
Without TLS: password=secret123
With TLS:    7a9f3b2c1d4e5f6a...
```

### 2. Integrity
Data cannot be modified in transit:

```
Without TLS: Attacker changes "Transfer $100" to "$10000"
With TLS:    Modifications detected, connection aborted
```

### 3. Authentication
Verify the server (and optionally client) identity:

```
Without TLS: Am I talking to my bank or an impersonator?
With TLS:    Certificate proves it's really my bank
```

## The TLS Handshake

Before encrypted data flows, TLS establishes a secure connection:

### TLS 1.2 Handshake (Traditional)

```
Client                                     Server
   |                                          |
   |------ ClientHello ---------------------->|
   |        (supported ciphers, random)       |
   |                                          |
   |<----- ServerHello -----------------------|
   |        (chosen cipher, random)           |
   |<----- Certificate -----------------------|
   |        (server's identity proof)         |
   |<----- ServerHelloDone -------------------|
   |                                          |
   |------ ClientKeyExchange ---------------->|
   |        (key material)                    |
   |------ ChangeCipherSpec ----------------->|
   |------ Finished ------------------------->|
   |                                          |
   |<----- ChangeCipherSpec ------------------|
   |<----- Finished --------------------------|
   |                                          |
   |========= Encrypted Data ================|
```

2 round trips before data flows.

### TLS 1.3 Handshake (Modern)

```
Client                                     Server
   |                                          |
   |------ ClientHello ---------------------->|
   |        + key_share (DH public key)       |
   |                                          |
   |<----- ServerHello -----------------------|
   |        + key_share                       |
   |<----- {EncryptedExtensions} -------------|
   |<----- {Certificate} ---------------------|
   |<----- {CertificateVerify} ---------------|
   |<----- {Finished} ------------------------|
   |                                          |
   |------ {Finished} ----------------------->|
   |                                          |
   |========= Encrypted Data ================|
```

1 round trip! TLS 1.3 removed obsolete features and optimized the handshake.

### 0-RTT Resumption

For returning clients:

```
Client                                     Server
   |                                          |
   |------ ClientHello + early_data --------->|
   |        (encrypted with previous session) |
   |                                          |
   |<----- ServerHello + data ----------------|
   |                                          |
```

Data flows immediately. But 0-RTT has replay risks—use carefully.

## Certificates and Trust

### The Problem

How do you know the server is legitimate?

```
You connect to https://bank.com
Someone intercepts, presents their own certificate
How do you know it's fake?
```

### Certificate Authorities (CAs)

A trusted third party vouches for identity:

```
1. Bank proves to CA they own bank.com
2. CA signs bank.com's certificate
3. Your browser trusts the CA
4. Browser trusts bank.com's certificate

Chain of trust:
   Root CA (in your browser)
        ↓ signed
   Intermediate CA
        ↓ signed
   bank.com certificate
```

### What a Certificate Contains

```
Subject: CN=bank.com
Issuer: CN=DigiCert TLS RSA SHA256 2020 CA1
Valid From: 2024-01-01
Valid Until: 2025-01-01
Public Key: (RSA 2048 bits)
Signature: (CA's signature proving authenticity)
```

### Certificate Validation

Browser checks:

1. Is the certificate unexpired?
2. Does the hostname match?
3. Is it signed by a trusted CA?
4. Is the CA's certificate valid?
5. Is the certificate revoked?

Any failure → warning or error.

## Cipher Suites

TLS negotiates algorithms:

```
TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384

ECDHE:   Key exchange (Elliptic Curve Diffie-Hellman Ephemeral)
RSA:     Authentication (server proves identity)
AES_256: Encryption (256-bit AES)
GCM:     Mode (Galois/Counter Mode)
SHA384:  Hash for integrity
```

TLS 1.3 simplified to fewer, stronger options:

```
TLS_AES_256_GCM_SHA384
TLS_CHACHA20_POLY1305_SHA256
```

No more weak ciphers to negotiate down to.

## Perfect Forward Secrecy

What if your private key is stolen?

**Without PFS:**
```
Attacker records encrypted traffic today
Key is stolen (or cracked) years later
Attacker decrypts all recorded traffic
```

**With PFS (using ECDHE):**
```
Each session uses ephemeral keys
Session keys deleted after connection
Key theft later doesn't help
Past traffic remains safe
```

TLS 1.3 requires forward secrecy.

## Common TLS Attacks (and Defenses)

### BEAST, POODLE, CRIME, BREACH
Historical attacks on older TLS versions. TLS 1.2+ with proper configuration is immune.

### Heartbleed
OpenSSL bug (2014) that leaked server memory. Fixed by patching OpenSSL—not a protocol flaw.

### Certificate Misissuance
CA issues certificate to wrong party. Defenses:
- Certificate Transparency logs
- DANE (DNS-based certificate authentication)
- HPKP (HTTP Public Key Pinning, now deprecated)

### Downgrade Attacks
TLS 1.3 protects against these by authenticating the handshake.

## Let's Encrypt and Free Certificates

Before 2015, certificates cost money. Let's Encrypt changed this:

```
Free certificates for everyone
Automated issuance and renewal
Helped HTTPS adoption explode
```

Now there's no excuse for unencrypted websites.

## TLS for Non-HTTP Protocols

TLS wraps many protocols:

```
HTTPS:   HTTP over TLS
SMTPS:   SMTP over TLS
IMAPS:   IMAP over TLS
FTPS:    FTP over TLS
LDAPS:   LDAP over TLS

Same TLS handshake, different application layer.
```

## STARTTLS vs Implicit TLS

**STARTTLS**: Start plain, upgrade to encrypted
```
Client: EHLO
Server: 250-STARTTLS
Client: STARTTLS
[TLS handshake]
[Encrypted SMTP]
```

**Implicit TLS**: TLS from the start
```
[TLS handshake on dedicated port]
[Encrypted SMTP]
```

Implicit is simpler; STARTTLS is vulnerable to downgrade attacks.

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| PKI/CAs | Scalable trust | CA vulnerabilities |
| Symmetric + Asymmetric | Performance | Complexity |
| TLS 1.3 | Speed, security | Compatibility |
| Free certs | Ubiquitous HTTPS | Phishing sites also use HTTPS |

## The Principle

> **TLS solved the problem of secure communication at scale by combining asymmetric cryptography (for key exchange and authentication) with symmetric cryptography (for fast encryption). The certificate authority system enables trust without prior relationship.**

TLS is imperfect (CA trust model has issues), but it's the foundation of internet security.

## Configuration Best Practices

```nginx
# Nginx example
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_prefer_server_ciphers on;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_stapling on;
ssl_stapling_verify on;
```

Test your configuration: https://www.ssllabs.com/ssltest/

---

## Summary

- TLS provides confidentiality, integrity, and authentication
- Certificate authorities enable scalable trust
- TLS 1.3 reduced handshake to 1 RTT
- Perfect forward secrecy protects against future key compromise
- Free certificates (Let's Encrypt) enabled ubiquitous HTTPS
- TLS wraps many protocols beyond HTTP

---

*TLS protects the channel. But who is allowed to do what? That's authorization—OAuth's domain.*
