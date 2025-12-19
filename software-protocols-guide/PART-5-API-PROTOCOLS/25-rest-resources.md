# Chapter 25: REST—Resources and Representations

## Embracing HTTP Instead of Fighting It

---

> *"REST is not a protocol. It's an architectural style. Most 'REST APIs' aren't RESTful—and that's often fine."*
> — Pragmatic developers

---

## The Frustration

SOAP was complex. Developers wanted something simpler. They looked at HTTP and saw:

- **URLs** identify things
- **Methods** (GET, POST, PUT, DELETE) describe actions
- **Status codes** indicate results
- **Headers** carry metadata

Why wrap everything in XML envelopes? Why ignore what HTTP already provides?

## The World Before REST

Web services meant SOAP or custom protocols:

```xml
<!-- SOAP: Action buried in body -->
POST /service HTTP/1.1
Content-Type: text/xml

<soap:Envelope>
    <soap:Body>
        <GetUser>
            <userId>123</userId>
        </GetUser>
    </soap:Body>
</soap:Envelope>
```

HTTP's semantics were unused. Everything was POST to a single endpoint.

## The Insight: Resources and Representations

Roy Fielding's 2000 dissertation defined REST (Representational State Transfer). The key insight:

**The web is about resources.**

A resource is anything with an identity:
- A user
- A document
- A shopping cart
- Today's weather in Seattle

Resources have **representations** (JSON, HTML, XML) transferred over HTTP.

```
Resource: User #123
URL: /users/123
Representation: {"id": 123, "name": "Alice", "email": "..."}
```

## REST Constraints

Fielding defined constraints, not rules:

### 1. Client-Server
Separate concerns. Clients don't store business logic. Servers don't store client state.

### 2. Stateless
Each request contains all information needed. Server doesn't remember previous requests.

```
# Stateful (not REST)
GET /next-page    <- Server remembers which page you're on

# Stateless (REST)
GET /items?page=2 <- Request contains all needed info
```

### 3. Cacheable
Responses indicate cacheability:

```
HTTP/1.1 200 OK
Cache-Control: max-age=3600
ETag: "abc123"

Clients and intermediaries can cache this.
```

### 4. Layered System
Clients don't know if they're talking to the origin server or an intermediary (CDN, load balancer).

### 5. Uniform Interface
The key constraint. Four sub-constraints:

- **Resource identification**: URLs identify resources
- **Manipulation through representations**: Send representations to modify resources
- **Self-descriptive messages**: Messages include all needed metadata
- **Hypermedia as the engine of application state** (HATEOAS): Responses include links to related actions

### 6. Code on Demand (Optional)
Servers can send executable code (JavaScript).

## Practical REST: The Richardson Maturity Model

Most APIs claiming "REST" aren't fully RESTful. The maturity model:

### Level 0: The Swamp of POX
```
POST /api
{"action": "getUser", "userId": 123}
```
HTTP as tunnel. SOAP without the envelope.

### Level 1: Resources
```
POST /users/123
{"action": "get"}
```
URLs identify resources. Still only POST.

### Level 2: HTTP Verbs
```
GET    /users/123       - Read
POST   /users           - Create
PUT    /users/123       - Update
DELETE /users/123       - Delete
```
HTTP methods have meaning. **Most APIs stop here.**

### Level 3: Hypermedia (HATEOAS)
```json
{
    "id": 123,
    "name": "Alice",
    "_links": {
        "self": {"href": "/users/123"},
        "orders": {"href": "/users/123/orders"},
        "delete": {"href": "/users/123", "method": "DELETE"}
    }
}
```
Responses include navigation. Clients discover actions from responses.

## HTTP Methods in REST

### GET - Read
```
GET /users/123
→ 200 OK + user data

Safe (no side effects)
Idempotent (multiple calls = same result)
Cacheable
```

### POST - Create
```
POST /users
Body: {"name": "Alice", "email": "..."}
→ 201 Created
→ Location: /users/123

Not safe
Not idempotent (creates new resource each time)
```

### PUT - Replace
```
PUT /users/123
Body: {"name": "Alice", "email": "new@example.com"}
→ 200 OK

Not safe
Idempotent (same result each time)
```

### PATCH - Partial Update
```
PATCH /users/123
Body: {"email": "new@example.com"}
→ 200 OK

Only updates specified fields.
```

### DELETE - Remove
```
DELETE /users/123
→ 204 No Content

Idempotent (deleting twice = same result)
```

## Status Codes

REST uses HTTP status codes meaningfully:

```
2xx Success
200 OK                  - Success with body
201 Created             - Resource created
204 No Content          - Success, no body

3xx Redirection
301 Moved Permanently   - Resource moved
304 Not Modified        - Use cached version

4xx Client Error
400 Bad Request         - Invalid request
401 Unauthorized        - Authentication required
403 Forbidden           - Authenticated but not allowed
404 Not Found           - Resource doesn't exist
409 Conflict            - State conflict
422 Unprocessable       - Validation error

5xx Server Error
500 Internal Error      - Server bug
502 Bad Gateway         - Upstream failure
503 Service Unavailable - Temporarily down
```

## Content Negotiation

Clients request formats:

```
GET /users/123
Accept: application/json
→ JSON response

GET /users/123
Accept: text/html
→ HTML response

Same resource, different representations.
```

## URL Design

Good URLs are:

```
/users                      - Collection
/users/123                  - Specific user
/users/123/orders           - User's orders
/users/123/orders/456       - Specific order

Nouns, not verbs:
/users/123          ✓
/getUser?id=123     ✗

Hierarchical:
/orders/456/items   ✓
/orderItems?order=456 (less clear)

Plural for collections:
/users              ✓
/user               (inconsistent)
```

## REST vs RPC Style

```
RPC style (actions):
POST /createUser
POST /updateUser
POST /deleteUser

REST style (resources):
POST   /users
PUT    /users/123
DELETE /users/123
```

REST focuses on *what* (resources), not *how* (procedures).

## The "REST" Reality

Most "REST APIs" are really "HTTP APIs":

```
✓ Use HTTP methods
✓ Use URLs for resources
✓ Return JSON
✗ Hypermedia (rarely)
✗ Proper caching
✗ Content negotiation

That's fine. Level 2 is practical and useful.
```

Full REST (Level 3 with HATEOAS) is rare. The benefits often don't justify the complexity.

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| HTTP semantics | Caching, tooling | Learning curve |
| Stateless | Scalability | Client complexity |
| URLs for resources | Intuitive, cacheable | Multiple roundtrips |
| JSON (typically) | Simplicity | Some efficiency |

## When REST Works Well

- CRUD operations
- Public APIs
- Web/mobile clients
- Cacheable data
- Simple relationships

## When REST Struggles

- Complex queries (use GraphQL)
- Realtime (use WebSockets)
- High-performance (use gRPC)
- Graphs of data (overfetching/underfetching)

## The Principle

> **REST embraced HTTP's design instead of fighting it. URLs identify resources. Methods indicate actions. Status codes signal results. This alignment with the web made REST natural for web APIs.**

REST isn't perfect, but it's simple, widely understood, and leverages existing web infrastructure.

## Practical Guidelines

1. **Use nouns for URLs, verbs for methods**
2. **Be consistent with pluralization**
3. **Use proper status codes**
4. **Support filtering and pagination**
5. **Version your API** (/v1/users)
6. **Document clearly** (OpenAPI/Swagger)
7. **Don't obsess about "true REST"** — Level 2 is usually enough

---

## Summary

- REST is an architectural style, not a protocol
- Resources have URLs; representations are transferred
- HTTP methods (GET, POST, PUT, DELETE) have meanings
- Status codes indicate outcomes
- Most APIs are "HTTP APIs" (Level 2), not full REST
- HATEOAS (Level 3) is rarely implemented
- REST works well for CRUD; consider alternatives for complex queries

---

*REST struggles with complex data needs. GraphQL was invented to solve this.*
