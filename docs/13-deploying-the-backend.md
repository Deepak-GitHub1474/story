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

## 2. Where the container files live

Every deployable owns its own container configuration. The repository root has
none.

| File | Purpose |
|---|---|
| `backend/Dockerfile` | The image. Used by both options below. |
| `backend/docker-compose.yml` | Full deploy stack: API + MongoDB + Redis. |
| `backend/docker-compose.dev.yml` | Local MongoDB + Redis only, no API. |

## 3. Two ways to run it in Dokploy

**Application — use this one.** Create a Dokploy **Application**, point it at
this repository, set **Build Path** to `backend` and **Build Type** to
`Dockerfile`. Then create a Dokploy-managed **MongoDB** and **Redis** as
separate services and put their internal connection strings in the environment.

This is the right choice because the databases sit outside the deploy. A bad
release, a rollback, or a delete of the application cannot take the data with
it — which is exactly the failure that compose invites.

**Compose — only if you want one unit.** Create a Dokploy **Compose** service
with **Compose Path** `backend/docker-compose.yml`. It brings up the API,
MongoDB and Redis together and waits for both to pass their health checks
before the API starts. Simpler to reason about, but the database lifecycle is
tied to the stack, and Dokploy's database backups and metrics do not apply to
containers it did not create.

`backend/docker-compose.dev.yml` is for local development only. Nothing in
Dokploy should ever point at it.

There is no `.dokployignore`. Dokploy clones the whole repository and then
builds from `backend/`, so `app/`, `web/`, `admin/` and `docs/` are fetched and
ignored. That costs a little clone time and nothing else — the Docker build
context is `backend/` alone, filtered by `backend/.dockerignore`, so none of it
reaches the image.

## 4. Environment

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

## 5. After the first deploy

- Seed the reference data: categories, communities and interests come from
  `app/db/seed.py` and run on startup, so nothing manual is needed.
- Check `GET /v1/health/ready` returns `mongodb: true, redis: true`.
- Point the app at the deployed URL by building with
  `--dart-define=STORY_API_BASE_URL=https://your-domain/v1`.

## 6. Things that will bite

**Workers and the socket hub.** The container runs two Uvicorn workers. The
realtime hub is per-process, which is why events go through Redis pub/sub rather
than memory — a socket on worker one still receives a message published by
worker two. Raising the worker count is safe. Running several containers is also
safe, for the same reason.

**Storage on `local`.** Files land inside the container and vanish on redeploy
unless a volume is mounted. Set `STORAGE_LOCAL_ROOT=/srv/storage-data` and mount
a volume there — the compose file already does. The image runs as the non-root
user `story`, so the mount must be writable by it or every upload returns 500.
This is a stopgap either way: switch `STORAGE_PROVIDER` to `r2` before inviting
anyone.

**The AI gate fails closed.** If the provider is unreachable, publishing returns
`503 MODERATION_UNAVAILABLE` and drafts are kept. That is intended — failing open
would publish exactly what the gate exists to stop — but it means a dead provider
stops publishing. Set `AI_PROVIDER=none` to turn the gate off deliberately rather
than leaving it broken.
