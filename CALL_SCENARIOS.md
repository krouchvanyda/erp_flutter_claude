# Call scenarios (18)

What each call scenario is and what you should see. Full test steps and results:
[REAL_DEVICE_TESTS.md](REAL_DEVICE_TESTS.md).

**Status** comes from reading the code on 2026-11-18, not from phone tests:
✅ in the code · ⚠️ partly there, or not checked · ❌ missing.

| # | Scenario | Should see | Status |
|---|---|---|---|
| 1 | Call while the app is open | Rings → Accept → talk → "📞 Voice call · 0:10" saved | ✅ |
| 2 | App in the background | Rings; Accept / Decline / cancel all work; Decline closes the caller in about 0.5 s | ✅ |
| 3 | App killed (cleared from Recents) | Still rings; one tap on Accept → in call | ✅ |
| 4 | In a call, then the screen locks | Voice keeps working; "Ongoing voice call" notification with Hang up | ⚠️ relies on Stream SDK's ongoing-call notification |
| 5 | Background + locked | Rings on the lock screen → Accept → call screen at once (no chats flash) | ✅ |
| 6 | Killed + locked | Rings on the lock screen → call screen straight away | ✅ |
| 7 | Call sounds | "Calling…" is silent → "Ringing…" plays the ringback → beep on connect → beep on end (see [Call sounds](#call-sounds)) | ✅ done 2026-11-18 |
| 8 | Bad network | "Reconnecting…" → voice comes back; ends after 30 s if the network doesn't return | ❌ no "Reconnecting…" label, no 30 s end |
| 9 | Other side ends while I'm in the background | My call stops, no stuck call screen | ✅ |
| 10 | Callee offline | "Calling…" only → "No answer" at 30 s + "Missed voice call" | ⚠️ timeout is 60 s, not 30 s; unanswered call saved as "Declined" (bug) |
| 11 | Busy (already in a call) | The second caller gets "Busy in another call" | ✅ |
| 12 | Video call | Camera full screen; Camera / Flip / Mute / Speaker work | ✅ |
| 13 | Caller cancels while it rings | Ringing stops at once; caller sees "Cancelled call", callee sees "Missed voice call" | ⚠️ no "Cancelled call" text for the caller |
| 14 | App swiped away during a call | The call ends on both sides | ⚠️ not checked |
| 15 | Start a call while another one rings for me | "End call with A and start a new one with B?" OK → A gets "Busy", B rings | ❌ dialog not built |
| 16 | Switch voice → video | My camera turns on; the other side switches to video with its camera off | ❌ not built |
| 17 | Group call | Everyone rings; Accept joins; grid of people; the banner count updates | ✅ |
| 18 | Two users call each other at once | Both see "Busy in another call"; nothing gets stuck; the next call works | ⚠️ only general busy handling |

## Call sounds

Like a real phone: the caller hears nothing until the other phone actually rings.

| Moment | Caller's screen | Caller hears | Callee hears |
|---|---|---|---|
| Call placed, callee's phone not ringing yet | **Calling…** | silence | — |
| Callee's phone rings | **Ringing…** | "tuut… tuut" ringback (repeats) | ringtone (repeats) if the app is open; the native ring if it's in the background or killed |
| Call connects | timer starts | short rising double beep | short rising double beep |
| Call ends, is declined, isn't answered, or is cancelled (even during "Calling…") | closes | short falling beep | short falling beep |

How "Ringing…" works: when the incoming call shows, the callee's app sends
`POST /api/v1/chats/calls/{id}/ringing` once. The backend relays `call.ringing` to
the caller, whose screen switches to "Ringing…" and starts the ringback.

Things to know:
- If the callee is offline or the app is killed with only the native ring, the
  report is sent only when their app runs, so the caller may stay on a silent
  "Calling…" until then (scenario 10).
- In-app sounds never change the call's audio settings, so they can't mute the call.
- Sound files: `assets/sounds/` (`call_ringback.wav`, `call_ringtone.wav`,
  `call_connected.wav`, `call_ended.wav`). Replace them with the same names to
  change the sounds.
