# Operations

> The API is a plain container listening on 8000 that needs MongoDB and Redis.
> Nothing about the deployment is clever, and that is the point.

## Deploying

`backend/Dockerfile` builds a two-stage image: dependencies resolve from
`uv.lock`, and the runtime stage carries only the virtualenv and `app/`. Tests,
caches and `.env` never reach it.

The container runs as a non-root user and answers `GET /v1/health/ready` with the
state of both dependencies. **Point the health check at `/ready`, not
`/v1/health`** — the plain endpoint returns 200 even when Mongo is unreachable.

| File | Purpose |
|---|---|
| `backend/Dockerfile` | the image |
| `backend/docker-compose.yml` | full stack: API + MongoDB + Redis |
| `backend/docker-compose.dev.yml` | local databases only, never deployed |

**Use a Dokploy Application, not Compose.** Point it at the repo, Build Path
`backend`, Build Type `Dockerfile`, then create Dokploy-managed MongoDB and Redis
as separate services. This keeps the databases outside the deploy, so a bad
release, a rollback or a deleted application cannot take the data with it —
exactly the failure Compose invites.

### Environment

Production refuses to start when any of these is missing, short, or still a
placeholder. A service that boots with a weak secret is worse than one that
refuses to boot.

| Variable | Notes |
|---|---|
| `API_ENV` | `production` |
| `JWT_SECRET` | 32+ chars, 8+ distinct, unlike every other secret |
| `OTP_HMAC_SECRET`, `EMAIL_INDEX_KEY`, `EMAIL_ENCRYPTION_KEY` | as above |
| `MONGODB_URI`, `REDIS_URL` | may not point at localhost |
| `CORS_ORIGINS` | comma separated, no `*` |
| `COOKIE_SECURE`, `RATE_LIMIT_ENABLED` | `true` |
| `MAIL_PROVIDER` | `smtp`; `console` is refused |
| `STORAGE_PROVIDER` | `r2` once the bucket exists, `local` until then |
| `AI_PROVIDER` | `gemini` with a real key, or `none` to skip every check |
| `PUSH_PROVIDER` | `fcm` with a service account, or `none` |
| `FCM_SERVICE_ACCOUNT` | the service account JSON on one line |
| `TURN_SHARED_SECRET`, `TURN_URLS` | the voice relay |

`make secrets` generates them. Each must differ from the others; the config
compares them and refuses a repeat.

### After the first deploy

Categories, communities and interests seed on startup. Check `/v1/health/ready`
returns `mongodb: true, redis: true`, then build the app against it with
`--dart-define=STORY_API_BASE_URL=https://your-domain/v1`.

### Things that will bite

**The realtime hub is per-process.** Two Uvicorn workers run, so events go
through Redis pub/sub rather than memory. Raising the worker count, or running
several containers, is safe for that reason.

**`STORAGE_PROVIDER=local` loses files on redeploy** unless a volume is mounted
at `STORAGE_LOCAL_ROOT`, writable by the non-root `story` user or every upload
returns 500. Switch to `r2` before inviting anyone.

**The AI gate fails closed.** An unreachable provider returns
`503 MODERATION_UNAVAILABLE` and keeps the draft. That is intended — failing open
would publish exactly what the gate exists to stop — but a dead provider stops
publishing. Set `AI_PROVIDER=none` to disable it deliberately rather than leaving
it broken.

**Push fails silently, not closed.** A missing `PUSH_PROVIDER` looks perfectly
healthy and notifies nobody. Check for `push_swept` in the logs rather than
assuming.

## The TURN relay

Voice calls connect phone-to-phone where the network allows. Symmetric and
carrier-grade NAT are common on mobile, so a minority relay through coturn.

```bash
cd backend/coturn
TURN_SHARED_SECRET=$(openssl rand -hex 32) TURN_PUBLIC_IP=<elastic-ip> \
  docker compose up -d
```

Put the same secret in the API environment and set `TURN_URLS` to the relay's
public address. The API mints a fresh username and password on every
`POST /v1/calls`, valid five minutes, so nothing long-lived reaches a client.
**The APK is public — a static relay secret compiled into it would be an open
relay for the internet, billed to us.**

| Port | Why |
|---|---|
| `3478/udp`, `3478/tcp` | STUN and TURN |
| `443/tcp` | TURN over TLS, for networks that only allow HTTPS |
| `49152-65535/udp` | where coturn allocates relays |

`network_mode: host` is required; coturn allocates across that whole range and
mapping it through Docker's NAT does not work.

## Storage

**Object keys reveal nothing and are unguessable.** Someone holding every
username must not be able to construct a path to anyone's files.

```
key   = 32 random bytes, hex
path  = <first 2>/<next 2>/<key>        e.g. 4f/a2/4fa2c1...
```

Nothing in the path derives from the username, user id, item id, filename or
upload time. ULIDs are the specific thing to avoid: they encode a timestamp and
sort lexicographically, so one media id makes its neighbours a small search
space. The two-level shard also means **files are not grouped by owner**, so a
directory listing reveals neither who owns what nor how much anyone stored.

**Original filenames never touch storage.** The filename is part of the encrypted
payload. A path must never say `passport.pdf`.

**Quotas are enforced twice**, because once is not enough. At reservation,
`create_item` sums the owner's live items — hidden ones included, or hiding would
be a way around the ceiling. At completion, `complete_item` compares what storage
actually holds against what was reserved; a 2 KB reservation followed by a 20 MB
upload is the whole disk one item at a time, so the bytes are erased.

**An hour later**, `workers/vault_sweep.py` collects reservations nobody
completed — an upload URL is handed out before any bytes move and nothing obliges
the client to return. `VAULT_UPLOAD_GRACE_SECONDS` must stay above
`PRESIGN_UPLOAD_TTL_SECONDS`, or an in-flight upload loses the bytes underneath
it.

**Deleting erases bytes, never just a flag.** A row that stands for something
reachable stops existing when it stops being reachable.

## Push

Push is only a transport for notification rows that already exist. Turning it off
changes nothing a user can see except the phone buzzing.

**`push_after` is a due-time, not a flag.** A boolean `pushed` survives none of
the three failure modes cleanly — stamp before sending and a crash loses the
notification, stamp after and a race sends it twice. Instead: the row is written
due immediately, claiming it atomically pushes the time `PUSH_LEASE_SECONDS`
forward, success unsets it, and failure does nothing so the lease simply expires
and the row becomes due again. The claim is one `findOneAndUpdate`, so two
workers cannot both win it, and a crash needs no recovery path.

Rows written before the feature existed are excluded for free: MongoDB compares
within type brackets, so `{$lte: <date>}` never matches a missing field.

**Two paths, one claim.** `notify()` fires a detached task so no request waits on
FCM; a sweeper every 30 s picks up whatever the fast path lost. Neither
duplicates the other because whichever arrives second finds the row leased.

**Four reasons a push is not sent**, and only the first is a failure: tries
exhausted; the reader has a live socket, so the badge already moved;
`prefs.notify_push` is false, which is the default; no registered device.

**Dead tokens are deleted in the same pass.** FCM answers `UNREGISTERED` for an
uninstalled app; without pruning, the collection grows forever with tokens that
can never receive anything.

**Google sees the payload.** The copy is the actor's display name and the action
— `Deepak` / `liked your story` — and nothing else.

### Firebase

The free Spark plan is enough; FCM has no paid tier. Two files come out of it and
they are not equally sensitive.

- **`google-services.json`** ships inside every APK, so it lives in git. The package name must be exactly `com.story.story_app` — a mismatch fails at runtime with no build error.
- **The service account** is a private key that can push to every user. It belongs in `FCM_SERVICE_ACCOUNT` and nowhere else. Paste it collapsed to one line; `read_service_account` converts literal `\n` back to newlines, which is the usual failure when a PEM is pasted into a panel that stores it verbatim.

Analytics stays off deliberately — it attaches per-install behavioural events to
a platform built on anonymous writing.
