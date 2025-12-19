# Chapter 26: GraphQL—Client-Driven Queries

## Letting Clients Ask for Exactly What They Need

---

> *"GraphQL is not a replacement for REST. It's an alternative that solves different problems."*
> — Lee Byron, GraphQL co-creator

---

## The Frustration

It's 2012 at Facebook. Mobile apps are growing, but the API situation is painful:

**Over-fetching**: The `/users/123` endpoint returns 50 fields. The mobile app needs 3.

**Under-fetching**: To show a user's profile with their posts and friends, you need:
- GET /users/123
- GET /users/123/posts
- GET /users/123/friends

Three round trips. High latency on mobile.

**N+1 Problem**: To show 10 posts with their authors:
- GET /posts (10 posts)
- GET /users/1, GET /users/2, ... (10 more requests)

**Version Explosion**: Different apps need different data. Create custom endpoints for each? Maintain /v1, /v2, /v3?

## The World Before GraphQL

REST APIs served fixed responses:

```
GET /users/123
→ {
    "id": 123,
    "name": "Alice",
    "email": "...",
    "address": {...},
    "preferences": {...},
    "created_at": "...",
    ...50 more fields
}

Mobile app: "I just wanted the name..."
```

Solutions were awkward:
- Custom endpoints per client
- Query parameters (?fields=id,name)
- BFF (Backend for Frontend) pattern
- Accept the waste

## The Insight: Let Clients Specify Their Needs

GraphQL inverts the control. Clients ask for exactly what they need:

```graphql
query {
    user(id: 123) {
        name
        email
        posts(limit: 5) {
            title
            createdAt
        }
        friends {
            name
        }
    }
}
```

Response:

```json
{
    "data": {
        "user": {
            "name": "Alice",
            "email": "alice@example.com",
            "posts": [
                {"title": "Hello World", "createdAt": "2024-01-15"},
                ...
            ],
            "friends": [
                {"name": "Bob"},
                ...
            ]
        }
    }
}
```

One request. Exactly the data needed. No more, no less.

## GraphQL Fundamentals

### Schema Definition

The server defines available types and fields:

```graphql
type User {
    id: ID!
    name: String!
    email: String
    posts: [Post!]!
    friends: [User!]!
}

type Post {
    id: ID!
    title: String!
    content: String!
    author: User!
    createdAt: DateTime!
}

type Query {
    user(id: ID!): User
    posts(limit: Int): [Post!]!
}

type Mutation {
    createPost(title: String!, content: String!): Post!
    updateUser(id: ID!, name: String): User!
}
```

### Queries

Read data:

```graphql
query {
    user(id: "123") {
        name
        posts {
            title
        }
    }
}
```

### Mutations

Modify data:

```graphql
mutation {
    createPost(title: "New Post", content: "...") {
        id
        title
        createdAt
    }
}
```

### Subscriptions

Real-time updates:

```graphql
subscription {
    newPost {
        id
        title
        author {
            name
        }
    }
}
```

## How GraphQL Works

### Single Endpoint

```
POST /graphql
Content-Type: application/json

{
    "query": "query { user(id: 123) { name } }",
    "variables": {}
}
```

All operations go to one endpoint. The query determines the response.

### Resolution

```
Request: { user(id: 123) { name, posts { title } } }

Server resolves:
1. user(id: 123) → calls userResolver(id=123)
2. user.name → returns the name field
3. user.posts → calls postsResolver(user)
4. posts[].title → returns title for each post
```

Each field has a resolver function.

### Introspection

Clients can query the schema itself:

```graphql
query {
    __schema {
        types {
            name
            fields {
                name
                type { name }
            }
        }
    }
}
```

This enables tooling: auto-complete, documentation, validation.

## GraphQL Benefits

### No Over-fetching
Ask for `name`, get only `name`. Mobile data efficiency.

### No Under-fetching
Get user, posts, and friends in one query. Reduced latency.

### Strongly Typed
Schema defines types. Queries validated before execution.

### Self-Documenting
Introspection + schema = automatic documentation.

### Evolving APIs
Add fields freely. Clients only get what they ask for.

```graphql
# Old query (still works)
{ user { name } }

# New query (uses new field)
{ user { name, avatarUrl } }
```

Deprecate fields instead of versioning:

```graphql
type User {
    name: String!
    fullName: String @deprecated(reason: "Use 'name' instead")
}
```

## GraphQL Challenges

### Complexity Attacks

```graphql
query Evil {
    users {
        friends {
            friends {
                friends {
                    friends {
                        name
                    }
                }
            }
        }
    }
}
```

Deeply nested queries can explode database load. Solutions:
- Query depth limiting
- Query cost analysis
- Timeout limits

### N+1 Problem (Still Exists)

```graphql
query {
    posts {        # 1 query for posts
        author {   # N queries for authors!
            name
        }
    }
}
```

Solution: DataLoader pattern for batching.

```javascript
// Without DataLoader: N queries
// With DataLoader: 1 batched query
const userLoader = new DataLoader(ids => batchGetUsers(ids));
```

### Caching is Harder

REST: Cache by URL
```
GET /users/123 → Cache key: /users/123
```

GraphQL: Different queries, same endpoint
```
POST /graphql { query: "{ user(id: 123) { name } }" }
POST /graphql { query: "{ user(id: 123) { email } }" }
```

Solutions: Persisted queries, response caching, client-side caching (Apollo, Relay).

### HTTP Semantics Lost

All GraphQL uses POST (or GET with query param). HTTP caching, status codes—less useful.

## GraphQL vs REST

| Aspect | GraphQL | REST |
|--------|---------|------|
| Data fetching | Client specifies | Server determines |
| Endpoints | Single | Multiple |
| Over/under-fetch | Solved | Common problem |
| Caching | Complex | Natural with HTTP |
| File upload | Awkward | Natural |
| Learning curve | Steeper | Gentler |
| Tooling | Excellent | Mature |

## When GraphQL Shines

### Multiple Clients
Mobile needs less data than web. One API, different queries.

### Complex Data Relationships
Graphs of interconnected data. Get it all in one query.

### Rapidly Evolving APIs
Add fields without breaking clients.

### Developer Experience
Introspection, auto-complete, type safety.

## When REST is Better

### Simple CRUD
If your API is straightforward CRUD, REST is simpler.

### Caching-Heavy
HTTP caching works naturally with REST.

### File Uploads
REST handles multipart uploads easily.

### Public APIs
REST is more widely understood.

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Client-driven queries | Flexibility | Complexity attacks |
| Single endpoint | Simplicity | HTTP semantics |
| Strong typing | Safety | Learning curve |
| Schema requirement | Documentation | Setup overhead |

## The Principle

> **GraphQL recognized that fixed REST endpoints don't match the varied needs of modern clients. By letting clients specify their data requirements, GraphQL eliminates over-fetching and under-fetching—at the cost of added server complexity.**

GraphQL isn't better than REST. It's better for certain problems.

---

## Summary

- GraphQL lets clients request exactly the data they need
- Single endpoint, query determines response
- Schema defines types; introspection enables tooling
- Solves over-fetching and under-fetching
- Challenges: complexity attacks, N+1, caching
- Best for multiple clients with varied data needs
- Not a REST replacement—a different tradeoff

---

*For maximum performance, binary beats text. gRPC brings modern RPC with Protocol Buffers.*
