# Chapter 20: MQTT—IoT and Constrained Devices

## The Protocol Designed for Unreliable Networks and Tiny Devices

---

> *"MQTT: Because your temperature sensor has 32KB of RAM and a 2G connection."*
> — IoT developers everywhere

---

## The Frustration

It's 1999. You're connecting oil pipeline sensors across remote locations. Your constraints:

- **Bandwidth**: Satellite links cost $5 per kilobyte
- **Reliability**: Connections drop constantly
- **Power**: Sensors run on batteries for months
- **Memory**: 8KB RAM is luxurious
- **Latency**: Seconds of delay are normal

HTTP? Too verbose. AMQP? Too complex. You need something minimal.

IBM engineers created MQTT for exactly this scenario.

## The World Before MQTT

IoT connectivity was custom:

```
Device → [Custom binary protocol] → Server
         [Proprietary vendor protocol]
         [HTTP polling] (wasteful)
         [Serial over radio]
```

No standard. Every project reinvented communication.

## The Insight: Minimalism for Constrained Environments

MQTT (Message Queuing Telemetry Transport) was designed with brutal constraints:

```
Minimum packet: 2 bytes
Connect packet: ~12 bytes
Publish packet: topic + payload + 2-4 bytes overhead

Compare to HTTP:
Minimum request: ~100 bytes headers
JSON wrapper: additional overhead
```

MQTT does less, so it can run anywhere.

## MQTT Core Concepts

### Publish-Subscribe Model

```
┌──────────┐         ┌─────────┐         ┌────────────┐
│ Publisher│────────→│  Broker │────────→│ Subscriber │
│ (Sensor) │         │         │────────→│ Subscriber │
└──────────┘         └─────────┘────────→│ Subscriber │
                                         └────────────┘
```

Publishers send to topics. Subscribers listen to topics. They never communicate directly.

### Topics

Hierarchical, slash-separated strings:

```
home/living-room/temperature
home/kitchen/temperature
office/floor-1/room-101/occupancy
sensors/factory-a/machine-7/vibration
```

### Wildcards

`+` matches one level:
```
home/+/temperature
  → matches home/kitchen/temperature
  → matches home/bedroom/temperature
  → doesn't match home/floor1/room1/temperature
```

`#` matches remaining levels:
```
home/#
  → matches home/kitchen/temperature
  → matches home/bedroom/humidity
  → matches home/garage/door/status
```

## Quality of Service (QoS) Levels

MQTT offers three QoS levels:

### QoS 0: At Most Once
Fire and forget:

```
Publisher → Broker: PUBLISH
Done.

If network fails: Message lost.
Use for: Non-critical data (temperature reading every second)
```

Minimal overhead. No acknowledgments.

### QoS 1: At Least Once
Acknowledged delivery:

```
Publisher → Broker: PUBLISH
Broker → Publisher: PUBACK

If no PUBACK: Publisher retries.
Duplicates possible.

Use for: Important data where duplicates are OK
```

One extra packet. Guaranteed delivery.

### QoS 2: Exactly Once
Four-way handshake:

```
Publisher → Broker: PUBLISH
Broker → Publisher: PUBREC (received)
Publisher → Broker: PUBREL (release)
Broker → Publisher: PUBCOMP (complete)

No duplicates. No loss.
Use for: Critical transactions
```

Maximum overhead. Maximum reliability.

## The Session and Clean Start

MQTT maintains session state:

### Persistent Session
```
Client connects with clean_session=false
Client subscribes to topics
Client disconnects

Later:
Client reconnects with same client_id
Broker: "Here are messages you missed while offline"
```

The broker queues messages for offline clients.

### Clean Session
```
Client connects with clean_session=true
Previous subscriptions cleared
No queued messages
Start fresh
```

## Last Will and Testament

What if a device dies silently?

```
Connect:
  client_id: "sensor-42"
  will_topic: "sensors/sensor-42/status"
  will_message: "offline"
  will_qos: 1
  will_retain: true

If connection drops unexpectedly:
Broker publishes: sensors/sensor-42/status → "offline"
```

Other systems learn about the death.

## Retained Messages

A new subscriber needs current state:

```
Without retain:
  Subscriber connects
  Waits for next publish (might be hours)

With retain:
  Publisher: PUBLISH temperature=72 (retain=true)
  Broker stores this
  Later: Subscriber connects
  Broker immediately sends: temperature=72
```

Retained messages provide instant state.

## Keep-Alive

Detect dead connections:

```
Keep-alive: 60 seconds
Client must send PINGREQ every 60 seconds
If nothing from client for 1.5 × 60 = 90 seconds:
Broker considers client dead, sends LWT
```

## Packet Format

MQTT packets are tiny:

```
Fixed Header (1-2 bytes):
┌───────────────────────────────────────┐
│ Packet Type (4 bits) │ Flags (4 bits) │
├───────────────────────────────────────┤
│ Remaining Length (1-4 bytes, varint)  │
└───────────────────────────────────────┘

PUBLISH example:
02          - Packet type (PUBLISH) + flags
0C          - Remaining length: 12 bytes
00 04       - Topic length: 4
74 65 6D 70 - Topic: "temp"
32 33       - Payload: "23"

Total: 10 bytes for topic "temp" with value "23"
```

## MQTT 5.0 Improvements

MQTT 5.0 (2019) added modern features:

```
Reason codes: Why did this fail?
User properties: Custom key-value headers
Message expiry: Auto-delete old messages
Topic aliases: Use number instead of repeating topic string
Request-response: Correlation for request-reply patterns
Shared subscriptions: Load balancing across subscribers
```

## Popular MQTT Brokers

```
Mosquitto    - Lightweight, open source, common choice
EMQ X        - Highly scalable, commercial support
HiveMQ       - Enterprise features, clustering
VerneMQ      - Distributed, Erlang-based
Cloud        - AWS IoT Core, Azure IoT Hub, Google Cloud IoT
```

## MQTT in Practice

```python
# Publisher (sensor)
import paho.mqtt.client as mqtt
import json

client = mqtt.Client()
client.connect("broker.example.com", 1883)

# Publish temperature reading
client.publish(
    "home/living-room/temperature",
    json.dumps({"value": 72.5, "unit": "F"}),
    qos=1,
    retain=True
)

# Subscriber (dashboard)
def on_message(client, userdata, msg):
    print(f"{msg.topic}: {msg.payload}")

client = mqtt.Client()
client.on_message = on_message
client.connect("broker.example.com", 1883)
client.subscribe("home/+/temperature")
client.loop_forever()
```

## MQTT vs Alternatives

| Aspect | MQTT | HTTP | AMQP | CoAP |
|--------|------|------|------|------|
| Overhead | Very low | High | Medium | Very low |
| QoS options | 3 levels | None | Extensive | 2 levels |
| Pattern | Pub-sub | Request-response | Flexible | Request-response |
| Constrained devices | Excellent | Poor | Poor | Excellent |
| Browser support | Needs WebSocket | Native | Needs WebSocket | No |

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Minimal protocol | Low overhead | Limited features |
| Broker-centric | Simple clients | Broker bottleneck |
| Pub-sub only | Decoupling | Request-response complexity |
| QoS in protocol | Reliability control | Processing overhead for QoS 2 |

## The Principle

> **MQTT succeeds in IoT because it was designed for constrained environments from the start. Every byte matters. Every round trip matters. MQTT respects these constraints.**

MQTT isn't trying to solve every messaging problem. It solves one problem—IoT communication—extremely well.

## When to Use MQTT

**Use MQTT when:**
- Constrained devices (sensors, embedded systems)
- Unreliable networks (cellular, satellite, weak WiFi)
- Battery-powered devices
- Many-to-many pub-sub patterns
- Real-time telemetry

**Consider alternatives when:**
- Request-response patterns (HTTP, CoAP)
- Complex routing (AMQP)
- High-throughput streaming (Kafka)
- Browser-only apps (WebSockets directly)

---

## Summary

- MQTT designed for constrained devices and unreliable networks
- Minimal overhead: 2-byte minimum packet
- Three QoS levels: at-most-once, at-least-once, exactly-once
- Features: Last Will, retained messages, persistent sessions
- Hierarchical topics with wildcards
- MQTT 5.0 adds modern features while keeping simplicity

---

*For high-throughput data streaming, we need something different. Enter Kafka.*
