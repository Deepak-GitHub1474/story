# Voice calling

> 1:1 voice between people who already have an accepted chat. Signaling reuses
> the existing socket; the only genuinely new parts are a media engine, a relay
> and two screens.

## Decisions

**Voice only.** Faces identify people faster than voices do, and 720p video is
roughly 46× the bandwidth of voice on our own egress (~1.35 GB vs ~29 MB per
relayed hour). Video stays out, and the section below keeps the door open.

**Only between accepted conversations.** A voice is recognisable to anyone who
knows you, so calling is held to the bar chat already uses. No new trust model,
no new machinery — the rule is already enforced in one place. The first call an
account places shows a one-time notice saying exactly that.

**No system dialer integration.** Android's `ConnectionService` would put STORY
calls in the system call log, where anyone holding the phone can read them. On an
anonymity product that is a leak, not a feature.

**One new package.** `flutter_webrtc` binds libwebrtc — the same media engine
inside Chrome, Meet, Signal and WhatsApp. The alternative is writing an Opus
codec, an echo canceller and an ICE stack; the hand-rolled path still ships
libwebrtc, just with glue we maintain forever.

## What it reuses

| Piece | Where it already lived |
|---|---|
| Authenticated socket, cross-instance fanout | `app/realtime/hub.py`, `bus.py` |
| Presence — can they be rung now | `hub.is_online(user_id)` |
| Waking a closed phone | `push_fcm.py`, data-only, `priority: high` |
| Who may contact whom | accepted `chat_conversations` |
| Native channels | `MainActivity.kt` |

## Signaling

Six message types over the existing `/ws`, each carrying `call_id`.

| Type | Direction | Payload |
|---|---|---|
| `call.offer` | caller → callee | `conversation_id`, `media`, `sdp` |
| `call.answer` | callee → caller | `sdp` |
| `call.ice` | both | `candidate` |
| `call.update` | both | `media`, `muted` |
| `call.end` | both | `reason` |
| `call.state` | server → client | `state` |

`reason` ∈ `hangup`, `declined`, `busy`, `timeout`, `failed`.
`state` ∈ `ringing`, `offline`, `timeout`.

Ringing state lives in Redis with a TTL, never MongoDB — a call that never
connected should not outlive a restart.

## Waking a closed phone

The push is **data-only**, with no `notification` block. A `notification` block
makes FCM draw the banner itself and hand control over only after a tap, which is
too late to ring. The app draws its own full-screen intent instead.

Two Android facts that cost real debugging time:

- **Notification channels are immutable after creation.** Sound, vibration and importance are frozen at registration; changing them needs a new channel id. That is why the ids carry a `_v2` suffix.
- **`MODE_IN_COMMUNICATION` must be set** or the hardware echo canceller never runs, and the call routes to the loudspeaker.

## NAT, and an honest latency problem

Most calls connect phone-to-phone. Symmetric and carrier-grade NAT are common on
mobile, so a minority relay through coturn — free software, no vendor, no
per-minute fee, ~29 MB per call-hour of our own egress.

The API runs in `eu-north-1`. Measured round trip from India is **~150 ms**.

| Path | One-way mouth-to-ear | Feel |
|---|---|---|
| Peer-to-peer, two Indian phones | ~100 ms | transparent |
| Relayed via Stockholm | ~210 ms | noticeable; people talk over each other |

ITU-T G.114 puts the transparent ceiling at 150 ms one-way. The relayed minority
is over it. **Accepted for v1 and instrumented rather than guessed** — every call
records whether it relayed, so buying a relay in `ap-south-1` gets decided by a
number.

Relay setup and ports are in [operations](03-operations.md).

## History and retention

**One row per participant per call.** Two people can hold different retention
settings, and one shared row cannot expire at two different times. Deleting your
copy must not touch theirs.

Deletion is real deletion — `delete_many`, never a flag. A call row has no bytes
in object storage behind it, so erasing the row erases the record.

| Action | Endpoint |
|---|---|
| One | `DELETE /v1/calls/{call_id}` |
| Selected / all | `POST /v1/calls/delete` |

Every one scopes to `owner_id` from the token; no endpoint reaches another
account's history.

Retention is `expires_at`, stamped at insert from the owner's setting — 24 hours,
7 days, 30 days (default), or keep forever. **Changing the setting restamps
existing rows**, so shortening it takes effect on history already recorded. That
is what a person expects from a privacy control; the alternative silently keeps
old rows under the old rule. An hourly sweeper deletes what expired.

## Keeping video a later addition

Three commitments, all free today. Breaking any one turns video from an addition
into surgery.

1. **`media` is always a list**, in every message and every stored row. Video is `["audio","video"]` — never an `is_audio` boolean, never a second endpoint.
2. **Renegotiation works from day one.** A mid-call re-offer *is* the audio→video upgrade mechanism.
3. **`call.update` ships immediately**, carrying mute today. Video becomes a new payload on an existing message, not a new mechanism.

Deliberately not done in advance: pre-adding inactive video transceivers, a
camera preview behind a flag, or a "media kind" strategy class. Those cost
complexity now for a feature that may never come.

## Not built

| Not built | Why |
|---|---|
| Group calls | needs an SFU — a second server and a different cost model |
| Call recording | storage, legal exposure, and an anonymity disaster |
| System call log entry | identifies the app to anyone holding the phone |
| CallKit / PushKit | iOS is scaffolded but has never shipped a build |
| Custom DSP | libwebrtc's echo canceller is better than one we would write |
| Multi-region TURN | buy it when the measurement says to, not before |
