<p align="center">
  <img src="docs/screenshots/hero.webp" alt="STORY — anonymous long-form writing, an end-to-end encrypted vault, and chat the server holds no key to" width="900">
</p>

# STORY

Anonymous long-form storytelling with an encrypted private vault.

Full specification lives in [`docs/`](docs/). Read [`docs/00-product-overview.md`](docs/00-product-overview.md) first.

## Download the app

**[⬇ Get the latest APK](https://github.com/Deepak-GitHub1474/story/releases/latest)** — or browse [all releases](https://github.com/Deepak-GitHub1474/story/releases).

| | |
|---|---|
| File | `story.apk`, 27.4 MB |
| Requires | Android 7.0 or newer (`minSdk 24`, `targetSdk 36`) |
| Built for | `arm64-v8a` — every phone shipped since about 2015 |
| Signed with | a real release key, not the debug key |

The APK is attached to a GitHub Release, not committed to the repository. Release
assets live in separate storage, so cloning this repo never downloads it and no
push rebuilds it.

Android will warn about installing outside the Play Store. If an older build is
already on the phone and the install is refused, uninstall it first — Android
refuses to replace an app that was signed with a different key.

Build it yourself instead:

```bash
cd app && make apk-release
```

## The app, screen by screen

### Getting in

A username, a password, and nothing else. No email is required to sign up, no
phone number, no real name.

| Sign in | Create account | Pick what you are into |
|---|---|---|
| <img src="docs/screenshots/signin.webp" width="240"> | <img src="docs/screenshots/signup.webp" width="240"> | <img src="docs/screenshots/interests.webp" width="240"> |
| Your space. Your story. Always private. | "Pick a name nobody can trace back to you." | Up to 12 interests shape the feed. Nobody else can see the choices. |

### Reading and writing

| Feed | A story | The composer |
|---|---|---|
| <img src="docs/screenshots/feed.webp" width="240"> | <img src="docs/screenshots/story.webp" width="240"> | <img src="docs/screenshots/composer.webp" width="240"> |
| Long-form posts, expanded in place. | Reactions are the six the product allows, and a comment box that says "Say something kind". | Drafts save as you type. The two icons in the bar are the AI draft and polish helpers. |

### Writing with AI

Two assistants sit in the composer bar. Both are opt-in — nothing runs unless you
tap it — and both are rate limited per account.

**Write it with AI** takes a subject and a brief and returns a finished story,
title and all. You read it before it goes anywhere: the sheet is called *Read it
first*, and the only ways out are **Use this** and **Ask for changes**. A change
request rewrites the whole piece and leaves a **Back to the one before** link, so
no revision is a one-way door. Ten drafts an hour.

| Describe it | It writes | Ask for changes | The rewrite |
|---|---|---|---|
| <img src="docs/screenshots/ai-write-brief.webp" width="200"> | <img src="docs/screenshots/ai-draft.webp" width="200"> | <img src="docs/screenshots/ai-changes.webp" width="200"> | <img src="docs/screenshots/ai-rewritten.webp" width="200"> |

**Ask for a tidier version** is the opposite job — it edits what you already
wrote. The sheet states the boundary in its own words: *"It stays your story, in
your words — nothing is added and nothing is softened."* Four presets cover most
asks — fix the spelling and grammar, make it shorter, break it into paragraphs,
keep it simple and plain — or type your own. Each pass builds on the last, and
the result is a proposal: **Keep mine** throws it away, **Use this version**
accepts it. Twenty passes an hour.

| The ask | The proposal |
|---|---|
| <img src="docs/screenshots/ai-polish.webp" width="240"> | <img src="docs/screenshots/ai-polished.webp" width="240"> |

### The gate every story passes

Publishing runs one model call before anything becomes visible, and it decides
five separate things. They are separate on purpose — different failure costs,
different appeal paths. Full rules in [`docs/12-ai-layer.md`](docs/12-ai-layer.md).

| Check | What it asks | May it block? |
|---|---|---|
| **Safety gate** | Does this break one of five named rules? | **Yes** — the only check that can |
| **Fit check** | Is this in the right room? | No — suggests a better one |
| **Exposure check** | Would this identify its own author? | No — warns, and the choice is recorded |
| **Care signal** | Does the author sound at risk? | Never — shows helplines to the author alone |
| **Suggestion** | Which rooms and people fit this person? | Not a gate |

The five blocking rules are named, closed, and all about harm to someone else:
targeted harassment, doxxing, sexual content involving minors, credible threats,
and illegal goods. Everything else publishes. As the block sheet puts it: *"Hard,
dark and painful writing is welcome here."* Sadness is not a rule violation.

| Blocked | Routed |
|---|---|
| <img src="docs/screenshots/ai-blocked.webp" width="240"> | <img src="docs/screenshots/ai-suggestion.webp" width="240"> |

The gate **fails closed**. If the model is unreachable or answers with something
unreadable, publishing stops and the story stays a saved draft — the API returns
`MODERATION_UNAVAILABLE` rather than letting anything through unchecked.

All model access goes through one port (`backend/app/ports/ai.py`), with a Gemini
adapter behind it and an `AI_PROVIDER=none` setting that disables the layer entirely. No
model ranks a feed, and no model sees a private story, a draft, or anything in
the vault.

### Finding people

| Communities | Inside one | Search | Someone's profile |
|---|---|---|---|
| <img src="docs/screenshots/communities.webp" width="200"> | <img src="docs/screenshots/community.webp" width="200"> | <img src="docs/screenshots/search.webp" width="200"> | <img src="docs/screenshots/public-profile.webp" width="200"> |

The 46 communities are organised by feeling rather than topic — `quiet-grief`,
`invisible-work`, `nine-month-gap`, `imposter-hours`, `first-year-without`.
Search covers accounts, communities, and public stories only; private and draft
stories never appear in it.

### The vault

Photos, videos, and PDFs, encrypted on the device before they leave it. The
server stores ciphertext and never sees a filename or a key.

| A new vault | Locked | Sealing a file | Open |
|---|---|---|---|
| <img src="docs/screenshots/vault-new.webp" width="200"> | <img src="docs/screenshots/vault-locked.webp" width="200"> | <img src="docs/screenshots/vault-seal.webp" width="200"> | <img src="docs/screenshots/vault-open.webp" width="200"> |

One account can hold several vaults. Reuse a passcode and the new vault opens
alongside the others; type a different one and it becomes separate, with its own
key that nothing else can open. Forgetting a passcode is final — deleting that
vault is the only way back, and its files go with it.

A **sealed** file appears in no tab and no listing. It is found only by typing
its secret word back, exactly, capitals included.

Each account gets **100 MB**, set by `VAULT_QUOTA_BYTES` and enforced when space
is reserved, again when the bytes land, and hourly by a sweeper that erases
uploads nobody finished. See [`docs/15-storage-security-and-scale.md`](docs/15-storage-security-and-scale.md).

### Chat and notifications

| Notifications | Conversations | A thread |
|---|---|---|
| <img src="docs/screenshots/notifications.webp" width="240"> | <img src="docs/screenshots/chats.webp" width="240"> | <img src="docs/screenshots/chat.webp" width="240"> |

Chat is end-to-end encrypted. The server stores ciphertext and cannot read any of it —
which is why the conversation list shows no message previews. Message someone
you follow; if you follow each other it opens straight away, otherwise it waits
in their requests.

### Your account

| You | Settings | Active sessions | Leaving |
|---|---|---|---|
| <img src="docs/screenshots/profile.webp" width="200"> | <img src="docs/screenshots/settings.webp" width="200"> | <img src="docs/screenshots/sessions.webp" width="200"> | <img src="docs/screenshots/leaving.webp" width="200"> |

Every signed-in device is listed and can be revoked, and revoking signs that
device out within a minute. Deleting an account is scheduled 14 days out and can
be cancelled by signing in before then; after that everything is erased and the
username is released.

> Screens captured on a Pixel 7 Pro emulator against a local API with seeded
> content. The vault sets `FLAG_SECURE`, so Android blocks screenshots of it on
> a real install — those four frames were taken with that flag disabled in a
> local build.

## Status

| Piece | State |
|---|---|
| Backend | Working, 1,000 tests |
| Flutter app | Working, 549 tests |
| Vault — encrypted files | Working, see [`docs/05-security-and-crypto.md`](docs/05-security-and-crypto.md) |
| Chat — end-to-end encrypted | Working |
| AI sanity layer | Working, see [`docs/12-ai-layer.md`](docs/12-ai-layer.md) |
| Web + admin (Next.js) | Behind the app; feature parity incomplete |
| 2FA | Deferred |

## Prerequisites

- Python 3.13 via [uv](https://docs.astral.sh/uv/)
- Flutter 3.44+
- MongoDB 8 and Redis 7 running locally

## Layout

Every project is self-contained. Each owns its `Makefile`, its container files,
its `.env.example` and its own dependencies. The repository root carries no
build or tooling configuration — run `make help` inside the project you are
working on.

```
story/
├── backend/    FastAPI. Dockerfile, docker-compose.yml, Makefile.
├── app/        Flutter. Makefile.
├── web/        Next.js, users, :3100. pnpm scripts.
├── admin/      Next.js, staff, :3200. pnpm scripts.
├── docs/       The specification, plus screenshots/
└── README.md
```

## Backend

```bash
cd backend
make services-up   # start mongod and redis (or: make docker-up)
make setup         # uv sync + copy .env.example to .env
make dev           # uvicorn on http://127.0.0.1:9000
make test
make check         # ruff + pytest
```

Verify it is alive:

```bash
curl -s http://127.0.0.1:9000/v1/health/ready
```

`/v1/health` answers "is the process alive". `/v1/health/ready` issues a real `ping` to
MongoDB and a real `PING` to Redis, and returns 503 naming the dependency that is down.

Interactive API docs at http://127.0.0.1:9000/docs while `API_ENV=local`.

## App

```bash
cd app
make setup
make check                                  # analyzer + unit tests
make run
make e2e                                    # boots ../backend, runs the full suite
```

The API base URL is compiled in and overridable:

```bash
make run API_URL=http://10.0.2.2:9000/v1
make apk API_URL=http://192.168.1.38:9000/v1
```

Use `10.0.2.2` for the Android emulator and `127.0.0.1` for the iOS simulator.
A physical Android device over USB needs `adb reverse tcp:9000 tcp:9000`, or a
LAN address compiled in with `make apk`.

## Web

Two separate Next.js apps, one backend. Admin is never a route inside the user app —
it needs a different origin so it can be IP-restricted at the edge.

```bash
cd web   && pnpm install && cp .env.example .env && pnpm dev -p 3100   # users
cd admin && pnpm install && cp .env.example .env && pnpm dev -p 3200   # staff
```

Give an account staff access:

```bash
cd backend
make promote USER=quiet_fox ROLE=moderator   # queue only
make promote USER=quiet_fox ROLE=admin       # queue, accounts, audit
```

Design tokens live in three hand-maintained files — `app/lib/theme/tokens.dart`,
`web/src/styles/tokens.css` and `admin/src/styles/tokens.css`. There is no
generator and no shared source. Changing a colour means touching all three; the
CSS files carry a banner saying so.

## Secrets

Four values are real secrets: `JWT_SECRET`, `EMAIL_INDEX_KEY`,
`EMAIL_ENCRYPTION_KEY`, `OTP_HMAC_SECRET`. They live in `backend/.env`, which is
gitignored. `backend/.env.example` carries placeholders only.

```bash
cd backend && make secrets   # generate strong values into backend/.env
```

Production refuses to boot if any secret is short, low-entropy, reused across
two settings, or still contains a placeholder marker — and equally if rate
limiting is off, cookies are insecure, CORS holds a wildcard, the console mailer
is selected, or the database points at localhost. `backend/tests/test_config.py`
covers each rule.

Rate limiting is **on** by default, including locally, so development behaves
like production. `app/`'s `make e2e` is the one place it is disabled, because
the integration suite creates dozens of accounts in seconds.

## Reading the logs

Every failure logs one line carrying the four facts needed to find it:

```
error  request_failed  time=2026-08-05T05:04:10.174Z  error='That username is already taken.'
                       route=/v1/auth/signup  method=POST  status=409  code=USERNAME_TAKEN
                       request_id=req_f8651929875f643b
```

`request_id` is returned on every response as the `x-request-id` header, so a user-reported
problem maps to exactly one log line. Unhandled errors add `where=file.py:line`.

Values are redacted by default — a field is logged only if its key is allowlisted in
`backend/app/logging.py`. Passwords, tokens, and key material can never reach the log store.

## Conventions

Binding on all code in this repository, see [`docs/02-repo-structure-and-conventions.md`](docs/02-repo-structure-and-conventions.md) §5a:

- **No comments and no docstrings in source.** Reasoning lives in `docs/`.
- **One response shape.** `{success, message, data}` on every backend response; `Result<T>` on every client call.
- **Custom components only.** No UI kits, no icon packages.
- **No dependency without a reason** that could not be met in ~50 lines.
- **No production code without a failing test first.**
