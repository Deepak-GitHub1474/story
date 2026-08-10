# STORY

Anonymous long-form storytelling with an encrypted private vault.

Full specification lives in [`docs/`](docs/). Read [`docs/00-product-overview.md`](docs/00-product-overview.md) first.

## Status

| Piece | State |
|---|---|
| Backend | Working, 800 tests |
| Flutter app | Working, 168 tests |
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
├── docs/       The specification
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
