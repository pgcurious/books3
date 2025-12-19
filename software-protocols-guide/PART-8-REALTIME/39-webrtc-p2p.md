# Chapter 39: WebRTC—Peer-to-Peer Communication

## Real-Time Media Without Servers in the Middle

---

> *"WebRTC made video calling as simple as clicking a link. The protocol behind it is anything but simple."*
> — WebRTC Developer

---

## The Frustration

You want video calling in your web app. Traditional approach:

```
User A → Server → User B

Problems:
- Server handles all video data (expensive)
- Double latency (A→Server + Server→B)
- Server bandwidth costs for all media
```

What if users could connect directly?

## The Insight: Browser-to-Browser Communication

WebRTC enables direct peer-to-peer connections:

```
User A ←──────→ User B
       (direct)

Benefits:
- Lowest possible latency
- No server bandwidth for media
- End-to-end encryption
```

Servers are only needed for signaling (finding each other) and NAT traversal (connecting through firewalls).

## WebRTC Components

### 1. MediaStream (getUserMedia)

Capture audio/video:

```javascript
const stream = await navigator.mediaDevices.getUserMedia({
    video: true,
    audio: true
});
videoElement.srcObject = stream;
```

### 2. RTCPeerConnection

Manage the peer connection:

```javascript
const pc = new RTCPeerConnection({
    iceServers: [
        { urls: 'stun:stun.example.com' },
        { urls: 'turn:turn.example.com', username: 'user', credential: 'pass' }
    ]
});
```

### 3. RTCDataChannel

Send arbitrary data peer-to-peer:

```javascript
const channel = pc.createDataChannel('chat');
channel.onopen = () => channel.send('Hello!');
channel.onmessage = (e) => console.log(e.data);
```

## The Connection Dance (Signaling)

Peers need to exchange information to connect. WebRTC doesn't specify how—you choose:

```
User A                     Signal Server                    User B
   |                            |                              |
   |─── Offer (SDP) ──────────→|───── Offer (SDP) ──────────→|
   |                            |                              |
   |                            |←─── Answer (SDP) ────────────|
   |←── Answer (SDP) ──────────│                              |
   |                            |                              |
   |─── ICE Candidate ────────→|─── ICE Candidate ──────────→|
   |←── ICE Candidate ─────────|←── ICE Candidate ────────────|
   |                            |                              |
   |═══════════ Direct P2P Connection Established ════════════|
```

### SDP (Session Description Protocol)

Describes capabilities:

```
v=0
o=- 1234567890 2 IN IP4 127.0.0.1
s=-
t=0 0
m=audio 49170 RTP/AVP 0
a=rtpmap:0 PCMU/8000
m=video 51372 RTP/AVP 31
a=rtpmap:31 H261/90000
```

### ICE (Interactive Connectivity Establishment)

Finding a path between peers:

```
1. Gather candidates (possible connection paths)
   - Local addresses
   - Server-reflexive (STUN)
   - Relay (TURN)

2. Exchange candidates via signaling

3. Check connectivity of each pair

4. Select best working path
```

## NAT Traversal

Most users are behind NAT. Direct connection is tricky:

### STUN (Session Traversal Utilities for NAT)

Discover your public IP:

```
Client → STUN Server: "What's my public address?"
STUN Server → Client: "Your public IP:port is 203.0.113.5:12345"

Now client can share this address with peer.
```

### TURN (Traversal Using Relays around NAT)

When direct connection fails:

```
Client A → TURN Server → Client B

TURN relays all data.
Less efficient but always works.
```

### ICE Candidate Types

```
Host:    Local IP (works on same network)
srflx:   Server-reflexive (via STUN)
relay:   Via TURN server (fallback)
```

## WebRTC Media Transport

Media uses RTP (Real-time Transport Protocol):

```
Audio/Video → RTP packets → DTLS encrypted → Network

Features:
- Timestamp synchronization
- Sequence numbers
- Packet loss detection
- Jitter buffering
```

DTLS provides encryption—media is always encrypted in WebRTC.

## Example: Simple Video Call

```javascript
// User A (Caller)
const pc = new RTCPeerConnection({ iceServers: [...] });

// Add local media
const stream = await navigator.mediaDevices.getUserMedia({video: true, audio: true});
stream.getTracks().forEach(track => pc.addTrack(track, stream));

// Handle ICE candidates
pc.onicecandidate = (e) => {
    if (e.candidate) sendToSignalServer(e.candidate);
};

// Create offer
const offer = await pc.createOffer();
await pc.setLocalDescription(offer);
sendToSignalServer(offer);

// Receive answer (from User B via signal server)
signalServer.on('answer', async (answer) => {
    await pc.setRemoteDescription(answer);
});

// Receive ICE candidates
signalServer.on('ice-candidate', async (candidate) => {
    await pc.addIceCandidate(candidate);
});
```

```javascript
// User B (Answerer)
const pc = new RTCPeerConnection({ iceServers: [...] });

// Handle incoming media
pc.ontrack = (e) => {
    videoElement.srcObject = e.streams[0];
};

// Receive offer
signalServer.on('offer', async (offer) => {
    await pc.setRemoteDescription(offer);

    const stream = await navigator.mediaDevices.getUserMedia({video: true, audio: true});
    stream.getTracks().forEach(track => pc.addTrack(track, stream));

    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    sendToSignalServer(answer);
});
```

## DataChannels: Beyond Media

Send arbitrary data peer-to-peer:

```javascript
const channel = pc.createDataChannel('game-state', {
    ordered: false,      // UDP-like
    maxRetransmits: 0    // Don't retry lost packets
});

channel.send(JSON.stringify({ position: {x: 100, y: 200} }));
```

Use cases:
- Multiplayer games
- File transfer
- Screen sharing
- Collaborative editing

## WebRTC vs Server-Mediated

| Aspect | WebRTC | Server-Mediated |
|--------|--------|-----------------|
| Latency | Lowest | Higher |
| Bandwidth cost | Peer pays | Server pays |
| Encryption | End-to-end | To/from server |
| Complexity | High | Medium |
| NAT traversal | Required | Not needed |
| Recording | Harder | Easy |

## When WebRTC is Right

### Video/Audio Calling
```
Direct peer connection = best quality, lowest latency.
Zoom, Google Meet, Discord all use WebRTC.
```

### Real-Time Gaming
```
DataChannel with unreliable mode = fast game state sync.
No server in the middle for gameplay.
```

### File Transfer
```
Large file transfers without server storage.
Peer-to-peer = no upload then download.
```

## When WebRTC is Wrong

### Recording/Archiving
```
Peer-to-peer has no central point for recording.
Use SFU (Selective Forwarding Unit) for this.
```

### Many Participants
```
6 users = 30 peer connections!
Use SFU for large meetings.
```

### Simple Messaging
```
Overkill for text chat.
Use WebSocket.
```

## The Principle

> **WebRTC enables browser-to-browser communication with the lowest possible latency. The complexity of NAT traversal and signaling is the price for direct connections.**

WebRTC is powerful but complex. Use it for real-time media; use simpler protocols for simpler needs.

---

## Summary

- WebRTC enables peer-to-peer audio, video, and data
- Signaling server helps peers find each other
- ICE/STUN/TURN handle NAT traversal
- All media is encrypted via DTLS
- DataChannels provide arbitrary data transfer
- Best for video calls, real-time games, file transfer
- Complex setup is the tradeoff for direct connection

---

*We've covered real-time communication. Now let's explore how distributed systems coordinate—the hardest protocols of all.*
