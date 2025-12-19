# Chapter 45: Choosing the Right Protocol

## A Framework for Protocol Selection

---

> *"The right protocol is the simplest one that solves your problem."*
> — Engineering Wisdom

---

## The Challenge

You've learned dozens of protocols. Now a real project appears. How do you choose?

This chapter provides a framework for making protocol decisions.

## The Decision Framework

Ask these questions in order:

### 1. What Are You Communicating?

```
Request-Response data?     → HTTP, gRPC, REST
Streaming data?            → WebSocket, SSE, Kafka
Events/Messages?           → AMQP, MQTT, Kafka
Real-time media?           → WebRTC
Files?                     → HTTP, SFTP, S3 API
```

### 2. What Are Your Constraints?

```
Browser clients?           → HTTP, WebSocket, SSE
IoT/Embedded?              → MQTT, CoAP
Internal services?         → gRPC, HTTP, messaging
Mobile with poor network?  → HTTP/2, HTTP/3, MQTT
Firewalls/Proxies?         → HTTP, WebSocket (usually)
```

### 3. What Are Your Requirements?

```
Low latency?               → gRPC, WebSocket, UDP
High throughput?           → Kafka, gRPC, custom binary
Strong consistency?        → Raft-based systems, 2PC
Eventually consistent?     → Gossip, CRDTs
Exactly-once delivery?     → Kafka (with care), messaging + idempotency
```

### 4. What Are Your Team's Capabilities?

```
Familiar with REST?        → Start there
Need strong types?         → gRPC, GraphQL
Need flexibility?          → REST, GraphQL
Complex deployment?        → Simpler protocols win
```

## Decision Trees

### API Protocol Selection

```
                    Is it internal only?
                           │
               ┌───────────┴───────────┐
              Yes                      No
               │                       │
         Performance              Public API?
         critical?                     │
               │               ┌───────┴───────┐
       ┌───────┴───────┐      Yes             No
      Yes             No       │               │
       │               │      REST           REST
     gRPC            REST   (widely           or
       │               │    understood)     GraphQL
       │               │
    Binary,         Simple,
    streaming,      debuggable,
    typed           flexible
```

### Messaging Protocol Selection

```
                    Need ordering?
                         │
             ┌───────────┴───────────┐
            Yes                      No
             │                       │
       Need replay?           Complex routing?
             │                       │
     ┌───────┴───────┐       ┌───────┴───────┐
    Yes             No      Yes             No
     │               │       │               │
   Kafka          AMQP     AMQP          Redis
     │          or Kafka     │           Pub/Sub
  Log-based      Queue   Enterprise       │
  streaming      style   messaging      Simple
```

### Real-Time Protocol Selection

```
                  Need bidirectional?
                         │
             ┌───────────┴───────────┐
            Yes                      No
             │                       │
        Peer-to-peer?              SSE
             │                   (simplest)
     ┌───────┴───────┐
    Yes             No
     │               │
  WebRTC        WebSocket
     │               │
   Media,         Chat,
   gaming      collaboration
```

## Common Mistakes

### Over-Engineering

```
Problem: Simple CRUD app
Mistake: Use Kafka, gRPC, microservices
Reality: REST + PostgreSQL would be fine

Simple problems deserve simple solutions.
```

### Under-Engineering

```
Problem: High-throughput event streaming
Mistake: REST with polling
Reality: Events dropped, latency high

Know when simple isn't enough.
```

### Ignoring Ecosystem

```
Problem: Team knows Python, need messaging
Mistake: Choose RabbitMQ because "it's good"
Reality: Python Celery + Redis is simpler for the team

Familiarity reduces bugs and speeds development.
```

### Chasing Trends

```
Problem: Need an API
Mistake: "GraphQL is hot, let's use it"
Reality: Team doesn't know it, use cases don't need it

New protocols have learning curves and less mature tooling.
```

## Protocol Combinations

Real systems use multiple protocols:

### Typical Web Application

```
Browser ←─ HTTPS ─→ Load Balancer
                        │
                   HTTP/2 or gRPC
                        │
                ┌───────┴───────┐
                │               │
            Web Server      API Server
                │               │
           PostgreSQL      Redis PubSub
          (wire protocol)  (RESP protocol)
```

### Microservices Architecture

```
External: REST/GraphQL over HTTPS
Internal: gRPC
Async: Kafka
Config: etcd (gRPC)
Service discovery: Consul (gossip)
```

### IoT System

```
Devices: MQTT to broker
Broker: Kafka for event streaming
Analytics: Kafka consumers
API: REST for dashboards
```

## Evaluation Checklist

Before choosing, verify:

```
□ Performance meets requirements
□ Team can implement and operate it
□ Tooling and libraries exist
□ Debugging is feasible
□ Security requirements are met
□ Failure modes are acceptable
□ Scaling path is clear
□ Migration path exists (if needed)
```

## The Principle

> **The best protocol is determined by your specific constraints: technical requirements, team capabilities, ecosystem, and operational needs. There is no universally best protocol—only the best fit for your situation.**

---

## Summary

- Ask: What are you communicating? What are your constraints?
- Use decision trees to narrow options
- Avoid over-engineering and under-engineering
- Consider team familiarity and ecosystem
- Real systems combine multiple protocols
- Verify with a checklist before committing

---

*What if existing protocols don't fit? Let's discuss designing your own.*
