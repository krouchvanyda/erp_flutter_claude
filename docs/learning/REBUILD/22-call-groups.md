# Step 6.3c — Call: group calls

> ← Previous: [21-call-reconnecting.md](21-call-reconnecting.md) · Next: [23-call-line.md](23-call-line.md) → · Roadmap: [README.md](README.md)

```
6.3a sounds ✅ · 6.3b reconnecting ✅
6.3c group calls     who is calling · who is in · voice row · video grid   ← this lesson
6.3d call line in the chat
```

## 1. Why

A group 📞 already worked in 6.1 at the **signalling** level: the server rings
every member, and the bloc follows the group rules (others keep ringing when
one accepts, one leaving doesn't end the call). What was missing is the
**screen**: with 2+ people, "Jane Doe" and one full-screen video don't fit.

This step teaches:

- **Ids → names in one place.** Stream knows only user ids; the chat knows
  names. `app/` builds a `members` map once and hands it to the call.
- **A list, not a flag.** "Is the other person here?" (`bool`) becomes "who is
  here?" (`List<String>`). 1-to-1 is just the list with one id.
- **One layout per count** (1 · 2 · 3–4), decided with a `switch`.

## 2. Picture

```
Incoming (group)        Group voice call              Group video call (3–4)
┌──────────────────┐  ┌──────────────────────────┐  ┌───────────┬───────────┐
│      (TE)        │  │          (TE)            │  │   Dara    │   Jane    │
│    Team ERP      │  │        Team ERP          │  │ (camera)  │ (photo)   │
│ 📞 Group voice   │  │    📞 Group voice call   │  ├───────────┼───────────┤
│ Dara is calling… │  │          01:35           │  │   Sok     │   Bin     │
│                  │  │ (DS) (JD) (SV) (BL) (+2) │  │ 🎙̸ Sok    │           │
│ (⛔)       (📞)  │  │ Dara Jane Sok  Bin       │  └───────────┴───────────┘
└──────────────────┘  │  (🎙) (🔊)   (⛔)        │   my camera: small, top right
                      └──────────────────────────┘
```

| Who else is in the media | Video layout |
|---|---|
| 0 | the call's photo (waiting) |
| 1 | full screen (as in 6.2) |
| 2 | two rows |
| 3–4 (more → the first 4) | 2 × 2 grid, name pill (+ 🎙̸ if muted) |

### Files

```
lib/app/call_peer_of.dart                 NEW  ConversationModel → CallPeer (+ every member)
lib/app/app_di.dart · auth_gate.dart      use callPeerOf (incoming + outgoing)
lib/features/call/
├── model/call_peer.dart                  + CallMember {name, avatarUrl, firstName} · members map
├── repository/call_media.dart            peerPresent (bool) → peers (List<String> user ids)
├── viewmodel/call/                       InCall + others; timer from the FIRST person
├── widgets/call_status_text.dart         "Dara is calling…" · "Waiting for others…"
├── widgets/call_participants_row.dart    NEW  group voice: faces + first names, "+N"
├── widgets/call_video_tile.dart          NEW  one person: camera or photo, name pill
├── widgets/call_video_view.dart          1 · 2 · 2×2 layouts
└── view/call_page.dart                   + the row under the header (group voice)
```

## 3. Code

### One map of names, built in `app/`

```dart
CallPeer callPeerOf(ConversationModel c, String? myId) => CallPeer(
  name: c.title(myId), avatarUrl: …, isGroup: c.isGroup,
  members: {for (final m in c.members) m.userId: CallMember(name: m.displayName, avatarUrl: …)},
);
```

Used by both the 📞 launcher (outgoing) and `loadPeer` (incoming). So a tile
can always say `peer.member(p.userId).firstName`.

### Who is in the media: a sorted list

```dart
c.state.valueStream
    .map((s) => {for (final p in s.otherParticipants) p.userId}.toList()..sort())
    .distinct(const ListEquality<String>().equals)    // same people → no event
```

The `{…}` set removes duplicates (one person on two devices). `sort` +
`ListEquality` means "same people in another order" is not a change.

### The bloc: first person starts the timer

```dart
if (ids.isNotEmpty) {
  emit(s.copyWith(connectedAt: s.connectedAt ?? _now(), peerAway: false, others: ids));
} else if (s.connectedAt != null) {
  emit(s.copyWith(peerAway: true, others: const []));
}
```

A second person joining keeps `connectedAt`. One person leaving while others
stay is NOT "away". Only "nobody left" is, and for a group the text is
"Waiting for others…" (the server ends it when the last one really leaves).

### Name clash: `CallMember`

`stream_video_flutter` also exports a `CallMember`. The two files that import
both say `hide CallMember`, so "ours" is the one used.

## 4. 🤔 Why like this? (other ways)

| Choice we made | Other way | Why we didn't pick the other way |
|---|---|---|
| `members` map from the chat | Give Stream our names (`User.regular(name:)`) | Only MY name goes to Stream; we'd still need everyone else's. And the chat already has them, photos too. |
| Who is IN = Stream's participants | Our backend's `participants` statuses | Stream knows who really has media; the backend knows who accepted (they can differ for a second, or after a network drop). |
| Max 4 tiles | All tiles, scrolling | A phone screen can't show more than 4 cameras usefully; Stream puts the speaker first. |
| Row of faces for voice | Nothing (just the group photo) | You want to know who you're talking to. |

## 5. Try it

```bash
flutter test                                    # 282 tests → All tests passed!
flutter run --flavor dev -t lib/main_dev.dart   # THREE phones in one group
```

1. A 📞 in the group → B and C: **"A is calling…"** under the group name.
2. B accepts → A and B talk (timer starts). C still rings. C accepts → a third
   face in the row; the timer doesn't restart.
3. 🎥 in the group with 3 people → two rows; with 4 → a 2 × 2 grid with names.
4. C hangs up → the call goes on for A and B. A (the caller) hangs up → it ends
   for everyone.

## 6. Check yourself

1. Why does `app/` build the `members` map, not the call feature?
2. Why are the participant ids sorted before `distinct`?
3. A second person joins. Why doesn't the timer restart?
4. In a group call one person leaves the media. Why isn't that "away"?

<details><summary>Answers</summary>

1. The names live in the chat feature; the call feature must not import chat.
   `app/` may import both.
2. So "the same people in a different order" is equal → no needless
   rebuild / event.
3. `connectedAt: s.connectedAt ?? _now()` only sets it the first time.
4. Others are still talking. "Away" only means "nobody else is here"; the
   server ends the call when the last callee leaves.

</details>
