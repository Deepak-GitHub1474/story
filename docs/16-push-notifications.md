# 16 — Push Notifications

> Built and deployed. A notification row already existed for every social event
> in the system; this layer is only a transport that carries the ones a reader
> would otherwise miss, to a phone that is not currently open.

Read this before touching `backend/app/workers/push.py`, the `push_tokens`
collection, or the send path in `notifications/service.py`.

## 1. What this layer is, and is not

**Is:** a delivery mechanism for `notifications` rows that already exist, gated
on an explicit opt-in, and suppressed whenever the reader is already connected.

**Is not:** a second source of notification truth, a re-engagement tool, or a
campaign system. Nothing here originates a notification. If a row is not in
`notifications`, no push can exist for it, and deleting the row through
`withdraw()` removes the reason to send.

That constraint is what keeps the feature honest. A push cannot say something
the in-app badge does not already say, so there is no path by which push becomes
a channel for prompts nobody asked for. `PUSH_PROVIDER=none` removes the
transport and changes nothing else.

## 2. The lease

A send has three ways to fail: two workers claiming the same row, FCM refusing
transiently, and the process dying mid-send. A boolean `pushed` flag survives
none of them cleanly — stamp before sending and a crash loses the notification,
stamp after and a race sends it twice.

One field solves all three. `push_after` is a due-time, not a flag:

- written as `created_at`, so the row is due immediately
- claiming it atomically moves it `PUSH_LEASE_SECONDS` into the future
- success unsets it and stamps `pushed_at`
- failure does nothing — the lease simply expires and the row becomes due again

The claim is a single `findOneAndUpdate` on `{_id, push_after: {$lte: now}}`,
so two callers cannot both win it. A crash needs no recovery path at all: the
lease was never renewed, so the sweeper picks the row up on its next pass.

**Rows written before this feature existed are excluded for free.** MongoDB
compares within type brackets, so `{$lte: <date>}` never matches a missing
field. Older notifications have no `push_after` and can never become due, which
is why deploying this did not flood every user with their backlog.

`push_tries` bounds the retry. Past `PUSH_MAX_TRIES` the row is abandoned rather
than retried forever — a permanently malformed notification must not occupy the
sweeper indefinitely.

## 3. Two paths, one claim

Realtime and durability are usually a trade. Here they are not, because both
paths go through the same claim.

- **Fast path.** `notify()` fires `deliver_now` as a detached task. Nothing in
  the request awaits it, so a like is never slowed by FCM.
- **Sweeper.** `sweep_due` runs every 30 s from the scheduler and picks up
  anything still due.

The fast path delivers in the normal case. The sweeper exists only for the
cases the fast path lost. Neither can duplicate the other, because whichever
arrives second finds the row already leased.

The sweeper runs under `RUN_BACKGROUND_JOBS`, which is single-replica by
convention. That is why a plain `find` is safe here and no distributed lock is
needed.

## 4. Who does not get pushed

Four checks, in order, each of which settles the row rather than retrying it:

1. **Tries exhausted** — abandoned.
2. **Reader is connected.** `redis.get(keys.presence(user_id))` is the same
   cross-replica presence the chat online dot uses. A live socket means the
   badge already moved, so a push would be the second copy of one event.
3. **`prefs.notify_push` is false.** Default `False` in `DEFAULT_PREFS` —
   silence is the state a reader gets without asking for anything.
4. **No registered device.**

Only the first is a failure. The rest are correct outcomes, which is why they
unset `push_after` instead of leaving the row due.

## 5. Dead tokens

FCM answers `UNREGISTERED` for a token belonging to an uninstalled app. The
adapter sorts every response into `delivered` / `stale` / `retry`, and `stale`
tokens are deleted from `push_tokens` in the same pass.

This is the [07](07-data-model.md) rule about `media` applied again: a row that
stands for something reachable must stop existing when it stops being
reachable. Without it the collection grows forever with tokens that can never
receive anything, and every future send wastes a request on each.

## 6. What Google can see

FCM relays every message, so whatever is in the payload is visible to Google.
The chosen copy is the actor's display name and the action — `Deepak` /
`liked your story`.

Two things bound that exposure. Display names are pseudonyms already shown
publicly across the app, so the notification reveals nothing the profile does
not. And **direct messages never carry content**: chat is end-to-end encrypted,
the server holds only ciphertext, so a message push can only ever say
`New message`. The privacy property is structural, not a policy.

The payload always carries `data` alongside the text — `notification_id`,
`kind`, `target_id`, `thread`. That is deliberate. Moving to data-only pushes,
where the device fetches and renders the notification itself and Google sees
only an opaque id, becomes a change to what the server *stops* sending. No
schema change, no API change, no migration. The cost of that move is a
background handler whose delivery Android may throttle, which is why it was not
taken first.

## 7. The icon

Android discards colour from the notification small icon and uses only the
alpha channel, tinted with `notification_accent`. A colour logo renders as a
white blob. `ic_notification` is therefore the bloom as a monochrome silhouette,
shipped at all five densities.

FCM's v1 API has no `large_icon` field, so the full-colour mark cannot appear
in a server-sent notification at all. That needs client-rendered notifications
— the same change described in §6.

## 8. Cost

FCM is free with no paid tier. The only spend is the EC2 bandwidth for the
send requests themselves, which is negligible: a push is a few hundred bytes,
and delivery to the device is Google's egress, not ours.
