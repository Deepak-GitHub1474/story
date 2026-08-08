# 13 — Deploying the backend on Dokploy

> The API is a plain container that listens on 8000 and needs MongoDB and Redis.
> Nothing about the deployment is clever, and that is the point.

## 1. What gets deployed

`backend/Dockerfile` builds a two-stage image: dependencies resolve from
`uv.lock` in the first stage, and the runtime stage carries only the virtualenv
and `app/`. Tests, caches and `.env` never reach the image — see
`backend/.dockerignore`.

The container runs as a non-root user, exposes 8000, and answers
`GET /v1/health/ready` with the state of both dependencies. Dokploy's health
check should point at that path, not at `/v1/health`, because the plain health
endpoint returns 200 even when Mongo is unreachable.

## 2. Two ways to run it

**Application (recommended).** Point Dokploy at this repository, set the build
path to `backend`, and let it use the Dockerfile. Attach a Dokploy-managed
MongoDB and Redis, then put their connection strings in the environment. This
keeps the databases outside the deploy, so a bad release cannot take them with
it.

**Compose.** Use `docker-compose.deploy.yml`, which brings up the API, MongoDB
and Redis together and waits for both to pass their health checks before the API
starts. Simpler to reason about, but the database lifecycle is tied to the stack.

`docker-compose.yml` at the repository root is for local development only. It
starts MongoDB and Redis and nothing else.

## 3. Environment

Production refuses to start when any of these is missing, short, or still
carries a placeholder. This is deliberate: a service that boots with a weak
secret is worse than one that refuses to boot.

| Variable | Notes |
|---|---|
| `API_ENV` | `production` |
| `JWT_SECRET` | 32+ characters, 8+ distinct characters, unlike every other secret |
| `OTP_HMAC_SECRET` | as above |
| `EMAIL_INDEX_KEY` | as above |
| `EMAIL_ENCRYPTION_KEY` | as above |
| `MONGODB_URI` | may not point at localhost |
| `REDIS_URL` | may not point at localhost |
| `CORS_ORIGINS` | comma separated origins, no `*` |
| `COOKIE_SECURE` | `true` |
| `RATE_LIMIT_ENABLED` | `true` |
| `MAIL_PROVIDER` | `smtp`; `console` is refused |
| `SMTP_*`, `MAIL_FROM` | see `.env.example` |
| `STORAGE_PROVIDER` | `r2` once the bucket exists, `local` until then |
| `AI_PROVIDER` | `gemini` with a real key, or `none` to skip every check |

Generate secrets with `make secrets`. Each must differ from the others — the
config compares them and refuses a repeat.

## 4. After the first deploy

- Seed the reference data: categories, communities and interests come from
  `app/db/seed.py` and run on startup, so nothing manual is needed.
- Check `GET /v1/health/ready` returns `mongodb: true, redis: true`.
- Point the app at the deployed URL by building with
  `--dart-define=STORY_API_BASE_URL=https://your-domain/v1`.

## 5. Things that will bite

**Workers and the socket hub.** The container runs two Uvicorn workers. The
realtime hub is per-process, which is why events go through Redis pub/sub rather
than memory — a socket on worker one still receives a message published by
worker two. Raising the worker count is safe. Running several containers is also
safe, for the same reason.

**Storage on `local`.** Files land inside the container and vanish on redeploy.
Fine while nothing depends on them, wrong the moment a real person uploads
anything. Switch `STORAGE_PROVIDER` to `r2` before inviting anyone.

**The AI gate fails closed.** If the provider is unreachable, publishing returns
`503 MODERATION_UNAVAILABLE` and drafts are kept. That is intended — failing open
would publish exactly what the gate exists to stop — but it means a dead provider
stops publishing. Set `AI_PROVIDER=none` to turn the gate off deliberately rather
than leaving it broken.
