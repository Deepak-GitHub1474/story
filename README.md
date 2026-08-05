# STORY

Anonymous long-form storytelling with an encrypted private vault.

Full specification lives in [`docs/`](docs/). Read [`docs/00-product-overview.md`](docs/00-product-overview.md) first.

## Status

| Piece | State |
|---|---|
| Backend — foundations + onboarding | Working, 146 tests |
| Flutter app — onboarding | Working, 19 tests |
| Web (Next.js) | Not started — begins after the app is finalized |
| AI sanity layer | Specified in [`docs/12-ai-layer.md`](docs/12-ai-layer.md), not built |
| Vault | Specified in [`docs/05-security-and-crypto.md`](docs/05-security-and-crypto.md), not built |

## Prerequisites

- Python 3.13 via [uv](https://docs.astral.sh/uv/)
- Flutter 3.44+
- MongoDB 8 and Redis 7 running locally

## Local services

```bash
make services-up      # start mongod and redis
make services-status  # confirm both answer a real ping
make services-down
```

## Backend

```bash
make backend-setup    # uv sync + copy .env.example to .env
make backend-dev      # uvicorn on http://127.0.0.1:9000
make backend-test
make backend-check    # ruff + pytest
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
make app-setup
make app-test         # unit tests plus live tests against a running backend
make app-run
```

The API base URL is compiled in and overridable:

```bash
flutter run --dart-define=STORY_API_BASE_URL=http://10.0.2.2:9000/v1
```

Use `10.0.2.2` for the Android emulator and `127.0.0.1` for the iOS simulator.

## Everything

```bash
make check
```

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
