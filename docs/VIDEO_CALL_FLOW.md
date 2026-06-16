# Video Call Flow (voice vs video type propagation)

How **video** calls work end to end, and — the part that actually bites —
how the **voice-vs-video** distinction travels from caller to callee across
every transport. The ring / accept / reject / hang-up *ceremony* is identical
to voice (see [`IOS_CALL_FLOW.md`](./IOS_CALL_FLOW.md)); this doc covers only
where video **diverges** and where the type can get **lost**.

> ## 🔒 Golden rule
> Same as the call flow: **Android calls already work; every iOS call fix must
> be iOS-only and additive.** The type-resolution fixes below follow that —
> `Platform.isIOS` guards, additive keys, fetch-with-voice-fallback.

---

## 1. Where video differs from voice

Voice and video share the same signalling, presence gate, ring, and teardown.
Video diverges in exactly three places — all correct, all intentional:

| Concern | Voice | Video | Where |
|---|---|---|---|
| Media track | mic only | mic **+ camera** | [`stream_call_engine.dart` `_connectOptions`](../lib/features/chat/repositories/stream_call_engine.dart) |
| Permission | `microphone` | `microphone` **+ `camera`** (partial grant handled) | [`call_permission_gate.dart`](../lib/features/chat/repositories/call_permission_gate.dart) |
| iOS audio mode | `voiceChat` | `videoChat` | `stream_call_engine.dart` `configureIosCallAudio` |
| In-call UI | avatar + audio | `StreamCallParticipants` (remote) + `_LiveLocalPip` (mirrored front cam) | [`video_call_page.dart`](../lib/features/chat/views/video_call_page.dart) |

Everything else (backend `ChatCallService.start`, the presence gate, the
Stream ring, STOMP `call.invite`, the in-call state machine) is **byte-for-byte
the same** for both — only the `type` field differs.

---

## 2. The one hard problem: the type is authoritative ONLY on the backend

The voice/video flag lives on the backend `ChatCall.type` (`VOICE` / `VIDEO`),
surfaced as `ChatCallDto.type`. It is **NOT** reliably encoded anywhere on the
Stream / CallKit layer, because:

- `StreamTokenService.cidForCall` mints **every** CID as
  `default:erp-call-<id>` — the Stream call type is always `"default"`, never
  `"video"`.
- `StreamVideoService.ring` rings Stream with `{ ring:true, data:{members} }`
  — **no custom data, no video flag**.

So anything that infers the type from the Stream call object
(`state.callType.value`), the CallKit `type` flag (`'1'`=video), or Stream's
`call.ring` push (`call_type`) reads **voice for every call**. Voice "worked"
only because voice is the accidental default; **video opened the voice page.**

### The single source of truth

```
GET /chats/calls/{id}  →  data.type ∈ { "VOICE", "VIDEO" }
```

Resolved through one helper (returns `bool? ` — `null` on failure → fall back
to voice, preserving old behaviour):

- main isolate (DI):  `CallSignalingService.isVideoCall(callId)`
- FCM background isolate (no DI): `_fetchIsVideoFromBackend(callId, token)`
  in [`firebase_notification_provider.dart`](../lib/shared/firebase_services/firebase_notification_provider.dart)
  (bare `HttpClient` + stored access token, no 401-refresh — best effort).

---

## 3. The three sources that lie (and where each is corrected)

| Path | Wrong source | Corrected in |
|---|---|---|
| iOS foreground / online | — (already correct: STOMP `_callInviteFromDto` reads `json['type']`) | n/a |
| iOS foreground misdetect / WS-up | `state.callType.value == 'video'` | `CallSignalingService._handleStreamIncomingCall` → `isVideoCall` |
| iOS background / killed accept | CallKit `params['type'] == '1'` | `callkit_event_handler._handleAccept` → `isVideoCall` (after the early-accept POST, before seeding `_active` + page push) |
| Android background / killed ring | Stream push `call_type == 'video'` | `firebase_notification_provider` `call.ring` → `_fetchIsVideoFromBackend` |
| Android background / killed accept | launch payload `isVideo` | `app.dart._handleNativeCallLaunch` → `signaling.isVideoCall` (DI backstop) |

`_handleDecline` still uses the CallKit flag — it only affects the *logged*
call type (📞 vs 📹), which is cosmetic on a decline.

---

## 4. End-to-end flow

### Outgoing (caller)
```
VideoCallPage  → startOutgoing(callType: video)
  → ensureCallPermissions(needCamera: true)         (mic + camera)
  → sendCallInvite(callType: video)
       → POST /conversations/{id}/calls { type: "VIDEO" }
  → StreamCallEngine.join(isVideo: true)            (camera track enabled)
```
Backend stores `type=VIDEO`, broadcasts `call.invite` (DTO `type:"VIDEO"`)
over STOMP, and (OFFLINE callees only) rings Stream.

### Incoming — foreground / online callee (STOMP)
```
STOMP call.invite  → _callInviteFromDto reads json['type'] = "VIDEO"  ✅
  → ActiveCall.callType = video
  → IncomingCallOverlay shows video sheet; Accept → VideoCallPage
```

### Incoming — iOS backgrounded / killed (Stream VoIP → CallKit)
```
VoIP push → native CallKit ring (flagged audio; cosmetic — see §5)
Accept → callkit_event_handler._handleAccept
  → notifyBackendAcceptEarly()                      (caller stops ringing first)
  → isVideo = await isVideoCall(backendCallId)  ✅  (overrides CallKit flag)
  → seed _active(callType: video) → push VideoCallPage → join(isVideo:true)
```

### Incoming — Android backgrounded / killed (Stream call.ring FCM)
```
FCM call.ring (background isolate)
  → isVideo = _fetchIsVideoFromBackend(callId, token)  ✅
  → ErpCallKit.showIncomingCall(isVideo: true)         (ring shows video)
Accept → app launches → app.dart._handleNativeCallLaunch
  → isVideo = await signaling.isVideoCall(callId)  ✅  (DI backstop)
  → handleIncomingFromPush(callType: video) → acceptIncoming()
  → IncomingCallOverlay auto-push → VideoCallPage
```

---

## 5. Known limitations

- **iOS native ringer icon may still show "voice" for a video call.** A
  blocking `GET` before reporting a PushKit call risks iOS killing the app for
  a late CallKit report, so `_showStreamCallkitRinger` is left as-is. The
  *accept* is corrected in `_handleAccept`, so the call still opens as video —
  only the ring glyph is wrong.
- **Android FCM-BG fetch is best-effort.** No DI / no 401-refresh in the
  isolate; if the access token is stale the ring falls back to voice, but
  `app.dart`'s DI-backed `isVideoCall` still corrects the routing on accept.

---

## 6. The real fix (backend follow-up — not done)

All §3 client fetches exist because the backend never tells Stream the call is
video. If `StreamTokenService.cidForCall` / `StreamVideoService.ring` encoded
the type so Stream's `call.ring` push carried `call_type: "video"` (or a video
flag), **every** path — iOS + Android, ring icon + routing — would be correct
with zero client guesswork, and the §2 helpers would become pure safety nets.

---

## 7. Key files

| File | Role |
|---|---|
| [`call_signaling_service.dart`](../lib/features/chat/repositories/call_signaling_service.dart) | `isVideoCall()`; `_handleStreamIncomingCall` (iOS bridge) |
| [`callkit_event_handler.dart`](../lib/features/chat/repositories/callkit_event_handler.dart) | `_handleAccept` type correction (iOS bg/killed) |
| [`app.dart`](../lib/app.dart) | `_handleNativeCallLaunch` (Android accept routing) |
| [`firebase_notification_provider.dart`](../lib/shared/firebase_services/firebase_notification_provider.dart) | `_fetchIsVideoFromBackend`; FCM-BG `call.ring` (Android) |
| [`video_call_page.dart`](../lib/features/chat/views/video_call_page.dart) | In-call video UI (remote grid + local PiP) |
| `StreamTokenService.java` / `StreamVideoService.java` (backend) | CID minting + Stream ring (the root of §6) |
