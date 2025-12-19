# Chapter 27: gRPC—Modern RPC

## High-Performance Services with Protocol Buffers

---

> *"gRPC: When you need the simplicity of RPC with the performance of binary protocols."*
> — Google

---

## The Frustration

Microservices communicate constantly. REST/JSON is everywhere, but:

**Performance**: Text serialization is slow. JSON parsing burns CPU.

**Contract drift**: Without schemas, APIs diverge. Breaking changes slip through.

**Streaming**: HTTP/1.1 request-response doesn't handle streaming well.

**Code generation**: Every team writes API clients differently.

Google needed something better for internal services.

## The World Before gRPC

Internal services used various approaches:

```
REST/JSON:     Universal, slow, untyped
SOAP:          Formal, complex, XML overhead
Thrift:        Binary, but dated
Custom binary: Fast, undocumented
```

Google used an internal system called Stubby—gRPC is its open-source successor.

## The Insight: Protocol Buffers + HTTP/2

gRPC combines proven technologies:

- **Protocol Buffers**: Efficient binary serialization (we covered this)
- **HTTP/2**: Multiplexing, streaming, header compression
- **Code generation**: Clients and servers from one definition

```protobuf
syntax = "proto3";

service UserService {
    rpc GetUser(GetUserRequest) returns (User);
    rpc ListUsers(ListUsersRequest) returns (stream User);
    rpc CreateUsers(stream CreateUserRequest) returns (CreateUsersResponse);
}

message User {
    int32 id = 1;
    string name = 2;
    string email = 3;
}
```

From this, generate code for any language:

```bash
protoc --go_out=. --go-grpc_out=. user.proto
protoc --python_out=. --grpc_python_out=. user.proto
protoc --java_out=. --grpc_java_out=. user.proto
```

## gRPC Communication Patterns

### 1. Unary RPC
Classic request-response:

```protobuf
rpc GetUser(GetUserRequest) returns (User);
```

```go
// Client
user, err := client.GetUser(ctx, &GetUserRequest{Id: 123})

// Server
func (s *server) GetUser(ctx context.Context, req *GetUserRequest) (*User, error) {
    return &User{Id: req.Id, Name: "Alice"}, nil
}
```

### 2. Server Streaming
Server sends multiple messages:

```protobuf
rpc ListUsers(ListUsersRequest) returns (stream User);
```

```go
// Client
stream, _ := client.ListUsers(ctx, &ListUsersRequest{})
for {
    user, err := stream.Recv()
    if err == io.EOF { break }
    fmt.Println(user.Name)
}

// Server
func (s *server) ListUsers(req *ListUsersRequest, stream UserService_ListUsersServer) error {
    for _, user := range users {
        stream.Send(&user)
    }
    return nil
}
```

Real-time feeds, large result sets.

### 3. Client Streaming
Client sends multiple messages:

```protobuf
rpc CreateUsers(stream CreateUserRequest) returns (CreateUsersResponse);
```

```go
// Client
stream, _ := client.CreateUsers(ctx)
for _, user := range usersToCreate {
    stream.Send(&CreateUserRequest{Name: user.Name})
}
response, _ := stream.CloseAndRecv()

// Server
func (s *server) CreateUsers(stream UserService_CreateUsersServer) error {
    var count int32
    for {
        req, err := stream.Recv()
        if err == io.EOF {
            return stream.SendAndClose(&CreateUsersResponse{Created: count})
        }
        // Create user...
        count++
    }
}
```

Batch uploads, log ingestion.

### 4. Bidirectional Streaming
Both sides stream simultaneously:

```protobuf
rpc Chat(stream ChatMessage) returns (stream ChatMessage);
```

```go
// Full duplex communication
stream, _ := client.Chat(ctx)

// Send in one goroutine
go func() {
    for _, msg := range messages {
        stream.Send(&msg)
    }
    stream.CloseSend()
}()

// Receive in another
for {
    msg, err := stream.Recv()
    if err == io.EOF { break }
    fmt.Println(msg.Text)
}
```

Real-time chat, live updates, interactive protocols.

## Performance Advantages

### Binary Serialization
```
JSON:     {"id":123,"name":"Alice"}  (27 bytes, slow parse)
Protobuf: \x08\x7b\x12\x05Alice      (9 bytes, fast parse)
```

3x smaller, 10x faster parsing.

### HTTP/2 Features
```
Multiplexing:   Multiple RPCs on one connection
Header compression: HPACK reduces repetitive headers
Flow control:   Prevents overwhelming receivers
```

### Efficient Connections
```
REST:  Often new connection per request, or connection pooling
gRPC:  One connection, multiplexed streams
```

## Code Generation Benefits

### Type Safety
```go
// Compile-time checked
user, err := client.GetUser(ctx, &GetUserRequest{Id: 123})
fmt.Println(user.Name)  // IDE knows this exists

// vs. JSON
data := map[string]interface{}{}
json.Unmarshal(response, &data)
fmt.Println(data["name"])  // Hope it's there...
```

### Cross-Language Consistency
```
Same .proto file generates:
- Go client/server
- Python client/server
- Java client/server
- C++, C#, Ruby, Node.js...

All interoperate perfectly.
```

### No Manual Serialization
```python
# gRPC
response = stub.GetUser(GetUserRequest(id=123))
print(response.name)

# vs manual
response = requests.get(f"/users/{id}")
data = response.json()
user = User(**data)  # Hope the structure matches
```

## gRPC Ecosystem

### Metadata
Like HTTP headers, for cross-cutting concerns:

```go
// Client sends metadata
md := metadata.Pairs("authorization", "Bearer token123")
ctx := metadata.NewOutgoingContext(ctx, md)
client.GetUser(ctx, req)

// Server reads metadata
md, _ := metadata.FromIncomingContext(ctx)
token := md["authorization"][0]
```

### Interceptors
Middleware for gRPC:

```go
func loggingInterceptor(ctx context.Context, req interface{},
    info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
    start := time.Now()
    resp, err := handler(ctx, req)
    log.Printf("%s took %v", info.FullMethod, time.Since(start))
    return resp, err
}
```

### Deadlines
Request-scoped timeouts:

```go
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()

response, err := client.GetUser(ctx, &GetUserRequest{Id: 123})
if err != nil {
    if status.Code(err) == codes.DeadlineExceeded {
        // Timeout
    }
}
```

Deadlines propagate through service chains.

### Health Checking
Standard health check protocol:

```protobuf
service Health {
    rpc Check(HealthCheckRequest) returns (HealthCheckResponse);
    rpc Watch(HealthCheckRequest) returns (stream HealthCheckResponse);
}
```

Load balancers can use this.

## gRPC-Web

Browsers can't do raw gRPC (no HTTP/2 trailers, no binary streams). gRPC-Web bridges this:

```
Browser → [gRPC-Web Proxy] → gRPC Server

Proxy translates HTTP/1.1 + base64 to gRPC.
```

Or use Envoy, which supports gRPC-Web natively.

## gRPC vs REST vs GraphQL

| Aspect | gRPC | REST | GraphQL |
|--------|------|------|---------|
| Format | Binary (Protobuf) | Text (JSON) | Text (JSON) |
| Protocol | HTTP/2 | HTTP/1.1+ | HTTP |
| Schema | Required (.proto) | Optional (OpenAPI) | Required |
| Streaming | Built-in | WebSocket add-on | Subscriptions |
| Browser support | Via proxy | Native | Native |
| Performance | Highest | Medium | Medium |
| Flexibility | Fixed contracts | Fixed endpoints | Client-driven |

## When gRPC Shines

### Microservices
Service-to-service communication. Performance matters.

### Streaming Requirements
Server-side events, bidirectional communication.

### Polyglot Environments
Many languages, one contract.

### High-Performance Systems
Every microsecond counts.

## When gRPC is Wrong

### Public APIs
REST is more accessible. Better tooling for exploration.

### Browser-Only Apps
Native gRPC requires proxy. REST/GraphQL are simpler.

### Simple CRUD
Overhead of protobuf compilation may not be worth it.

### Text Debugging
Binary protocols are harder to inspect.

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Binary format | Performance | Debuggability |
| HTTP/2 | Multiplexing, streaming | Browser complexity |
| Code generation | Type safety | Build complexity |
| Strong contracts | Correctness | Flexibility |

## The Principle

> **gRPC brings the RPC paradigm into the modern era with binary efficiency, streaming support, and strong typing. For internal services where performance matters, gRPC is often the best choice.**

gRPC isn't for every API. It's for high-performance, strongly-typed, service-to-service communication.

---

## Summary

- gRPC combines Protocol Buffers + HTTP/2
- Four patterns: unary, server streaming, client streaming, bidirectional
- 3x smaller, 10x faster than JSON
- Code generation provides type safety across languages
- Features: metadata, interceptors, deadlines, health checking
- Best for internal microservices, streaming, high-performance
- REST remains better for public APIs and browsers

---

*APIs need protection. Next, we explore security protocols—starting with why security is hard.*
