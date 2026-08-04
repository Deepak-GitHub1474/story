# 09 — Backend Conventions

FastAPI patterns, in enough detail that two engineers writing two features independently produce code that looks like it was written by one person.

## 1. The ten rules

1. **Routers route. Controllers decide. Nothing else exists.** No service layer, no use-case layer, no manager classes.
2. **The envelope is built in the router, never in a controller.**
3. **Dependencies are `Annotated` aliases.** Adding a parameter is how you opt into a resource, a role, or auth.
4. **Cross-cutting concerns are declarative dependencies**, not middleware and not inline checks.
5. **Every route declares a `response_model`.**
6. **Every route declares an explicit `status_code`.**
7. **Errors are `HTTPException` with a structured `detail`.** No custom exception hierarchy crossing the HTTP boundary.
8. **Controllers take the body positionally and infrastructure keyword-only.**
9. **Every Mongo query has an explicit projection.**
10. **Nothing sensitive reaches a log.** Default-deny redaction.

## 2. Application entrypoint

`app` is a module-level instance in `app/main.py`. Order matters: create, register handlers, mount routers, add middleware.

```python
# app/main.py
settings = get_settings()
logger = structlog.get_logger("story.main")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    configure_logging(settings)
    init_state(app)
    await connect_mongo(app, settings)
    await connect_redis(app, settings)
    await connect_storage(app, settings)
    if settings.ENSURE_INDEXES_ON_BOOT:
        await ensure_indexes(app.state.mongo_db)
    try:
        yield
    finally:
        for name, close in (
            ("storage", disconnect_storage),
            ("redis", disconnect_redis),
            ("mongo", disconnect_mongo),
        ):
            try:
                await close(app)
            except Exception as exc:
                logger.error("shutdown_failed", service=name,
                             reason=f"{type(exc).__name__}: {exc}", exc_info=True)


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan,
    docs_url="/docs" if settings.API_ENV != "production" else None,
    redoc_url=None,
)

register_exception_handlers(app)
app.include_router(api_router, prefix=settings.API_PREFIX)
app.include_router(admin_router)          # separate, not in the public schema

app.add_middleware(RequestIdMiddleware)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["content-type", "authorization", "x-csrf-token",
                   "x-client-version", "idempotency-key"],
)
```

Four deliberate differences from the reference implementation:

**`configure_logging` runs inside `lifespan`, not in a launcher script.** The reference configured logging only in `run.py`, while the Dockerfile started `uvicorn app.main:app` directly — so the formatter never applied in production and every log line came out in uvicorn's default shape. Logging configuration belongs where the app is constructed.

**`API_PREFIX` is actually used.** The reference declared it in settings, documented it in the README, and mounted every router at a bare path. A configuration value that nothing reads is worse than no value, because the next person assumes it works.

**`allow_methods` and `allow_headers` are enumerated, not `["*"]`.** With `allow_credentials=True`, a wildcard is both meaningless per spec and a signal that nobody thought about it.

**`docs_url` is disabled in production.** The schema describes every endpoint including the admin surface's existence. There is no reason to publish it.

## 3. Configuration

One flat `Settings` class, `lru_cache`'d accessor. Required values have no default and fail at import; tunables carry defaults so `.env` stays short.

```python
class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8",
        case_sensitive=False, extra="forbid",
    )

    # --- Application ---
    APP_NAME: str = "Story API"
    APP_VERSION: str
    API_ENV: Literal["local", "staging", "production"]
    API_PREFIX: str = "/v1"
    HOST: str = "127.0.0.1"
    PORT: int = 9000
    CORS_ORIGINS: str

    # --- Data ---
    MONGODB_URI: str
    MONGODB_DB_NAME: str
    REDIS_URL: str
    ENSURE_INDEXES_ON_BOOT: bool = True

    # --- Object storage ---
    S3_ENDPOINT_URL: str
    S3_REGION: str = "auto"
    S3_ACCESS_KEY_ID: str
    S3_SECRET_ACCESS_KEY: str
    S3_BUCKET_VAULT: str
    S3_BUCKET_PUBLIC: str
    PRESIGN_UPLOAD_TTL_SECONDS: int = 900
    PRESIGN_DOWNLOAD_TTL_SECONDS: int = 300

    # --- Auth ---
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_TTL_MINUTES: int = 30
    REFRESH_TOKEN_TTL_DAYS: int = 30
    ARGON2_MEMORY_KIB: int = 65536
    ARGON2_ITERATIONS: int = 3
    ARGON2_PARALLELISM: int = 2

    # --- Cookies ---
    COOKIE_SECURE: bool = True
    COOKIE_DOMAIN: str | None = None
    COOKIE_SAMESITE: Literal["lax", "strict", "none"] = "lax"
    ACCESS_COOKIE_NAME: str = "story_access"
    REFRESH_COOKIE_NAME: str = "story_refresh"
    CSRF_COOKIE_NAME: str = "story_csrf"
    CSRF_HEADER_NAME: str = "x-csrf-token"

    # --- Crypto ---
    EMAIL_INDEX_KEY: str
    OTP_HMAC_SECRET: str
    KMS_KEY_ID: str
    KMS_PROVIDER: Literal["aws", "gcp", "local"] = "aws"

    # --- OTP ---
    OTP_TTL_SECONDS: int = 600
    OTP_FAIL_THRESHOLD: int = 5
    OTP_LOCKOUT_MINUTES: int = 15
    OTP_RESEND_COOLDOWN_SECONDS: int = 30

    # --- Vault ---
    VAULT_QUOTA_BYTES: int = 2 * 1024**3
    VAULT_MAX_ITEM_BYTES: int = 512 * 1024**2
    VAULT_MAX_ITEMS: int = 2000

    # --- Admin ---
    REQUIRE_DUAL_APPROVAL: bool = False
    ADMIN_IP_ALLOWLIST: str = ""
    REVEAL_LINK_TTL_HOURS: int = 24

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    @model_validator(mode="after")
    def enforce_production_invariants(self) -> "Settings":
        if self.API_ENV == "production":
            if not self.COOKIE_SECURE:
                raise ValueError("COOKIE_SECURE must be true in production.")
            if "*" in self.CORS_ORIGINS:
                raise ValueError("CORS_ORIGINS cannot contain a wildcard in production.")
            if len(self.JWT_SECRET) < 32:
                raise ValueError("JWT_SECRET must be at least 32 characters.")
            if self.KMS_PROVIDER == "local":
                raise ValueError("KMS_PROVIDER cannot be local in production.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

Two things worth calling out.

**`extra="forbid"`.** The reference used `extra="ignore"`, which means a typo'd variable name in a deployment environment is silently discarded and the app runs with a default nobody intended. `forbid` turns that into a startup crash, which is the correct time to find out.

**`enforce_production_invariants`.** A production deployment with `COOKIE_SECURE=false` or a wildcard CORS origin should not be possible. Encoding those invariants as a validator means the misconfiguration fails at boot instead of becoming a vulnerability that ships. The reference shipped production URLs over plain HTTP; this validator is the mechanism that would have prevented it.

`.env.example` lists every key with a placeholder, and a CI check compares it against the `Settings` fields so the two cannot drift.

## 4. Dependency injection

Every shared resource is an `Annotated` alias in `app/core/deps.py`. This is the reference project's best structural idea: a route's parameter list *is* its declaration of what it needs.

```python
MongoDatabase = Annotated[AsyncIOMotorDatabase, Depends(get_mongo_db)]
RedisClient   = Annotated[Redis, Depends(get_redis)]
Storage       = Annotated[StorageClient, Depends(get_storage)]
Queue         = Annotated[ArqRedis, Depends(get_queue)]
CurrentClaims = Annotated[AccessClaims, Depends(get_current_claims)]
CurrentUser   = Annotated[dict[str, Any], Depends(get_current_user)]
ClientMeta    = Annotated[ClientContext, Depends(get_client_meta)]
```

`CurrentClaims` is cheap — it verifies the JWT and checks the Redis denylist, with no database read. `CurrentUser` additionally loads the user document and is used only where fresh mutable fields are needed. Most routes want `CurrentClaims`.

`ClientMeta` bundles truncated IP, coarse device fingerprint, and client version, so no controller reaches into `Request` for them.

### Degraded start

Connection failures at startup are recorded, not raised. The app boots and serves `/health` even when MongoDB is down; only routes that actually need the client get a 503. This is the reference's pattern and it is right — a dependency blip during a deploy should not produce a crash loop.

```python
def service_or_503[T](request: Request, client: T | None,
                      error_attr: str, service: str) -> T:
    if client is not None:
        return client
    detail = {"code": "SERVICE_UNAVAILABLE", "service": service,
              "message": f"{service} is temporarily unavailable."}
    raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, detail=detail)
```

A background reconnect task retries every 10 seconds with jitter, so recovery does not require a restart — the reference had no reconnection at all, meaning a transient failure at boot left the process permanently useless.

### Role and step-up dependencies

```python
ROLE_ORDER = {"user": 0, "moderator": 1, "admin": 2, "super_admin": 3}

def require_role(minimum: str) -> Callable:
    async def dependency(claims: CurrentClaims) -> AccessClaims:
        if ROLE_ORDER[claims.role] < ROLE_ORDER[minimum]:
            raise HTTPException(403, detail={
                "code": "ROLE_REQUIRED", "required_role": minimum,
                "message": "You do not have permission to do that.",
            })
        return claims
    return dependency


def require_step_up(*factors: str) -> Callable:
    """Verifies a step-up token proving the named factors were re-verified
    within the last 5 minutes."""
    async def dependency(request: Request, claims: CurrentClaims,
                         redis: RedisClient) -> None:
        ...
    return dependency
```

The reference put `role` in its claims and then never built a checker, leaving every check to be hand-written at each call site — which is how a forgotten check becomes invisible. Declaring it in the dependency list makes a missing check a missing line a reviewer can spot.

## 5. Feature slice anatomy

```
app/api/endpoints/stories/
├── __init__.py
├── router.py
├── controllers.py
├── models.py
├── utils.py
└── constants.py
```

### `router.py`

```python
router = APIRouter(prefix="/stories", tags=["Stories"])


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=Envelope[StoryOut],
    dependencies=[Depends(csrf_protect), Depends(rate_limit(20, 3600)),
                  Depends(idempotent)],
)
async def create_story(
    body: CreateStoryRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
):
    data = await controllers.create_story(body, claims=claims, mongo=mongo)
    return ok_response("Story saved as draft.", data=data)


@router.post(
    "/{story_id}/publish",
    status_code=status.HTTP_200_OK,
    response_model=Envelope[StoryOut],
    dependencies=[Depends(csrf_protect), Depends(rate_limit(20, 3600))],
)
async def publish_story(
    story_id: str,
    body: PublishStoryRequest,
    claims: CurrentClaims,
    mongo: MongoDatabase,
    queue: Queue,
):
    data = await controllers.publish_story(
        story_id, body, claims=claims, mongo=mongo, queue=queue,
    )
    message = ("Story scheduled." if data["visibility"] == "scheduled"
               else "Story published.")
    return ok_response(message, data=data)
```

A router function is four lines: call the controller, choose a message, wrap, return. If it grows an `if` that touches domain data, that logic belongs in the controller. Choosing between two messages based on a returned value is acceptable and is the reference's practice.

### `controllers.py`

```python
async def publish_story(
    story_id: str,
    body: PublishStoryRequest,
    *,
    claims: AccessClaims,
    mongo: AsyncIOMotorDatabase,
    queue: ArqRedis,
) -> dict[str, Any]:
    col = mongo[COL_STORIES]
    story = await col.find_one(
        {"_id": story_id, "author_id": claims.user_id, "deleted_at": None},
        projection=STORY_FULL_PROJECTION,
    )
    if story is None:
        raise not_found("STORY_NOT_FOUND", "That story could not be found.")

    if body.visibility == "public":
        if not body.community_id:
            raise bad_request("COMMUNITY_REQUIRED",
                              "Choose a community before publishing publicly.")
        if not await is_member(mongo, claims.user_id, body.community_id):
            raise forbidden("NOT_A_MEMBER",
                            "Join this community before posting in it.")
        if any(not m.get("exif_stripped") for m in story.get("media", [])):
            raise bad_request("EXIF_NOT_STRIPPED",
                              "Still preparing your images. Try again shortly.")

    if body.visibility == "scheduled":
        if body.scheduled_for is None or body.scheduled_for <= now_utc():
            raise unprocessable("SCHEDULE_IN_PAST",
                                "Pick a time in the future.")

    now = now_utc()
    update: dict[str, Any] = {
        "visibility": body.visibility,
        "community_id": body.community_id,
        "updated_at": now,
    }
    if body.visibility == "scheduled":
        update["scheduled_for"] = body.scheduled_for
    else:
        update["published_at"] = story.get("published_at") or now.replace(
            second=0, microsecond=0
        )
        if not story.get("slug") and body.visibility == "public":
            update["slug"] = new_slug()

    result = await col.update_one({"_id": story_id, "author_id": claims.user_id},
                                 {"$set": update})
    if result.matched_count == 0:
        raise not_found("STORY_NOT_FOUND", "That story could not be found.")

    if body.visibility == "public":
        await queue.enqueue_job("fan_out_new_story", story_id)

    return story_out({**story, **update})
```

Patterns visible here, all mandatory:

- **Explicit projection on every read.** Never an unprojected `find_one`.
- **Ownership is in the query filter**, not checked afterwards. `{"_id": ..., "author_id": claims.user_id}` cannot be bypassed by a logic error the way an `if story["author_id"] != ...` can.
- **`updated_at` in the same `$set`** as the mutation.
- **Branch on `matched_count` / `modified_count`** to distinguish 404 from 409 rather than re-reading to guess.
- **`published_at` truncated to the minute**, implementing the timing-correlation measure from [05](05-security-and-crypto.md) at the only place it can be enforced.
- **Side effects go on the queue**, never inline.

### `models.py`

Normalizing annotated types are defined once in `app/core/types.py` and imported everywhere, rather than being redefined per feature (the reference redefined `TrimStr` in its watchlist slice).

```python
# app/core/types.py
def _strip(v: Any) -> Any:      return v.strip() if isinstance(v, str) else v
def _strip_lower(v: Any) -> Any: return v.strip().lower() if isinstance(v, str) else v

TrimStr  = Annotated[str, BeforeValidator(_strip)]
LowerStr = Annotated[str, BeforeValidator(_strip_lower)]

USERNAME_RE = re.compile(r"^[a-z0-9_]{3,20}$")
SLUG_RE     = re.compile(r"^[a-z0-9-]{3,40}$")
EMAIL_RE    = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

Visibility = Annotated[Literal["draft", "private", "public", "scheduled"],
                       BeforeValidator(_strip_lower)]
```

```python
# stories/models.py
class CreateStoryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: TrimStr | None = Field(None, max_length=120)
    body: TrimStr = Field(min_length=1, max_length=20_000)
    community_id: str | None = None
    media: list[StoryMediaIn] = Field(default_factory=list, max_length=4)


class PublishStoryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    visibility: Literal["private", "public", "scheduled"]
    community_id: str | None = None
    scheduled_for: datetime | None = None


class StoryOut(BaseModel):
    id: str
    author: AuthorOut
    title: str | None
    body: str | None          # excluded from feed responses
    excerpt: str
    visibility: Visibility
    community: CommunityRefOut | None
    slug: str | None
    media: list[StoryMediaOut]
    counts: StoryCountsOut
    reading_minutes: int
    viewer_state: ViewerStateOut   # liked, is_author
    published_at: datetime | None
    created_at: datetime
```

`extra="forbid"` on every request model. A silently ignored unknown field means a client typo produces a successful response that did nothing, which is the hardest class of bug to find from the client side.

`Out` models are the public contract. Because a route declares `response_model=Envelope[StoryOut]`, a field that is not on `StoryOut` cannot escape — which is the structural guarantee that `password_hash` or `wrapped_umk` never leaks through an over-broad dict. The reference used `response_model` zero times and therefore had no such guarantee.

**Document models are not used for writes.** The reference defined a rich `User` Pydantic model and then built documents as raw dicts anyway, so the model was documentation that could silently diverge from reality. Here, document shapes live in [07-data-model.md](07-data-model.md), writes are explicit dicts built by a `build_*_doc` helper, and the enforced contracts are the request and response models at the boundary — the two places validation actually runs.

### `constants.py`

```python
COL_STORIES = "stories"
COL_COMMENTS = "comments"
COL_REACTIONS = "reactions"

STORY_MAX_BODY = 20_000
STORY_MAX_MEDIA = 4
STORY_EDIT_WINDOW_HOURS = 24
STORY_EXCERPT_CHARS = 240

STORY_FEED_PROJECTION = {
    "_id": 1, "author_id": 1, "author_snapshot": 1, "title": 1, "excerpt": 1,
    "visibility": 1, "community_id": 1, "slug": 1, "media": 1, "counts": 1,
    "reading_minutes": 1, "published_at": 1, "created_at": 1,
}
```

Collection names are constants, never inline strings. Projections are named constants, so a feed query and a detail query cannot accidentally diverge, and so the answer to "does the feed transfer full bodies?" is a one-line read.

## 6. Errors

Small helper constructors in `app/core/errors.py`, so no controller assembles a `detail` dict by hand:

```python
def _http(status_code: int, code: str, message: str, **extra) -> HTTPException:
    return HTTPException(status_code, detail={"code": code, "message": message, **extra})

def bad_request(code, message, **extra):   return _http(400, code, message, **extra)
def unauthorized(code, message, **extra):  return _http(401, code, message, **extra)
def forbidden(code, message, **extra):     return _http(403, code, message, **extra)
def not_found(code, message, **extra):     return _http(404, code, message, **extra)
def conflict(code, message, **extra):      return _http(409, code, message, **extra)
def gone(code, message, **extra):          return _http(410, code, message, **extra)
def locked(code, message, **extra):        return _http(423, code, message, **extra)
def unprocessable(code, message, **extra): return _http(422, code, message, **extra)
def too_many(code, message, retry_after_seconds: int, **extra):
    return _http(429, code, message, retry_after_seconds=retry_after_seconds, **extra)
```

**`detail` is always a dict** with `code` and `message`. The reference allowed both a bare string (which became the user message) and a dict (which became structured `data`), and the two paths behaved differently — one always-dict shape means the handler has one branch and clients always find `data.code`.

### Handlers

```python
def register_exception_handlers(app: FastAPI) -> None:

    @app.exception_handler(HTTPException)
    async def handle_http(request: Request, exc: HTTPException) -> JSONResponse:
        detail = exc.detail if isinstance(exc.detail, dict) else {
            "code": "ERROR", "message": str(exc.detail)}
        message = detail.pop("message", http_default_message(exc.status_code))
        logger.warning("http_error", status=exc.status_code,
                       code=detail.get("code"), route=request.url.path)
        return JSONResponse(exc.status_code,
                            content=err_response(message, data=detail))

    @app.exception_handler(RequestValidationError)
    async def handle_validation(request, exc) -> JSONResponse:
        fields = flatten_validation_errors(exc.errors())
        first = fields[0] if fields else None
        logger.warning("validation_failed", route=request.url.path,
                       fields=[f["field"] for f in fields])
        return JSONResponse(422, content=err_response(
            first["message"] if first else "That request was not valid.",
            data={"code": "VALIDATION_FAILED",
                  "field": first["field"] if first else None,
                  "fields": fields},
        ))

    @app.exception_handler(Exception)
    async def handle_unhandled(request, exc) -> JSONResponse:
        request_id = getattr(request.state, "request_id", None)
        logger.error("unhandled_error", type=type(exc).__name__,
                     route=request.url.path, request_id=request_id, exc_info=exc)
        return JSONResponse(500, content=err_response(
            "Something went wrong on our side. Try again shortly.",
            data={"code": "INTERNAL_ERROR", "request_id": request_id},
        ))
```

`flatten_validation_errors` walks every error rather than only the first, dropping `body`/`query`/`path` prefixes from `loc` and mapping Pydantic error types onto our codes (`string_too_long` → `TOO_LONG`).

The 500 handler returns a `request_id` and nothing else. A user can quote it to support; an attacker learns nothing.

**No handler logs a request body.** The reference echoed the full request payload from all three handlers, which for this product would mean passwords and passcodes in the log store. Handlers log the route, the status, the code, and the field *names* — never values.

## 7. Logging

`structlog`, JSON in staging and production, key-value in local. Configured in `app/logging.py` and called from `lifespan`.

```python
def configure_logging(settings: Settings) -> None:
    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        redact_processor,                      # ← mandatory, default-deny
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]
    renderer = (structlog.dev.ConsoleRenderer() if settings.API_ENV == "local"
                else structlog.processors.JSONRenderer())
    structlog.configure(processors=[*processors, renderer], ...)
```

### The redaction processor

```python
ALLOWED_KEYS = frozenset({
    "event", "level", "timestamp", "logger", "request_id",
    "user_id", "story_id", "item_id", "ticket_id", "community_id",
    "family_id", "staff_id", "role", "route", "method", "status",
    "duration_ms", "code", "service", "count", "reason", "type",
    "exc_info", "exception", "fields", "action", "outcome",
})

DENIED_SUBSTRINGS = ("password", "passcode", "otp", "token", "secret", "cookie",
                     "authorization", "wrapped", "salt", "email", "label",
                     "recovery", "dek", "umk", "kek", "escrow", "cipher",
                     "phrase", "reveal")

def redact_processor(logger, method, event_dict: dict) -> dict:
    out = {}
    for key, value in event_dict.items():
        lower = key.lower()
        if any(bad in lower for bad in DENIED_SUBSTRINGS):
            out[key] = "<redacted>"
        elif key in ALLOWED_KEYS:
            out[key] = value
        else:
            out[key] = "<redacted>"
    return out
```

**Default-deny.** An unrecognized key is redacted rather than logged. That is what makes the processor safe against future code: a developer who adds `logger.info("thing", secret_material=x)` gets `<redacted>` without having to know the rule exists. A CI test feeds a dict containing every denied key and asserts none of the values appear in the rendered output.

### Request context

`RequestIdMiddleware` generates or propagates `X-Request-Id` and binds it plus route, method, and `user_id` into `contextvars`, so every log line inside a request carries them without being passed down. Completion logs one line: `event=request route=... method=... status=... duration_ms=...`.

**One logger per module**, named `story.<area>`: `story.main`, `story.db`, `story.auth`, `story.stories.controller`. Never the root logger.

## 8. Cross-cutting dependencies

### CSRF

```python
async def csrf_protect(request: Request) -> None:
    s = get_settings()
    if request.headers.get("authorization"):
        return                        # Bearer clients are not CSRF-exposed
    cookie = request.cookies.get(s.CSRF_COOKIE_NAME, "")
    header = request.headers.get(s.CSRF_HEADER_NAME, "")
    if not cookie or not header:
        raise forbidden("CSRF_MISSING", "Your session needs to be refreshed.")
    if not hmac.compare_digest(cookie, header):
        raise forbidden("CSRF_MISMATCH", "Your session needs to be refreshed.")
```

The Bearer short-circuit is what lets one dependency serve both clients: a request carrying an explicit `Authorization` header is not using an ambient credential, so there is nothing for a cross-site request to forge.

### Rate limiting

```python
def rate_limit(max_calls: int, window_seconds: int, *,
               scope: str | None = None, by: Literal["ip", "user", "both"] = "both"):
    async def dependency(request: Request, redis: RedisClient) -> None: ...
    return dependency
```

Fixed-window Redis `INCR` with the TTL set on first increment. `by="both"` enforces per-IP and per-user limits independently, which matters because a per-IP limit alone punishes users behind shared NAT while a per-user limit alone does nothing against signup abuse.

**Applied to every mutating route without exception.** A CI test enumerates the route table and fails if a non-`GET` route lacks both `csrf_protect` and a `rate_limit` — the reference applied these by hand and its watchlist feature ended up with neither.

### Idempotency

```python
async def idempotent(request: Request, redis: RedisClient) -> None:
    key = request.headers.get("idempotency-key")
    if not key:
        return
    ...  # replay a cached response, or mark in-flight and cache on completion
```

## 9. Database access

### Query rules

| Rule | Why |
|---|---|
| Always pass `projection` | An unprojected read transfers whole documents and is how a `wrapped_umk` ends up somewhere it should not be |
| Filter `deleted_at: None` on content reads | Soft-deleted content must never appear |
| Put ownership in the filter | A filter cannot be forgotten the way a post-fetch check can |
| Set `updated_at` in the same `$set` | Two writes can interleave |
| Use conditional filters for idempotency | `{"sk": {"$ne": v}}` makes a double-submit a no-op |
| Branch on the write result | `matched_count == 0` is 404; `modified_count == 0` with a match is 409 |
| Never `find()` without a limit | An unbounded cursor is an outage waiting for enough data |

### The repository seam

Direct Motor access inside a controller is the default and is correct for CRUD. **Two collections are exceptions:** `vault_items` and `audit_logs` get a `repository.py` (the sixth permitted file in those slices only), because their correctness is security-critical and must be unit-testable without a live database.

```python
class VaultRepository:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self._items = db[COL_VAULT_ITEMS]

    async def list_normal(self, user_id: str, *, limit: int,
                          cursor: str | None) -> list[dict]:
        """Never returns hidden items. Enforced in the query, not the caller."""
        q: dict[str, Any] = {"user_id": user_id, "visibility": "normal",
                             "deleted_at": None}
        if cursor:
            q["_id"] = {"$lt": cursor}
        return await self._items.find(q, projection=VAULT_LIST_PROJECTION) \
                                .sort("_id", -1).limit(limit).to_list(limit)

    async def find_by_label(self, user_id: str, label_hash: str) -> dict | None:
        return await self._items.find_one(
            {"user_id": user_id, "label_hash": label_hash, "deleted_at": None},
            projection=VAULT_FULL_PROJECTION,
        )
```

`visibility: "normal"` living inside the repository means there is exactly one place in the codebase where the hidden-item guarantee can be broken, and a unit test asserts it. With the filter spread across call sites, the guarantee is only as strong as the least careful one.

### Audit writes

```python
async def write_audit(db, *, actor, action, target, outcome,
                      details=None, ticket_id=None, visible_to_target=True) -> str:
```

`AuditRepository` is the only module that touches `audit_logs`, it exposes `insert` and `find` and nothing else, and the MongoDB role the API connects with has no `update` or `remove` privilege on that collection. Both layers agree, so a bug in one cannot defeat the property.

## 10. Workers

```python
# app/workers/settings.py
class WorkerSettings:
    functions = [
        strip_exif_and_thumbnail, transcode_vault_video, verify_vault_object,
        fan_out_new_story, fan_out_comment, send_email_otp, send_security_alert,
        recompute_recommendations, refresh_interest_embeddings,
    ]
    cron_jobs = [
        cron(publish_scheduled_stories, minute=set(range(60))),
        cron(reconcile_counts, hour=3, minute=0),
        cron(verify_audit_chain, hour=3, minute=30),
        cron(reap_pending_uploads, hour=4, minute=0),
        cron(expire_reveal_links, minute={0, 15, 30, 45}),
        cron(purge_deleted_accounts, hour=5, minute=0),
    ]
    on_startup = worker_startup      # own Mongo, Redis, storage clients
    on_shutdown = worker_shutdown
    max_tries = 3
    job_timeout = 600
```

Rules:

- **Jobs take identifiers, never documents.** A job argument is serialized into Redis; passing a document means stale data and a payload that may contain sensitive fields.
- **Jobs are idempotent.** `max_tries = 3` means every job will sometimes run twice.
- **Jobs never touch plaintext vault content.** `verify_vault_object` checks size and existence against R2; it does not download and cannot decrypt.
- **`expire_reveal_links` is a security control, not maintenance.** It enforces the 24-hour ticket reveal window; if it stops running, reveal blobs persist indefinitely. It is monitored and alerts on failure.
- **The worker owns its own clients.** Sharing a connection pool with the API means a slow job degrades request latency.

## 11. Testing

```
tests/
├── conftest.py              # app fixture, mongomock-motor, fakeredis, auth helpers
├── core/                    # crypto, ids, deps, redaction
├── endpoints/<feature>/     # route-level tests through the real app
└── contract/                # envelope shape, error catalogue, route policy
```

| Layer | Approach |
|---|---|
| Unit | Pure functions and repositories. `mongomock-motor` and `fakeredis`. |
| Route | `httpx.AsyncClient` against the real app with fake backends. Asserts status, `success`, `data.code`, and the response model shape. |
| Contract | Enumerates `app.routes` and asserts policy: every non-`GET` route has CSRF and rate limiting, every route declares a `response_model`, every route declares an explicit `status_code`. |
| Security | The checklist in [05](05-security-and-crypto.md) §13. |

The contract tests are the highest-value ones because they catch omissions rather than mistakes. A developer who forgets `csrf_protect` on a new endpoint has written code that works perfectly in every functional test; only a test that inspects the route table finds it.

Coverage floor: 80% overall, **100% on `app/core/crypto.py` and `app/core/security.py`**. The reference project had no tests at all and a CI job that only import-checked with an incomplete environment — a gate that passes while broken is worse than no gate.

## 12. Deployment

Multi-stage Dockerfile, non-root user, frozen lockfile:

```dockerfile
FROM python:3.13-slim AS builder
WORKDIR /build
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

FROM python:3.13-slim
RUN useradd --create-home --uid 10001 story
WORKDIR /app
COPY --from=builder /build/.venv /app/.venv
COPY app ./app
ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1
USER story
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", \
     "--workers", "4", "--proxy-headers", "--forwarded-allow-ips", "*"]
```

`--proxy-headers` is required for `X-Forwarded-For` to reach the rate limiter behind a load balancer. Without it every request appears to come from the proxy's IP and per-IP limits become a single global limit.

**Deployment order** for a release with a data migration: run the migration command → deploy the API → deploy workers. Migrations never run automatically on boot, because during a rolling deploy that means every instance runs them concurrently.

Two health endpoints, used differently: the load balancer polls `/health/ready`, which probes MongoDB and Redis; the orchestrator's liveness probe polls `/health`, which only confirms the process is alive. Wiring liveness to a dependency check means a brief database blip restarts every container.
