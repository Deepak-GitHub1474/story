# 08 — API Contract

Base URL: `https://api.storyapp.example/v1`

Every response in this API has the same three-key shape, including errors. Every mutating route requires CSRF (browser) and is rate limited. Every field on the wire is `snake_case`.

## 1. The envelope

```jsonc
{
  "success": true,
  "message": "Story published.",
  "data": { /* payload, or null */ }
}
```

```jsonc
{
  "success": false,
  "message": "That username is already taken.",
  "data": { "code": "USERNAME_TAKEN", "field": "username" }
}
```

Rules, all enforced:

1. **Three keys, always present.** `data` may be `null` but is never omitted.
2. **`message` is a complete sentence with terminal punctuation**, written for a human, safe to display verbatim in a toast. Never a code, never an exception name, never a stack trace.
3. **`data.code` is present on every error** and is what clients branch on. Clients must never parse `message` — it is subject to change and to localization.
4. **The envelope is constructed in the router only.** Controllers return plain dicts; they never import `ok_response`.
5. **A response is successful only if the HTTP status is 2xx *and* `success` is `true`.** Clients check both, which makes a misconfigured proxy returning a 200 HTML error page fail safely.

`data` for a collection response is an object, never a bare array:

```jsonc
{
  "success": true,
  "message": "Stories retrieved.",
  "data": {
    "items": [ /* ... */ ],
    "next_cursor": "sto_01J9X...",
    "has_more": true
  }
}
```

Returning a bare array leaves nowhere to add pagination or metadata later without a breaking change.

## 2. Status codes

| Code | Meaning here |
|---|---|
| `200` | Success on read, update, delete |
| `201` | Resource created |
| `202` | Accepted for async processing (upload completion, export) |
| `204` | Never used — we always return an envelope |
| `400` | Malformed request, business-rule violation, limit exceeded |
| `401` | Missing, expired, or revoked credentials |
| `403` | Authenticated but not permitted; CSRF failure; account blocked |
| `404` | Not found, or not visible to this caller (the two are indistinguishable by design) |
| `409` | Conflict: duplicate username, duplicate label, already liked |
| `410` | Gone: an expired reveal link or one-time token |
| `413` | Payload too large |
| `422` | Schema validation failure |
| `423` | Locked: vault item in a passcode lockout window |
| `429` | Rate limited. Always includes `retry_after_seconds` |
| `503` | A dependency (MongoDB, Redis, R2) is unavailable |

**`404` doubles as "not permitted to know".** A request for another user's private story returns `404`, not `403`, because `403` confirms the resource exists. This applies to private stories, hidden vault items, and other users' tickets.

## 3. Validation errors

FastAPI's default validation error is an array of objects with `loc` paths — useful to a developer, useless in a toast. It is flattened to one sentence plus a structured field list:

```jsonc
{
  "success": false,
  "message": "Body must be 20000 characters or fewer.",
  "data": {
    "code": "VALIDATION_FAILED",
    "field": "body",
    "fields": [
      { "field": "body", "code": "TOO_LONG", "message": "Body must be 20000 characters or fewer." }
    ]
  }
}
```

`message` and `field` reflect the first error, for the common single-field case. `fields` carries all of them so a form can highlight every invalid input at once.

## 4. Error code catalogue

Clients branch on these. Adding a code is a minor version change; changing the meaning of one is breaking.

### Auth and identity

| Code | Status | Meaning |
|---|---|---|
| `INVALID_CREDENTIALS` | 401 | Wrong username or password. Deliberately does not distinguish. |
| `TOKEN_EXPIRED` | 401 | Access token past `exp`. Client should refresh. |
| `TOKEN_INVALID` | 401 | Malformed or bad signature. |
| `TOKEN_REVOKED` | 401 | On the denylist. Client must sign in again. |
| `TOKEN_REUSED` | 401 | Refresh reuse detected. Whole family revoked; sign in again. |
| `SESSION_REQUIRED` | 401 | No credentials supplied. |
| `USERNAME_TAKEN` | 409 | |
| `USERNAME_INVALID` | 422 | Fails `^[a-z0-9_]{3,20}$`. |
| `PASSWORD_TOO_WEAK` | 422 | Under 10 chars, or on the breached list. |
| `ACCOUNT_BLOCKED` | 403 | `blocked` is true. Reason is never returned. |
| `ACCOUNT_DEACTIVATED` | 403 | Recoverable by signing in within 30 days. |
| `REFERRAL_CODE_INVALID` | 422 | No account owns that code. Signup is rejected rather than silently dropping the code. |
| `TNC_REQUIRED` | 422 | |
| `STEP_UP_REQUIRED` | 403 | Route needs re-authentication. `data.factors` lists which. |
| `CSRF_MISSING` / `CSRF_MISMATCH` | 403 | |

### Keys, email, recovery

| Code | Status | Meaning |
|---|---|---|
| `KEYS_NOT_INITIALIZED` | 400 | Signup's key-upload step never completed. |
| `KEYS_ALREADY_INITIALIZED` | 409 | Prevents overwriting a `wrapped_umk` and silently destroying a vault. |
| `EMAIL_ALREADY_SET` | 409 | |
| `EMAIL_IN_USE` | 409 | Detected via the blind index. |
| `EMAIL_NOT_SET` | 400 | A flow requiring email was attempted without one. |
| `EMAIL_NOT_VERIFIED` | 403 | |
| `OTP_INVALID` | 400 | Wrong or expired. `data.attempts_remaining` when above zero. |
| `OTP_LOCKED` | 429 | Too many failures. `data.retry_after_seconds`. |
| `OTP_COOLDOWN` | 429 | Resend requested too soon. |
| `RECOVERY_NOT_ENABLED` | 400 | |
| `RECOVERY_INVALID` | 400 | Phrase failed to unwrap the UMK. |
| `RESET_TOKEN_INVALID` | 400 | |
| `RESET_TOKEN_EXPIRED` | 410 | |

### Stories, comments, communities

| Code | Status | Meaning |
|---|---|---|
| `STORY_NOT_FOUND` | 404 | Also returned for a private story owned by someone else. |
| `STORY_NOT_EDITABLE` | 400 | Published stories have a limited edit window. |
| `STORY_BODY_EMPTY` | 422 | |
| `STORY_TOO_LONG` | 422 | |
| `COMMUNITY_REQUIRED` | 400 | Publishing publicly requires a community. |
| `COMMUNITY_NOT_FOUND` | 404 | |
| `NOT_A_MEMBER` | 403 | Posting to a community requires membership. |
| `SCHEDULE_IN_PAST` | 422 | |
| `MEDIA_LIMIT` | 400 | More than 4 images. |
| `EXIF_NOT_STRIPPED` | 400 | Publish blocked until the worker finishes. |
| `ALREADY_LIKED` / `NOT_LIKED` | 409 | |
| `COMMENT_NOT_FOUND` | 404 | |
| `NESTING_TOO_DEEP` | 400 | One reply level only. |
| `SELF_FOLLOW` | 400 | |
| `BLOCKED_BY_USER` | 403 | |
| `CATEGORY_NOT_FOUND` | 404 | |

### The sanity layer

Publication is gated, so the publish endpoint has its own outcomes. See [12-ai-layer.md](12-ai-layer.md).

| Code | Status | Meaning |
|---|---|---|
| `CONTENT_BLOCKED` | 400 | The safety gate refused. `data.rule` names the rule, `data.rationale` is one displayable sentence, `data.review_id` identifies the decision, `data.appeal_available` is a boolean. |
| `CONTENT_HELD` | 202 | Queued for human review. `data.review_id`, `data.expected_by`. **Not an error in the user's sense** — the story is safe, it is waiting — so the envelope's `success` is `true` and the client renders it as a state, not a failure. |
| `CONTENT_OFF_TOPIC` | 400 | Fit check landed on `redirect`. `data.fit_score`, `data.suggested_communities[]` with `slug`, `name`, and `score`. Retrying with `fit_override: true` succeeds. |
| `SELF_EXPOSURE_UNACKNOWLEDGED` | 400 | The exposure check found identifying spans and the client did not send `exposure_ack`. `data.spans[]` carries `{start, end, kind}` for highlighting. **Never blocks on retry with `exposure_ack: true`** — this code exists to guarantee the warning was shown, not to prevent the choice. |
| `MODERATION_UNAVAILABLE` | 503 | The gate could not reach a verdict and `AI_FAIL_MODE` is `hold`. The story is saved and queued; nothing is lost. |
| `APPEAL_ALREADY_OPEN` | 409 | One open appeal per piece of content. |
| `APPEAL_NOT_AVAILABLE` | 403 | The verdict is terminal and not appealable. |

**`CONTENT_HELD` returning `202` with `success: true` is deliberate and is the one place the envelope rules bend toward the product.** A person who spent an hour writing something and pressed publish has not made an error, and an interface that returns them a red failure state for a review queue is telling them they did something wrong. The client branches on `data.moderation_state`, not on a red toast.

### Vault

| Code | Status | Meaning |
|---|---|---|
| `VAULT_ITEM_NOT_FOUND` | 404 | Also the response for a hidden-label miss. |
| `PASSCODE_INVALID` | 400 | `data.attempts_remaining` when above zero. |
| `PASSCODE_LOCKED` | 423 | `data.locked_until`. |
| `PASSCODE_NOT_FOUND` | 404 | |
| `PASSCODE_LABEL_TAKEN` | 409 | |
| `LABEL_REQUIRED` | 422 | A hidden item needs a `label_hash`. |
| `LABEL_TAKEN` | 409 | That `label_hash` already exists for this user. |
| `QUOTA_EXCEEDED` | 400 | `data.used_bytes`, `data.limit_bytes`. |
| `ITEM_TOO_LARGE` | 413 | |
| `ITEM_NOT_READY` | 400 | Upload not confirmed. |
| `ITEM_ORPHANED` | 400 | Key destroyed by a password reset. Undecryptable. |
| `UPLOAD_MISMATCH` | 400 | Confirmed size or chunk count does not match the object. |

### Tickets and admin

| Code | Status | Meaning |
|---|---|---|
| `TICKET_NOT_FOUND` | 404 | |
| `TICKET_ALREADY_OPEN` | 409 | One open ticket per type per user. |
| `TICKET_PRECONDITION_FAILED` | 400 | `data.unmet` lists which precondition. |
| `TICKET_WRONG_STATE` | 400 | Action invalid for the current state. |
| `ROLE_REQUIRED` | 403 | `data.required_role`. |
| `REVEAL_EXPIRED` | 410 | |
| `REVEAL_CODE_INVALID` | 400 | |
| `REVEAL_ALREADY_USED` | 410 | |
| `DUAL_APPROVAL_REQUIRED` | 403 | |

### Generic

| Code | Status | Meaning |
|---|---|---|
| `VALIDATION_FAILED` | 422 | |
| `RATE_LIMITED` | 429 | `data.retry_after_seconds`. |
| `SERVICE_UNAVAILABLE` | 503 | `data.service` names the dependency. |
| `INTERNAL_ERROR` | 500 | Opaque. Details are logged, never returned. |

## 5. Authentication transport

Two transports, one verification path. The server reads the access token from the cookie first and falls back to the `Authorization` header.

### Browser

| Cookie | Flags | Contents |
|---|---|---|
| `story_access` | httpOnly, Secure, SameSite=Lax, path=/ | Access JWT |
| `story_refresh` | httpOnly, Secure, SameSite=Lax, path=/ | Opaque refresh token |
| `story_csrf` | Secure, SameSite=Lax, **not** httpOnly | CSRF token, read by JS and echoed in `x-csrf-token` |

The CSRF cookie is intentionally JS-readable — that is the double-submit pattern. The value is compared with `hmac.compare_digest` against the header on every mutating request.

Browser requests do not reach the API directly. They go through the Next.js BFF at `/api/*`, which attaches cookies server-side, so tokens are never present in client JavaScript. See [10-client-conventions.md](10-client-conventions.md).

### Mobile

`Authorization: Bearer <access_token>`, with the refresh token in the platform keychain. CSRF does not apply — there is no ambient credential to forge.

### Refresh

```
POST /auth/refresh
```

Rotates the refresh token, issues a new access token, and keeps the same `family_id`. If the presented token matches a rotation tombstone, the entire family is revoked and `TOKEN_REUSED` is returned. Both clients implement retry-once-on-401: attempt, refresh on 401, retry once, and sign out if the retry also fails.

## 6. Pagination

Cursor-based on every list. Offset pagination is not offered — it duplicates and drops items when the underlying data changes, which on a live feed is constant.

```
GET /stories/feed?limit=20&cursor=sto_01J9X...
```

| Parameter | Notes |
|---|---|
| `limit` | Default 20, max 50 |
| `cursor` | The `_id` of the last item from the previous page. ULIDs sort chronologically, so this is a simple range predicate. |

Response carries `next_cursor` (null on the last page) and `has_more`. Total counts are never returned on feeds — computing one requires a full scan, and no interface needs it.

## 7. Endpoints

`Auth` column: `—` public, `S` session required, `SU` session plus step-up, `R:<role>` role required.

### Health

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/health` | — | Liveness. Returns service, version, env. |
| `GET` | `/health/ready` | — | Readiness. **Actually probes MongoDB and Redis** and returns 503 if either is down. |

The reference project's health endpoint reported "up and running" unconditionally without probing its dependencies, making it useless as a readiness check. Split into two: liveness answers "is the process alive", readiness answers "can it serve traffic".

### Auth — `/auth`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/auth/signup` | — | Create account. Body: `username`, `password`, `tnc_accepted`, `referral_code?`. Returns tokens plus `keys_required: true` and the new account's own `referral_code`. |
| `POST` | `/auth/signin` | — | Body: `username`, `password`. Constant-time on failure. |
| `POST` | `/auth/refresh` | — (refresh token) | Rotate. |
| `POST` | `/auth/signout` | S | Revoke this session's family and denylist the access token. |
| `POST` | `/auth/signout-all` | S | Revoke every family for this user. |
| `GET` | `/auth/me` | S | Current user. The client's canonical bootstrap call. |
| `GET` | `/auth/sessions` | S | Active sessions with device, coarse location, last used, `is_current`. |
| `DELETE` | `/auth/sessions/{family_id}` | S | Revoke one session. |
| `POST` | `/auth/username-available` | — | Body: `username`. Rate limited at 10/min. Returns only a boolean — never a suggestion list, which would leak the taken set. |
| `POST` | `/auth/password/change` | S | Body: `current_password`, `new_password`, `new_salt_pw`, `new_wrapped_umk`. **Preserves the vault.** |
| `POST` | `/auth/password-reset/request` | — | Body: `username`. Always 200, always the same message and timing. |
| `POST` | `/auth/password-reset/verify` | — | Body: `username`, `otp`. Returns a single-use `reset_token`. |
| `POST` | `/auth/password-reset/complete` | — | Body: `reset_token`, `new_password`, `new_salt_pw`, `new_wrapped_umk`, `acknowledged_vault_loss: true`. **Destroys the vault.** |

`acknowledged_vault_loss` is a required boolean that must be `true`. A server-side gate on a destructive client-side confirmation means a client bug, or a script hitting the API directly, cannot skip the warning.

### Keys — `/users/me/keys`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/users/me/keys` | S | One-time initialization. Body: `salt_pw`, `wrapped_umk`, `kdf`. Returns `KEYS_ALREADY_INITIALIZED` on a second call. |
| `GET` | `/users/me/keys` | S | Returns `salt_pw`, `wrapped_umk`, `kdf`, `label_key_version`. Called at every sign-in. |
| `POST` | `/users/me/keys/recovery` | S | Create a Recovery Kit. Body: `salt_recovery`, `blob` (omitted in offline mode), `mode`. |
| `DELETE` | `/users/me/keys/recovery` | SU | Remove it. |
| `POST` | `/auth/vault-recovery/request` | — | Body: `username`. Returns `salt_recovery` and `blob`. Rate limited 3/hour. |

### Profile — `/users`

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/users/me` | S | Full own profile including `prefs` and `onboarding`. |
| `PATCH` | `/users/me` | S | `display_name`, `bio`, `interests`, `prefs`. Partial, `extra="forbid"`. |
| `POST` | `/users/me/avatar/regenerate` | S | New `avatar_seed`. **No upload endpoint exists** (P4). |
| `GET` | `/users/{username}` | S | Public profile: display name, avatar seed, bio, counts, `is_following`. |
| `GET` | `/users/{username}/stories` | S | That user's public stories. Paginated. |
| `POST` | `/users/me/deactivate` | SU | Reversible for 30 days. |
| `POST` | `/users/me/delete` | SU | Opens an `account_deletion` ticket with a 14-day grace period. |

### Email — `/users/me/email`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/users/me/email` | S | Body: `email`. Stores blind index + ciphertext, sends OTP. Never echoes the address. |
| `POST` | `/users/me/email/verify` | S | Body: `otp`. |
| `POST` | `/users/me/email/resend` | S | 30-second cooldown, 3/hour. |
| `DELETE` | `/users/me/email` | SU | Removes it. Warns that account recovery becomes impossible. |

Every response carries `email_masked` only. There is no endpoint anywhere that returns a plaintext email address, so a stolen session cannot harvest one.

### Categories and communities — `/communities`

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/communities/categories` | S | The category taxonomy with `tone`, icon, accent token, and community counts. Cached 5 minutes; it changes about once a quarter. |
| `GET` | `/communities` | S | Browse. Filters: `category`, `tone`, `q`. Paginated. |
| `GET` | `/communities/{slug}` | S | Detail with `is_member`. |
| `GET` | `/communities/{slug}/stories` | S | Community feed. Paginated. |
| `POST` | `/communities/{slug}/join` | S | Idempotent. |
| `DELETE` | `/communities/{slug}/join` | S | Idempotent. |
| `GET` | `/communities/me` | S | Joined communities with unread indicators. |
| `GET` | `/communities/{slug}/members` | S | **Only when `member_directory` is `true`.** `404` otherwise — the flag's absence is not disclosed. Returns display name, avatar seed, joined-at. No sort parameter, no filter parameter, ever. |
| `PATCH` | `/communities/{slug}/settings` | S | `notifications_enabled`, `last_read_at`. |

### Connections — `/connections`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/connections/{username}` | S | Follow. Idempotent. |
| `DELETE` | `/connections/{username}` | S | Unfollow. Idempotent. |
| `GET` | `/connections/following` | S | Paginated. |
| `GET` | `/connections/followers` | S | Paginated. |
| `POST` | `/connections/{username}/block` | S | Blocks and removes any existing follow both ways. |
| `DELETE` | `/connections/{username}/block` | S | |
| `GET` | `/connections/blocked` | S | |

### Stories — `/stories`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/stories` | S | Create. Always starts as `draft` regardless of what the body says. 201. |
| `GET` | `/stories/{id}` | S | Own stories at any visibility; others' public only. |
| `PATCH` | `/stories/{id}` | S | Update `title`, `body`, `community_id`, `media`. Drafts freely; published within a 24-hour window, and edits set `edited_at`. |
| `DELETE` | `/stories/{id}` | S | Soft delete. |
| `POST` | `/stories/{id}/precheck` | S | Runs the sanity layer **without publishing**. Body: `community_id?`. Returns the verdict, fit score, suggested communities, and exposure spans. Rate limited 10/hour per story. |
| `POST` | `/stories/{id}/publish` | S | Body: `visibility` (`public`/`private`/`scheduled`), `scheduled_for?`, `community_id?`, `fit_override?`, `exposure_ack?`. The only transition out of `draft`. Runs the gate; see the sanity-layer error codes. |
| `POST` | `/stories/{id}/appeal` | S | Opens a `content_appeal` ticket for a `hold` or `block`. Body: `reason`. 201. |
| `POST` | `/stories/{id}/unpublish` | S | Back to `draft`. Comments and likes are preserved but hidden. |
| `GET` | `/stories/mine` | S | Own stories. Filter by `visibility`. |
| `GET` | `/stories/feed` | S | Home feed: followed users plus joined communities. |
| `GET` | `/stories/discover` | S | Recommendation-driven feed. |
| `GET` | `/stories/search` | S | `q`, optional `community`. Public stories only. |
| `POST` | `/stories/{id}/like` | S | Idempotent upsert. Returns the new count. |
| `DELETE` | `/stories/{id}/like` | S | Idempotent. |
| `POST` | `/stories/{id}/share` | S | Increments the count and returns a share URL with an opaque slug. |
| `POST` | `/stories/media/presign` | S | Body: `content_type`, `size_bytes`. Returns `object_key` and a presigned PUT URL. |
| `POST` | `/stories/media/complete` | S | Body: `object_key`. Enqueues EXIF strip and thumbnailing. 202. |

**Publish is a separate endpoint rather than a `PATCH` on `visibility`.** Publishing has side effects — the sanity gate, validation that a community is set, EXIF verification, slug generation, notification fan-out, feed cache invalidation — and a general-purpose field update should not carry that weight. Separating it also means the audit trail distinguishes "edited a draft" from "made something public", which for this product is a meaningful difference.

**`precheck` exists so the composer never ambushes the author.** The client calls it on a debounce while writing, so exposure warnings and a community suggestion appear *as* the story is written rather than at the moment the author presses publish and is emotionally finished. The publish endpoint re-runs the gate regardless — a precheck result is advisory and is never trusted as authorization, because a client that could pre-authorize its own publication would be the whole gate's bypass.

### Comments — `/stories/{id}/comments`

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/stories/{id}/comments` | S | Top-level, paginated, with the first 3 replies inlined. |
| `POST` | `/stories/{id}/comments` | S | Body: `body`, `parent_id?`. 201. |
| `GET` | `/comments/{id}/replies` | S | Full reply list. |
| `PATCH` | `/comments/{id}` | S | 15-minute edit window. |
| `DELETE` | `/comments/{id}` | S | Author or story author. |
| `POST` | `/comments/{id}/like` | S | |
| `DELETE` | `/comments/{id}/like` | S | |

### Vault — `/vault`

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/vault/overview` | S | Item count, used bytes, limit, passcode list, orphaned count. **Normal items only** — hidden items contribute to nothing visible here. |
| `GET` | `/vault/items` | S | `visibility: normal` items. Returns metadata plus `encrypted_metadata` and `thumb_encrypted` for client-side decryption. |
| `POST` | `/vault/items` | S | Create. Body: `passcode_id`, `kind`, `size_bytes`, `chunk_count`, `encrypted_metadata`, `wrapped_dek`, `salt_item`, `visibility`, `label_hash?`, `thumb_encrypted?`. Returns `item_id` and a presigned PUT URL. 201. |
| `POST` | `/vault/items/{id}/complete` | S | Body: `chunk_count`, `total_size`. Verifies the object against R2. 202. |
| `GET` | `/vault/items/{id}` | S | Full item record including `wrapped_dek` and `salt_item`. |
| `GET` | `/vault/items/{id}/download` | S | Presigned GET, 5-minute expiry. |
| `PATCH` | `/vault/items/{id}` | S | `encrypted_metadata`, `visibility`, `label_hash`. Changing to `hidden` requires a `label_hash`. |
| `DELETE` | `/vault/items/{id}` | S | Soft delete; the worker purges the object. |
| `POST` | `/vault/search` | S | Body: `label_hash`. **Exact match only.** Generic 404 on a miss, timing-equalized. |
| `POST` | `/vault/items/{id}/verify-passcode` | S | Body: `passcode_id`, `passcode_proof`. Confirms the passcode before the client attempts a decrypt, so a wrong entry produces a clear error instead of a mysterious decrypt failure. |
| `GET` | `/vault/passcodes` | S | List: id, label, scope, created, last used. **Never a value or a hash.** |
| `POST` | `/vault/passcodes` | S | Body: `label`, `scope`, `passcode_hash`, `salt_pc`, `kdf`, `escrow_payload`, `hint?`. |
| `PATCH` | `/vault/passcodes/{id}` | SU | Change. Body includes re-wrapped `wrapped_dek` values for every affected item, computed client-side. |
| `DELETE` | `/vault/passcodes/{id}` | SU | Only when no items reference it. |
| `POST` | `/vault/items/orphaned/delete-all` | SU | Bulk cleanup after a reset. |

**`/vault/search` is a POST, not a GET.** A `label_hash` in a query string lands in access logs, browser history, and any intermediate proxy's logs. It is not secret in the cryptographic sense, but its presence in a log confirms that a hidden item exists — so it goes in a body.

`escrow_payload` is the passcode encrypted under a public escrow key by the client, so the plaintext never appears in a request body that could be logged. The server unwraps it to KMS-envelope form.

### Tickets — `/tickets`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/tickets` | S | Body: `type`, `reason`. Preconditions checked; `data.unmet` on failure. 201. |
| `GET` | `/tickets` | S | Own tickets. |
| `GET` | `/tickets/{id}` | S | Detail with the full timeline. Internal staff notes are excluded by projection. |
| `POST` | `/tickets/{id}/verify-email` | S | Body: `otp`. Moves `awaiting_email_verify` → `submitted`. |
| `POST` | `/tickets/{id}/messages` | S | Reply. |
| `POST` | `/tickets/{id}/close` | S | User-initiated close. |
| `POST` | `/tickets/{id}/reveal` | S | Body: `reveal_token`, `otp`, `reveal_code`. All three required. Returns `payload_ciphertext` decryptable with `reveal_code`. |

### Notifications — `/notifications`

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/notifications` | S | Paginated. Filter `unread_only`. |
| `GET` | `/notifications/unread-count` | S | Cached 30 s. |
| `POST` | `/notifications/{id}/read` | S | |
| `POST` | `/notifications/read-all` | S | |

### Recommendations — `/recommendations`

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/recommendations/communities` | S | With a human-readable `reason` per item. |
| `GET` | `/recommendations/people` | S | With a `reason`. |
| `POST` | `/recommendations/dismiss` | S | Body: `kind`, `target_id`. Suppresses it. |
| `GET` | `/interests` | — | The interest catalogue for onboarding. |

### Reports — `/reports`

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/reports` | S | Body: `target_kind`, `target_id`, `reason`, `note?`. Vault items are not a valid target. A report triggers a `trigger: "report"` re-check immediately, so a machine settles what a machine can before anything reaches a human queue. |

### Admin — `/admin`

Separate router, IP-allowlisted, staff-only. Not part of the public OpenAPI schema.

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/admin/tickets` | `R:moderator+` | Queue filtered to the caller's role. |
| `POST` | `/admin/tickets/{id}/assign` | `R:moderator+` | |
| `POST` | `/admin/tickets/{id}/message` | `R:moderator+` | Supports `internal: true`. |
| `POST` | `/admin/tickets/{id}/request-info` | `R:moderator+` | |
| `POST` | `/admin/tickets/{id}/reject` | `R:admin+` | Requires a justification. |
| `POST` | `/admin/tickets/{id}/approve-release` | `R:super_admin` + SU | **Passcode release.** Requires password, TOTP, email OTP, and a 50-char justification. Returns the `reveal_code` once. |
| `GET` | `/admin/users/{id}` | `R:admin+` | Metadata only. No content, no vault, no plaintext email. |
| `POST` | `/admin/users/{id}/block` | `R:admin+` | |
| `POST` | `/admin/users/{id}/unblock` | `R:admin+` | |
| `GET` | `/admin/reports` | `R:moderator+` | |
| `GET` | `/admin/moderation/queue` | `R:moderator+` | Held content, oldest first, with the verdict, rule, rationale, rubric version, and the model's spans. |
| `POST` | `/admin/moderation/{review_id}/resolve` | `R:moderator+` | Body: `outcome` (`stood`/`overturned`), `note`. An overturn republishes, notifies the author, and writes the case into the golden set. |
| `GET` | `/admin/moderation/stats` | `R:admin+` | Verdict distribution, overturn rate per rule, tier-3 share. The calibration dashboard, and the source of the transparency report. |
| `POST` | `/admin/content/{kind}/{id}/remove` | `R:moderator+` | |
| `GET` | `/admin/audit` | `R:admin+` | Read-only. Filterable. |
| `POST` | `/admin/roles/{user_id}` | `R:super_admin` + SU | Grant or revoke. |

**There is no `/admin/users/{id}/impersonate`, no `/admin/users/{id}/password`, and no `/admin/vault/*`.** Their absence is the enforcement of R4 and R2 from [05](05-security-and-crypto.md). If one of these ever appears in a diff, that diff is rejected.

## 8. Idempotency

State-changing operations that a client might retry accept an `Idempotency-Key` header (a client-generated UUID). The key and its response are cached in Redis for 24 hours; a repeat with the same key returns the cached response without re-executing.

Required on: `POST /stories`, `POST /vault/items`, `POST /vault/items/{id}/complete`, `POST /tickets`, `POST /comments`.

Like and follow endpoints are naturally idempotent through deterministic composite `_id` upserts, so they need no key.

## 9. Versioning

The version is in the path (`/v1`). Additive changes — a new field, a new endpoint, a new error code — ship inside `v1`. Breaking changes get `/v2`, with `v1` supported for at least six months.

**Mobile clients pin their expectations,** so any field a client reads must never be removed or retyped within a major version. Clients send `X-Client-Version`, and the server can return a `data.upgrade_required` hint for a version below the supported floor.

## 10. OpenAPI and generated types

FastAPI produces the schema; `make types` generates TypeScript interfaces into `packages/api-types` and Dart models into `app/lib/gen/api_models.g.dart`. Both are committed, and CI fails on drift.

For this to work, response shapes must be declared. The reference project used `response_model` **zero times** and hand-built every response dict, which meant its OpenAPI schema described almost nothing. Here, every route declares a `response_model`, wrapped in a generic envelope type:

```python
class Envelope[T](BaseModel):
    success: bool
    message: str
    data: T | None

@router.get("/stories/{story_id}", response_model=Envelope[StoryOut])
async def get_story(...): ...
```

Response models use an `Out` suffix (`StoryOut`, `VaultItemOut`, `UserOut`), request models are named for the action (`CreateStoryRequest`, `PublishStoryRequest`). A response model is what defines the public contract, and it is what guarantees a field like `password_hash` cannot leak through an over-broad dict — a discipline the reference had no mechanism for.
