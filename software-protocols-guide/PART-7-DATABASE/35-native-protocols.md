# Chapter 35: Native Protocols—PostgreSQL, MySQL, MongoDB

## Understanding Database-Specific Communication

---

> *"To debug database issues, you sometimes need to speak the database's language."*
> — Every DBA at 3 AM

---

## The Frustration

You're debugging a slow query. The JDBC abstraction shows you results, but you need to understand:

- Why is this query slow?
- What's happening on the wire?
- How does the database interpret this?

Understanding native protocols helps you debug, optimize, and appreciate what abstraction layers hide.

## PostgreSQL Wire Protocol

### Message-Based Design

Every message has:

```
┌────────────┬─────────────┬──────────────────────────┐
│ Type (1B)  │ Length (4B) │ Payload (variable)       │
└────────────┴─────────────┴──────────────────────────┘
```

### Startup Sequence

```
Client → Server: StartupMessage
    Version: 3.0
    Parameters: user=alice, database=mydb

Server → Client: AuthenticationClearTextPassword
    (or other auth method)

Client → Server: PasswordMessage
    password=secret

Server → Client: AuthenticationOk
Server → Client: ParameterStatus (server_version, etc.)
Server → Client: BackendKeyData (PID for cancel)
Server → Client: ReadyForQuery
```

### Simple Query

```
Client: 'Q' + length + "SELECT * FROM users\0"

Server: 'T' + RowDescription (columns)
Server: 'D' + DataRow (values)
Server: 'D' + DataRow
...
Server: 'C' + CommandComplete ("SELECT 5")
Server: 'Z' + ReadyForQuery
```

### Extended Query Protocol

For prepared statements:

```
Client: 'P' (Parse) + name + query + parameter types
Server: '1' (ParseComplete)

Client: 'B' (Bind) + portal + statement + parameters
Server: '2' (BindComplete)

Client: 'E' (Execute) + portal + row_limit
Server: 'D' (DataRow)...
Server: 'C' (CommandComplete)

Client: 'S' (Sync)
Server: 'Z' (ReadyForQuery)
```

### Why Extended Protocol Matters

```
Simple Query:
- Parses SQL every time
- No parameter binding (SQL injection risk)

Extended Query:
- Parse once, execute many
- Type-safe parameters
- Plan caching
```

## MySQL Protocol

### Packet Format

```
┌─────────────────┬───────────────────┬──────────────────┐
│ Length (3B)     │ Sequence (1B)     │ Payload          │
└─────────────────┴───────────────────┴──────────────────┘

Max packet: 16MB (larger data split across packets)
Sequence: Increments per exchange
```

### Handshake

```
Server → Client: Handshake packet
    Protocol version, server version, auth plugin, salt

Client → Server: Handshake response
    Client flags, auth response, database

Server → Client: OK or Error
```

### Query Commands

```
COM_QUERY (0x03):
Client: 03 + "SELECT * FROM users"
Server: Column count
Server: Column definitions
Server: EOF
Server: Row data...
Server: EOF or Error

COM_STMT_PREPARE (0x16):
Client: 16 + "SELECT * FROM users WHERE id = ?"
Server: Statement ID + column/param info

COM_STMT_EXECUTE (0x17):
Client: 17 + statement_id + flags + parameters
Server: Result set
```

### MySQL vs PostgreSQL

| Aspect | MySQL | PostgreSQL |
|--------|-------|------------|
| Message type | First byte of packet | Dedicated type byte |
| Max packet | 16MB (can split) | 1GB |
| Prepared stmt | Binary protocol | Extended query protocol |
| Async | Limited | Full NOTIFY/LISTEN |

## MongoDB Wire Protocol

### Document-Based

MongoDB sends BSON (Binary JSON) documents:

```
Message format:
┌─────────────────┬─────────────────┬─────────────────┐
│ Length (4B)     │ RequestID (4B)  │ ResponseTo (4B) │
├─────────────────┴─────────────────┴─────────────────┤
│ OpCode (4B)                                         │
├─────────────────────────────────────────────────────┤
│ Payload (BSON documents)                            │
└─────────────────────────────────────────────────────┘
```

### Modern Protocol (OP_MSG, 2017+)

```
OP_MSG (2013) replaced legacy opcodes:

Client: OP_MSG with command document
{
    "find": "users",
    "filter": {"status": "active"},
    "limit": 10
}

Server: OP_MSG with result
{
    "cursor": {
        "firstBatch": [...documents...],
        "id": 0,
        "ns": "mydb.users"
    },
    "ok": 1
}
```

### Why Document Protocol?

```
Relational: Rows and columns, fixed schema
Document: Flexible structure, nested data

Protocol reflects the data model:
- SQL databases send tabular results
- MongoDB sends document trees
```

## Redis Protocol (RESP)

### Human-Readable Simplicity

```
Request (SET key value):
*3\r\n
$3\r\n
SET\r\n
$3\r\n
key\r\n
$5\r\n
value\r\n

Response:
+OK\r\n
```

### Data Types

```
+OK\r\n                    Simple string
-ERR message\r\n           Error
:42\r\n                    Integer
$5\r\nhello\r\n            Bulk string (5 bytes)
*3\r\n...\r\n              Array (3 elements)
```

### Why So Simple?

```
Redis is:
- In-memory (speed is everything)
- Single-threaded (simple protocol helps)
- Used for caching (simple operations)

Complex protocol would add latency for no benefit.
```

## Protocol Debugging

### Wireshark

```
Capture PostgreSQL traffic:
- Filter: tcp.port == 5432
- Dissector recognizes PostgreSQL protocol
- See message types, queries, results
```

### tcpdump

```bash
# Capture PostgreSQL traffic
tcpdump -i any port 5432 -w capture.pcap

# Analyze with tshark
tshark -r capture.pcap -Y "pgsql" -T fields -e pgsql.query
```

### Database Logs

```
# PostgreSQL
log_statement = 'all'
log_duration = on

# MySQL
general_log = 1
general_log_file = /var/log/mysql/general.log
```

## The Tradeoffs

| Database | Protocol Strength | Protocol Weakness |
|----------|-------------------|-------------------|
| PostgreSQL | Rich features, async | Complexity |
| MySQL | Wide compatibility | Less streaming |
| MongoDB | Document-native | Larger messages |
| Redis | Simplicity, speed | Limited data types |

## The Principle

> **Native database protocols reflect each database's design philosophy. PostgreSQL's extended query protocol enables plan caching. MongoDB's document protocol matches its flexible schema. Redis's simple protocol matches its simple operations.**

Understanding these protocols helps you debug issues, optimize performance, and choose the right database.

---

## Summary

- PostgreSQL uses message-based protocol with extended query support
- MySQL uses packet-based protocol with command codes
- MongoDB uses document-oriented BSON protocol
- Redis uses simple text-based RESP protocol
- Each protocol reflects its database's design philosophy
- Protocol knowledge enables deeper debugging

---

*Databases handle stored data. But what about real-time communication? That's our next part.*
