# Chapter 12: FTP/SFTP—Moving Files

## The Original File Sharing Protocol (And Why It's Problematic)

---

> *"FTP: It's not dead, it's just resting."*
> — Unknown Sysadmin

---

## The Frustration

It's 1971. You have a file on your computer. You want to copy it to another computer on the ARPANET. How?

You could log into the remote machine, navigate to the right directory, and copy the file there. But that requires an account on every machine. And managing directories manually is tedious.

People wanted a dedicated way to transfer files: browse remote directories, upload, download—without needing full shell access.

## The World Before FTP

File transfer was ad-hoc:

- **Remote login + copy**: Log in, navigate, copy
- **Tape exchange**: Physically mail magnetic tapes
- **Print and retype**: Seriously, this happened
- **Custom protocols**: Every system had its own approach

There was no standard way to say "give me that file" across different systems.

## The Insight: File-Centric Protocol

FTP (File Transfer Protocol), one of the oldest internet protocols (1971, standardized 1985), focused entirely on file operations:

```
Basic FTP commands:
USER username    - Identify yourself
PASS password    - Authenticate
CWD /path        - Change working directory
PWD              - Print working directory
LIST             - List files
RETR filename    - Retrieve (download) a file
STOR filename    - Store (upload) a file
DELE filename    - Delete a file
QUIT             - Disconnect
```

FTP abstracted the underlying file systems. The same commands worked whether the remote server was Unix, VMS, or anything else.

## FTP's Unusual Architecture

FTP uses two connections:

### Control Connection (Port 21)
Text-based commands and responses:

```
Client → Server: USER alice
Server → Client: 331 Password required
Client → Server: PASS secret
Server → Client: 230 User logged in
Client → Server: LIST
...
```

### Data Connection (Port 20 or dynamic)
Actual file content and directory listings.

Why two connections?

```
1971 reasoning:
- Keep commands responsive while large transfers happen
- Allow commands during transfers (abort, check status)
- Different handling for control (small, text) vs data (large, binary)
```

This made sense with 1971 constraints but causes problems today.

### Active vs Passive Mode

**Active mode** (original):
```
1. Client tells server: "Connect to me at IP:port"
2. Server initiates connection to client
3. Data flows

Problem: Firewalls block incoming connections to clients
```

**Passive mode** (PASV):
```
1. Client asks: "Enter passive mode"
2. Server: "Connect to me at IP:port"
3. Client initiates connection to server
4. Data flows

Works through firewalls (usually)
```

Passive mode is now standard, but you'll still encounter active mode issues.

## Why FTP is Problematic

FTP seemed reasonable in 1971. In 2024, it's a security concern:

### 1. Passwords in Plaintext

```
Client: USER alice
Client: PASS mysecretpassword

Anyone sniffing the network sees the password.
```

### 2. Data in Plaintext

Files transfer unencrypted. Sensitive documents are exposed.

### 3. Firewall Complexity

Two connections, dynamic ports, embedded IP addresses in commands—firewalls struggle:

```
Client behind NAT:
1. PASV
2. Server responds: "Connect to 10.0.0.1:12345"
3. 10.0.0.1 is the server's private IP
4. Client can't reach it
```

FTP embeds IP addresses in the application layer, breaking with NAT.

### 4. No Integrity Verification

Files might be corrupted in transit. FTP has no checksums.

## Securing File Transfer

### FTPS (FTP Secure)

Add TLS to FTP:

```
Implicit FTPS: TLS from the start (port 990)
Explicit FTPS: Start plain, upgrade with AUTH TLS command

Both control and data connections are encrypted.
```

Solves the encryption problem but keeps the two-connection complexity.

### SFTP (SSH File Transfer Protocol)

Not FTP at all—it's a subsystem of SSH:

```
Client: SSH to server, request SFTP subsystem
All file operations over single encrypted SSH connection
```

Advantages:
- Single connection (firewall-friendly)
- Strong encryption (SSH)
- Key-based authentication
- Built into SSH (usually already available)

SFTP became the default for secure file transfer.

### SCP (Secure Copy)

Even simpler than SFTP:

```
scp file.txt user@server:/path/
```

Uses SSH for transport. Good for quick one-off copies. Less feature-rich than SFTP (no directory listing, resume, etc.).

## Modern Alternatives

Why use FTP at all in 2024?

### For Public Files: HTTP

```
Web servers are everywhere.
wget/curl work with HTTP.
No authentication complexity.
TLS is standard.
```

HTTP is easier than FTP for public file hosting.

### For Private Files: SFTP or Managed Services

```
SFTP: Standard, secure, scriptable
Cloud storage APIs: S3, Azure Blob, Google Cloud Storage
Managed file transfer: SFTP-as-a-service
```

### For Development: Git, rsync

```
rsync: Efficient file sync, only transfers differences
Git: Version-controlled file transfer
Docker registries: Container image transfer
```

### When FTP Persists

FTP remains common in:

```
- Legacy systems (mainframes, old business software)
- Web hosting (cPanel still uses FTP by default)
- Embedded systems (some devices only support FTP)
- Bulk data exchange (some industries mandate it)
```

If you must use FTP, use SFTP or at minimum FTPS.

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Two connections | Concurrent control/data | Firewall problems |
| Plaintext (original) | Simplicity | Security |
| Stateful sessions | Resume capability | Scalability |
| Directory abstraction | Cross-platform | Implementation complexity |

## The Principle

> **FTP was designed when networks were trusted and firewalls didn't exist. Its architecture made sense then but conflicts with modern security requirements. SFTP, built on SSH, solves these problems by using a single encrypted connection.**

FTP teaches us that protocols designed for one era may become problematic in another. The network changed; FTP didn't.

## Choosing a File Transfer Protocol

**Use SFTP when:**
- Security matters (almost always)
- You need authentication
- Firewall traversal is important
- SSH is already available

**Use HTTP/HTTPS when:**
- Files are public
- You want simplicity
- Integration with web infrastructure

**Use FTP only when:**
- Legacy systems require it
- AND use FTPS or SFTP wrapper
- AND you understand the risks

**Consider rsync when:**
- Syncing large file sets
- Only changes should transfer
- You need efficiency

---

## Summary

- FTP was the original file transfer protocol, designed in 1971
- Two-connection architecture causes firewall problems
- Original FTP is plaintext—insecure for modern use
- FTPS adds TLS to FTP; SFTP uses SSH for file transfer
- SFTP is the modern standard for secure file transfer
- HTTP often works better for public files
- FTP persists in legacy systems but should be avoided when possible

---

*We've seen how data moves across networks. But data also needs a format—how do we encode meaning? That's data serialization, our next part.*
