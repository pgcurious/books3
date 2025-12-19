# Chapter 9: HTTP—The Language of the Web

## How We Made Documents Accessible Everywhere

---

> *"I just had to take the hypertext idea and connect it to the TCP and DNS ideas and—ta-da!—the World Wide Web."*
> — Tim Berners-Lee

---

## The Frustration

It's 1989 at CERN. Physicists have data—lots of data. Research papers, experimental results, equipment documentation. All scattered across different computers, in different formats, using different access methods.

To read a document on system A, you use one tool. To read something on system B, a different tool. There's no way to link between them. No way to browse. You have to know exactly what you're looking for and where it is.

Tim Berners-Lee saw a simple problem: "Why can't I click on a word and go to the related document, wherever it is?"

## The World Before HTTP

Accessing remote documents required:

- **FTP**: Connect, authenticate, navigate directories, download, open with appropriate viewer
- **Gopher**: Menu-based browsing, limited to text, hierarchical only
- **WAIS**: Full-text search, but no linking
- **Telnet**: Log into the remote machine, use their software

None of these supported hypertext—the idea that a word or phrase could link directly to another document.

## The Insight: Stateless, Hypertext Transfer

HTTP (Hypertext Transfer Protocol) was designed with specific goals:

### 1. Simplicity
A request is just text. A response is just text. A human can type a request and read the response:

```
Request:
GET /index.html HTTP/1.0
Host: info.cern.ch

Response:
HTTP/1.0 200 OK
Content-Type: text/html

<html>
<body>Welcome to CERN</body>
</html>
```

No binary encoding. No complex state machines. Anyone could implement it.

### 2. Statelessness
Each request is independent. The server doesn't remember previous requests:

```
Request 1: GET /page1.html → Response
Request 2: GET /page2.html → Response
Request 3: GET /page1.html → Same response

The server treats each request as if it's the first.
No login state, no session, no memory.
```

This simplifies servers dramatically: no session storage, no cleanup, easy horizontal scaling.

### 3. Resource-Based
Everything is a resource with a URL (Uniform Resource Locator):

```
http://info.cern.ch/hypertext/WWW/TheProject.html

Protocol: http
Host: info.cern.ch
Path: /hypertext/WWW/TheProject.html

The URL uniquely identifies a resource.
The resource is an abstraction—it might be a file,
generated content, or anything else.
```

### 4. Media-Independent
HTTP can transfer anything:

```
Content-Type: text/html       → HTML document
Content-Type: image/png       → PNG image
Content-Type: application/json → JSON data
Content-Type: video/mp4       → MP4 video

The protocol doesn't care what's inside.
```

## The HTTP Methods

HTTP defines what you want to do with a resource:

### GET
Retrieve a resource. Safe. Idempotent.
```
GET /users/123
→ Returns user 123's data
```

### POST
Submit data to be processed. Not safe. Not idempotent.
```
POST /users
Body: {"name": "Alice"}
→ Creates a new user
```

### PUT
Replace a resource entirely. Idempotent.
```
PUT /users/123
Body: {"name": "Alice", "email": "alice@example.com"}
→ Replaces user 123 completely
```

### DELETE
Remove a resource. Idempotent.
```
DELETE /users/123
→ Removes user 123
```

### PATCH
Partially update a resource.
```
PATCH /users/123
Body: {"email": "newemail@example.com"}
→ Updates only the email
```

### HEAD
Like GET but returns only headers, not body.
```
HEAD /large-file.zip
→ Returns headers (including Content-Length) without downloading
```

### OPTIONS
What methods are supported for this resource?
```
OPTIONS /users
→ Allow: GET, POST, PUT, DELETE
```

## HTTP Status Codes

Responses include status codes:

### 2xx: Success
```
200 OK         - Request succeeded
201 Created    - Resource created
204 No Content - Success, nothing to return
```

### 3xx: Redirection
```
301 Moved Permanently - Resource moved, update your links
302 Found            - Resource temporarily elsewhere
304 Not Modified     - Use your cached version
```

### 4xx: Client Error
```
400 Bad Request    - Malformed request
401 Unauthorized   - Authentication required
403 Forbidden      - Authenticated but not allowed
404 Not Found      - Resource doesn't exist
429 Too Many Requests - Rate limited
```

### 5xx: Server Error
```
500 Internal Server Error - Something broke
502 Bad Gateway          - Upstream service failed
503 Service Unavailable  - Temporarily overloaded
504 Gateway Timeout      - Upstream didn't respond
```

## Headers: Metadata

HTTP headers carry metadata:

### Request Headers
```
Host: example.com          - Which site (for virtual hosting)
Accept: text/html          - What content types I want
Accept-Language: en-US     - Preferred language
Authorization: Bearer xyz  - Authentication credentials
Cookie: session=abc123     - Session data
If-Modified-Since: [date]  - Conditional request
```

### Response Headers
```
Content-Type: text/html    - What I'm sending
Content-Length: 1234       - How big it is
Cache-Control: max-age=3600 - Caching instructions
Set-Cookie: session=abc123 - Store this cookie
Location: /new-url         - Redirect here
```

## The Statelessness "Problem"

Statelessness is elegant but creates challenges:

### Authentication
Without state, how does the server know who you are?

**Solution: Cookies**
```
Login:
POST /login → Set-Cookie: session=abc123

Subsequent requests:
GET /dashboard
Cookie: session=abc123
→ Server looks up session abc123 to identify you
```

Cookies add state, but it's managed by clients, not servers.

### Shopping Carts
How does the server remember what's in your cart?

**Solution: Session or Token**
```
The session cookie references server-side state, or
The cart data is encoded in the cookie/token itself.
```

HTTP remains stateless; the application layer manages state.

## HTTP/1.0 to HTTP/1.1

The original HTTP/1.0 had a critical inefficiency:

```
HTTP/1.0:
Open connection → Request → Response → Close connection
Open connection → Request → Response → Close connection
Open connection → Request → Response → Close connection

Every request requires a new TCP connection.
TCP handshake cost: 1 RTT minimum.
```

HTTP/1.1 added persistent connections:

```
HTTP/1.1:
Open connection → Request → Response
                → Request → Response
                → Request → Response → Close connection

One connection, many requests.
Massive performance improvement.
```

HTTP/1.1 also added:
- **Chunked transfer**: Stream responses of unknown length
- **Pipelining**: Send multiple requests without waiting (rarely used due to head-of-line blocking)
- **Host header**: Required, enabling virtual hosting

## The Tradeoffs HTTP Made

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Stateless | Scalability, simplicity | Application complexity |
| Text-based | Debuggability | Efficiency |
| Request-response | Simplicity | Real-time capability |
| Universal | Wide adoption | Protocol bloat |

## Why HTTP Won

HTTP succeeded not because it was technically superior, but because:

### 1. Low Barrier to Entry
Anyone could write a server or client. No special tools needed.

### 2. Graceful Extensibility
Headers allowed adding features without breaking old software.

### 3. Universal Resource Naming
URLs work for everything, not just HTML.

### 4. The Browser Came Free
Mosaic and then Netscape made HTTP accessible to non-technical users.

## HTTP Beyond the Web

HTTP became the universal application protocol:

- **APIs**: REST, GraphQL, and most APIs use HTTP
- **Mobile apps**: Backend communication
- **IoT**: Many devices speak HTTP
- **Microservices**: Service-to-service calls
- **Streaming**: Chunked responses for video

HTTP's simplicity made it the default choice for any application protocol.

## The Principle

> **HTTP succeeded by being simple, stateless, and universal. It gave everything a URL and a standard way to access it. Its simplicity enabled the web to grow faster than any previous protocol.**

The web's success is inseparable from HTTP's design choices. Statelessness enabled scaling. Simplicity enabled adoption. Extensibility enabled evolution.

## Why HTTP Matters Today

Understanding HTTP helps you understand:

- **Why web apps need cookies**: Stateless by design
- **Why APIs use HTTP**: It's universal
- **Why debugging is easy**: Text-based, inspectable
- **Why HTTP headers matter**: They control caching, auth, content
- **Why HTTPS everywhere**: HTTP has no encryption
- **Why HTTP/2 and HTTP/3 exist**: Performance limitations of HTTP/1.1

---

## Summary

- HTTP was designed for simplicity: text-based, stateless, resource-oriented
- Methods (GET, POST, PUT, DELETE) describe intent
- Status codes indicate outcomes
- Headers carry metadata
- Statelessness enables scaling; cookies add session management
- HTTP/1.1 improved performance with persistent connections
- HTTP became the universal application protocol

---

*HTTP/1.1 served us well, but the web outgrew it. Let's see how HTTP evolved—our next chapter.*
