# Lesson 6 — All the Flowcharts 🧭

This lesson collects every diagram in one place. These use **Mermaid** — if you
open this file on GitHub or in a Markdown viewer that supports Mermaid, they
render as real diagrams. (In a plain editor you still read them as text.)

---

## 6.1 — The state machine (the brain's moods)

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> outgoingRinging: I press Call (startOutgoing)
    idle --> incomingRinging: invite arrives (handleIncomingFromPush)

    outgoingRinging --> connected: peer accepted\n(STOMP call.accept OR Stream peer-joined)
    outgoingRinging --> ended: I cancel / peer rejects / timeout / busy

    incomingRinging --> connected: I accept (acceptIncoming)
    incomingRinging --> ended: I reject / caller cancels / timeout

    connected --> ended: someone hangs up\n(hangup / call.hangup / Stream remoteLeft)
    ended --> idle: cleanup, drop _active
    ended --> [*]
```

---

## 6.2 — Outgoing call (A presses Call)

```mermaid
sequenceDiagram
    participant A as A (caller UI)
    participant SIG as CallSignalingService
    participant TR as ChatTransport
    participant BE as Backend
    participant ST as Stream
    participant B as B (callee phone)

    A->>A: tap call → push VoiceCallPage
    A->>SIG: startOutgoing(convId, type)
    SIG->>SIG: state = outgoingRinging
    SIG-->>A: notify → show "Calling…"
    SIG->>ST: warmUp() (parallel)
    SIG->>TR: sendCallInvite(targetIds)
    TR->>BE: POST /chats/conversations/{id}/calls
    BE->>ST: getOrCreate(ring:true, members:[B])
    ST-->>B: VoIP push → ☎ RING
    BE-->>TR: { id, streamCallCid, participants }
    TR-->>SIG: response
    SIG->>SIG: swap temp id → numeric id, save CID
    SIG->>ST: join(shouldRing:false, isOutgoing:true)
    Note over A,ST: A is in the media leg, waiting on outgoingRinging
```

---

## 6.3 — Incoming call (B's three paths funnel into one handler)

```mermaid
flowchart TD
    FG["App FOREGROUND"] -->|Stream WebSocket| OS1["onStreamIncomingCall"]
    BG["App MINIMIZED"] -->|VoIP push| CK["CallKit native ring"]
    KL["App KILLED"] -->|VoIP push| ISO["isolate → CallKit ring\n+ notifyBackendAcceptEarly"]

    OS1 --> H["handleIncomingFromPush(payload)"]
    CK --> H
    ISO --> H

    H --> DEDUPE{"already have\nthis callId?"}
    DEDUPE -->|yes| STOP["do nothing"]
    DEDUPE -->|no| BUSY{"already in\nanother call?"}
    BUSY -->|yes| REJ["sendCallReject(reason: busy)"]
    BUSY -->|no| SET["_active = incomingRinging"]
    SET --> OV["IncomingCallOverlay shows\nAccept / Reject"]
```

---

## 6.4 — Accept → connected (the two signals)

```mermaid
sequenceDiagram
    participant B as B (callee)
    participant OV as IncomingCallOverlay
    participant SIG as CallSignaling (B)
    participant BE as Backend
    participant ST as Stream
    participant A as A (caller)

    B->>OV: tap Accept
    OV->>OV: push call page FIRST (rootNavigatorKey)
    OV->>SIG: acceptIncoming() (fire-and-forget)
    SIG->>BE: POST /chats/calls/{id}/accept
    SIG->>ST: accept() + join() (or reuse prepared)
    SIG->>SIG: B state = connected, timer starts

    par Primary signal
        BE-->>A: STOMP call.accept → CallAcceptEvent
    and Backup signal
        ST-->>A: remote participant joined → onStreamPeerJoined
    end
    A->>A: state = connected, timer starts
    Note over A,B: 🎙 audio flows through Stream SFU 🎙
```

---

## 6.5 — End / hangup (and how the peer learns)

```mermaid
sequenceDiagram
    participant U as Whoever taps End
    participant SIG as CallSignaling
    participant TR as ChatTransport
    participant BE as Backend
    participant ST as Stream
    participant P as The other side

    U->>SIG: hangup()
    alt outgoing still ringing (iOS)
        SIG->>ST: cancelOutgoingRing() (kill peer's CallKit ring)
    end
    SIG->>TR: sendCallHangup(callId, hangerUpperId)
    TR->>BE: POST /chats/calls/{id}/end
    SIG->>ST: endActiveCall() / leave()
    SIG->>SIG: log ended + write inbox summary
    SIG->>SIG: state = ended → (600ms) → _active = null

    par
        BE-->>P: STOMP call.hangup → CallHangupEvent
    and
        ST-->>P: onStreamCallEnded(remoteLeft)
    end
    P->>P: state = ended, page pops
    Note over P: group call? ignore unless hangerUpperId == caller or me
```

---

## 6.6 — The layered architecture (zoom out)

```mermaid
flowchart TB
    subgraph UI["Layer 1 — UI"]
        VP["VoiceCallPage / VideoCallPage"]
        OV["IncomingCallOverlay"]
    end
    subgraph BRAIN["Layer 2 — Signaling (brain)"]
        SIG["CallSignalingService\nActiveCall + CallSignalState"]
    end
    subgraph TRANSPORT["Layer 3 — Transport"]
        TR["ChatTransport\nREST (dio) + STOMP (WebSocket)"]
    end
    subgraph MEDIA["Layer 4 — Media"]
        SE["StreamCallEngine\n(stream_video_flutter / WebRTC)"]
    end
    subgraph NATIVE["Layer 5 — Native / Push"]
        CK["callkit_event_handler\nCallKit + APNs/FCM VoIP push"]
    end

    VP <--> SIG
    OV <--> SIG
    SIG <--> TR
    SIG <--> SE
    CK --> SIG
    TR <--> BE["Our Backend"]
    SE <--> STREAM["Stream SFU"]
    BE -.rings.-> STREAM
    STREAM -.VoIP push.-> CK
```

---

## 6.7 — One-page cheat sheet

```
START A CALL
  button → push VoiceCallPage → initState → startOutgoing()
  → state=outgoingRinging (UI: "Calling…")
  → POST /chats/conversations/{id}/calls
  → backend Stream getOrCreate(ring:true) → VoIP push → B rings
  → swap id, save CID → streamEngine.join(shouldRing:false)

RECEIVE A CALL
  foreground: Stream WS · background/killed: VoIP push → CallKit
  → handleIncomingFromPush → state=incomingRinging
  → IncomingCallOverlay (Accept / Reject)

ACCEPT
  push call page FIRST → acceptIncoming()
  → POST /accept + Stream accept()+join() → state=connected
  caller flips via STOMP call.accept OR Stream peer-joined fallback

TALK
  Stream SFU carries audio/video · timer ticks · iOS audio re-asserts

END
  hangup() → POST /end + Stream leave() → state=ended → cleanup
  peer learns via STOMP call.hangup OR Stream remoteLeft
  log + inbox summary written
```

Next: **[Lesson 7 — Apply to another project](07-apply-to-another-project.md)**,
then **[Lesson 8 — The 4 incoming-call cases](08-incoming-call-4-cases.md)**.

⬅ Back to the [index](README.md).
