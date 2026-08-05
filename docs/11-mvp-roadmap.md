# 11 — MVP Roadmap

Nine phases. Mobile first, mobile finished, then web. Every phase has a definition of done that is verifiable rather than asserted.

## Sequencing principles

**S1 — Foundations before features.** Tokens, components, and the API skeleton come first. Building three screens and then introducing a design system means retrofitting three screens, and the hardcoded values from those screens survive forever.

**S2 — Vertical slices, not horizontal layers.** Each feature phase ships its backend, its API, and its mobile UI together and is genuinely usable at the end. A phase that delivers "the stories API" with no way to write a story cannot be tested by a human and hides its own defects.

**S3 — Security work is never a later phase.** Crypto ships with the vault, redaction ships with logging, the audit log ships with the first privileged action. There is no "harden it before launch" milestone, because that milestone always slips into the launch.

**S3a — Moderation is security.** The safety gate ships in the same phase as the first publishable story, not in the AI phase. A platform that can publish before it can refuse has a window during which it is an unmoderated anonymous network, and that window is exactly when a closed beta is running. The *suggestion* half of the AI layer is a feature and can wait; the *gate* half cannot.

**S4 — Web starts only after the mobile app is finalized.** Explicitly per the requirement. Finalized means the token file, the component contract, and the API contract have stopped changing — those are exactly the three things the web app consumes, and building against moving versions of them doubles the work.

**S5 — Every phase leaves `main` deployable.** Feature flags gate incomplete work. No long-lived branches.

```mermaid
flowchart TD
    P0["Phase 0<br/>Foundations + ports"] --> P1["Phase 1<br/>Onboarding"]
    P1 --> P2["Phase 2<br/>Stories + safety gate"]
    P2 --> P3["Phase 3<br/>Categories, communities,<br/>social + fit check"]
    P3 --> P4["Phase 4<br/>Vault"]
    P4 --> P5["Phase 5<br/>Settings, email, recovery"]
    P5 --> P6["Phase 6<br/>Admin, tickets,<br/>moderation queue"]
    P6 --> P7["Phase 7<br/>AI suggestions & discovery"]
    P7 --> P8["Phase 8<br/>Hardening & mobile launch"]
    P8 --> P9["Phase 9<br/>Web"]
```

---

## Phase 0 — Foundations

Nothing user-visible. Everything downstream depends on it.

**Repo and tooling**
- Monorepo scaffold per [02](02-repo-structure-and-conventions.md): `app/`, `web/`, `backend/`, `packages/`, `tools/`, `Makefile`.
- `docker-compose.yml` with MongoDB, Redis, MinIO.
- All CI jobs wired and **actually failing on a deliberate violation** — verified, not assumed.
- Husky + lint-staged.

**Design system**
- `packages/design-tokens/tokens.json` with both themes complete.
- Both generators emitting `tokens.g.dart` and `tokens.css`.
- `design-guard` lint rules written and proven to fail on a raw hex.
- `packages/icons` with the first ~40 icons and both generators.

**Backend skeleton**
- `main.py`, `config.py`, `responses.py`, `error_handlers.py`, `logging.py` with the redaction processor.
- `db/mongo.py`, `db/redis.py`, `db/indexes.py`, `db/keys.py`.
- `core/deps.py` with every `Annotated` alias, `csrf_protect`, `rate_limit`, `require_role`, `idempotent`.
- `core/crypto.py` and `core/security.py`, **at 100% test coverage**.
- `/health` and `/health/ready`.
- Contract tests: envelope shape, route policy enforcement.

**Provider ports** — [01](01-tech-stack.md) Decision 10
- The four Protocols in `ports/`, plus `factory.py` resolving each from settings at startup.
- `S3CompatAdapter` verified against **both** MinIO and R2, and `LocalDiskAdapter`.
- Storage profiles (`vault`, `media`, `export`) wired and independently configurable.
- `NullAdapter` for AI, `ConsoleAdapter` for mail, `LocalKeyfileAdapter` for KMS.
- The **adapter contract test suite** — one suite every adapter must pass. This is the artifact that makes a later vendor swap a half-day rather than a rewrite.
- `port-guard` in CI, proven to fail on a deliberate `import aioboto3` in a controller.

**Flutter skeleton**
- `app.dart`, theme wiring, `ThemeController` with persistence and no-flash resolution.
- `Result<T>`, `ApiClient` with all interceptors, `go_router` with the `guard` function.
- The full primitive component set from [04](04-component-library.md) plus a gallery screen.

**Definition of done**
- [ ] `make check` passes from a clean clone.
- [ ] Changing one hex in `tokens.json` visibly changes both apps after `make tokens`.
- [ ] The gallery screen renders every component variant in both themes at 100% and 160% text scale.
- [ ] `design-guard` fails on an intentionally added raw color, and CI shows it.
- [ ] Redaction test passes: a payload of every denied key leaks nothing.
- [ ] Codegen drift check fails on a hand-edited generated file.
- [ ] Switching `STORAGE_PROFILE_VAULT` from `minio` to `r2` requires no code change and all storage tests still pass.
- [ ] `port-guard` fails on a deliberate vendor import outside `adapters/`.

**Why this phase is worth its cost.** Everything after it is faster, and none of the shortcuts that produce a hardcoded-value codebase are available. The reference project's token layer was theme-ready but its theme switch was never built; by the time anyone tried, two hundred components had accumulated assumptions. Building the switch in Phase 0 is what makes multi-theme real.

---

## Phase 1 — Onboarding

The first end-to-end flow. A user can create an account and sign in.

**Backend**
- `users` and `user_keys` collections with indexes.
- `POST /auth/signup`, `/auth/signin`, `/auth/refresh`, `/auth/signout`, `/auth/signout-all`, `GET /auth/me`.
- `POST /auth/username-available`.
- `POST/GET /users/me/keys`.
- Argon2id with PHC-string parameter storage and login-time re-hash on policy change.
- Token families, rotation with reuse detection, denylist.
- Constant-time login failure.
- `interests` collection, seeded. `GET /interests`.
- `PATCH /users/me` for display name, bio, interests.
- `POST /users/me/avatar/regenerate`.
- Login alerts and the `devices` collection.

**Mobile**
- Welcome, sign up, sign in, forgot-password stub.
- Username availability check with debounce.
- Password strength meter with the breached-password check.
- Terms acceptance.
- On-device UMK generation and key upload.
- Interest picker.
- Avatar reveal with regenerate.
- Session persistence, silent refresh, auto sign-out on refresh failure.

**Definition of done**
- [ ] A new account can be created and signed into on a real device.
- [ ] Killing and reopening the app keeps the user signed in.
- [ ] A username collision returns `USERNAME_TAKEN` and the form shows it on the field.
- [ ] `wrapped_umk` is present in `user_keys` and the plaintext UMK appears in no log and no request body.
- [ ] Refresh token reuse revokes the family (integration test).
- [ ] Login timing for an unknown username matches a known one within noise.
- [ ] Signing in on a second device produces a login alert.
- [ ] No personal field exists anywhere in the schema.

---

## Phase 2 — Stories and the safety gate

The core product loop, and the thing that stops it becoming a sewer. Per S3a these ship together.

**Backend**
- `stories` and `comments` collections with all partial indexes, including `moderation.state` on the feed filters.
- `content_reviews` collection.
- `POST /stories`, `PATCH`, `DELETE`, `POST /{id}/publish`, `/unpublish`.
- `GET /stories/mine`, `/stories/{id}`.
- `POST /stories/media/presign`, `/complete`.
- `strip_exif_and_thumbnail` worker.
- `publish_scheduled_stories` cron.
- Excerpt and reading-time derivation.
- Opaque slug generation.

**Sanity layer — tiers 1 and 2 only** ([12](12-ai-layer.md))
- `ai/cascade.py` with the verdict merge and the tier budget.
- `ai_rules.py`: identifier regexes, blocklists, spam heuristics, repetition detection.
- `ai_local.py`: the ONNX classifier, loaded at startup, refusing to boot if absent.
- `safety.v1.yaml` and `exposure.v1.yaml` rubrics.
- Safety gate and exposure check on publish; care signal async.
- `POST /stories/{id}/precheck`.
- The golden set with its first ~300 labelled cases, and `ai-eval` in CI.
- Tier 3 **not built yet** — uncertainty resolves to `hold`, and the queue is drained manually by the team.

**Mobile**
- Story composer: title, body, autosave to draft.
- Visibility picker with schedule.
- Image attachment with an EXIF-stripping notice.
- Debounced `precheck` while writing, surfacing exposure spans inline.
- Held / blocked states rendered as states, with the rule cited and an appeal affordance (the ticket itself lands in Phase 6; until then the button opens a stub).
- Draft list, published list, scheduled list.
- Story detail with `reading` typography and the max-width cap.
- Edit within the 24-hour window.
- The pre-first-public-story writing-style warning.

**Definition of done**
- [ ] A story can be written, saved as a draft, and published in all three visibilities.
- [ ] A scheduled story publishes within one minute of its time.
- [ ] Drafts survive app kill mid-compose.
- [ ] Published story images have no EXIF (verified with `exiftool`).
- [ ] The share URL contains an opaque slug and no `user_id`.
- [ ] A private story returns `404` to another account, not `403`.
- [ ] `published_at` is truncated to the minute.
- [ ] Story body reads comfortably at 160% text scale.
- [ ] **A draft produces zero `AIPort` calls** — asserted by a test, not by inspection.
- [ ] A story containing a phone number and an employer name warns before publish and publishes anyway on `exposure_ack`.
- [ ] A spam story is blocked with its rule cited in language a human understands.
- [ ] The golden set's emotional-distress slice has **zero** false blocks.
- [ ] Inline gate p95 is under 900 ms on the deployment target.
- [ ] With the AI adapter forced to fail, publish returns `MODERATION_UNAVAILABLE`, the story is preserved, and nothing reaches a feed.

---

## Phase 3 — Categories, communities, social, and the fit check

Stories become social, and the taxonomy from [00](00-product-overview.md) §6.1 becomes real.

**Backend**
- `community_categories`, `communities`, `community_members`, `connections`, `reactions`, `notifications`.
- Seed script: all 15 categories, ~30 curated communities spread across every one of them — **not just the reflective ones.** `job-search`, `money`, `study`, and `starting-over` each ship with at least two real rooms, because a taxonomy with empty shelves teaches users that the product is only about grief.
- `GET /communities/categories`, browse by category and tone, detail, join, leave, my-communities.
- `GET /communities/{slug}/members`, gated on `member_directory`.
- Follow, unfollow, followers, following, block, blocked.
- Like and unlike for stories and comments.
- Comments with one nesting level, tombstone handling; safety gate on comments.
- `GET /stories/feed`.
- `fan_out_new_story`, `fan_out_comment` workers.
- Notifications list, unread count, mark read.
- `reconcile_counts` cron.

**Sanity layer — the fit check**
- The four tone rubrics, each with its own labelled slice in the golden set.
- Fit scoring against the target community, with per-room `fit_threshold` overrides.
- `warn` / `redirect` bands, suggested-community generation, and `fit_override`.
- `wrong_community` reports routed to a fit re-check rather than to a human.

**Mobile**
- Category browse → community browse → community detail with a join control.
- Community picker in the composer, defaulting to the best-fit suggestion.
- The `redirect` sheet: up to three suggested rooms plus "publish here anyway".
- Home feed with skeletons, pull-to-refresh, cursor pagination.
- Reaction bar; comment thread with composer.
- Public profile with follow.
- Notification list with badge.
- Block from a story or a profile.

**Definition of done**
- [ ] The feed renders followed users and joined communities, correctly paginated.
- [ ] Held and blocked stories never appear in any feed **at the query level**, verified against the raw API.
- [ ] A double-tapped like produces one like (idempotency verified).
- [ ] Blocking removes the user from the feed in both directions.
- [ ] Comments from a deleted account render as a tombstone without breaking the thread.
- [ ] Counts match a recomputed aggregate after the nightly job.
- [ ] The feed's first paint is under 1.5 s on a mid-range Android over 4G.
- [ ] Every empty list shows a real `EmptyState`, never a blank screen.
- [ ] Adding a sixteenth category is a seed row and a deploy of data only — **no code change**, verified by actually doing it.
- [ ] A job-search story submitted to a grief community is redirected with sensible suggestions, and publishes anyway on override.
- [ ] A grief story submitted to a grief community scores above the warn band. Manual review of 30 real-shaped samples.
- [ ] `member_directory: false` makes `/members` return `404`, not `403`.

---

## Phase 4 — Vault

The most security-sensitive phase. Nothing here is rushed.

**Backend**
- `vault_items` and `user_passcodes` with all indexes including the unique sparse label index.
- `VaultRepository` with the hidden-item guarantee enforced in the query.
- Every `/vault/*` endpoint from [08](08-api-contract.md).
- KMS envelope encryption for passcode escrow.
- Presigned upload and download.
- `verify_vault_object` worker and `reap_pending_uploads` cron.
- Quota enforcement.
- Passcode lockout with exponential backoff.
- Timing-equalized search.

**Mobile**
- Vault home with an encrypted-thumbnail grid.
- Passcode creation with the PIN-versus-passphrase trade-off explained.
- `PasscodePad` with no clipboard, no autofill, `FLAG_SECURE`.
- Chunked streaming encrypt-and-upload with progress and resume.
- Chunked streaming download-and-decrypt with in-app viewers for image, video, PDF, and audio.
- Hidden-item creation with label and encrypted hint.
- Label search.
- Auto-lock: 60 s background, device lock, session end.
- Biometric unlock, opt-in.
- Export with re-entered passcode and a plain warning.
- The Recovery Kit offer, on first vault use.

**Definition of done**
- [ ] A 400 MB video uploads, downloads, and plays correctly.
- [ ] Ciphertext in R2 is unreadable and carries no filename or extension.
- [ ] The plaintext filename appears nowhere server-side.
- [ ] A hidden item is absent from `GET /vault/items` at the raw API level, not just in the UI.
- [ ] Vault storage totals and counts exclude hidden items.
- [ ] Label search for a nonexistent label and a wrong passcode are byte-identical and timing-equivalent.
- [ ] Moving user A's `wrapped_dek` onto user B's item fails the AEAD tag check.
- [ ] Vault locks on all three triggers.
- [ ] Screenshots are blocked on every vault screen and the recents thumbnail is obscured.
- [ ] No decrypted file appears in shared storage, the gallery, or a device backup.
- [ ] A full database plus KMS dump yields no plaintext vault content (manual exercise, documented).
- [ ] Key derivation does not block the UI thread.
- [ ] Every security checklist item in [05](05-security-and-crypto.md) §13 is green.

**This phase gets an internal security review before merge.** Not a code review — a review specifically against [05](05-security-and-crypto.md), by someone who did not write the code.

---

## Phase 5 — Settings, email, and recovery

Everything a user needs to manage and, if necessary, rescue their account.

**Backend**
- Email add, verify, resend, remove, with blind index, ciphertext, and precomputed mask.
- OTP with `HSETNX` attempt preservation, lockout, and resend cooldown.
- Password change (vault-preserving) and password reset (vault-destroying).
- `acknowledged_vault_loss` server-side gate.
- Orphaned-key marking and bulk delete.
- Recovery Kit create, delete, and use.
- Sessions list and per-session revocation.
- `audit_logs` with hash chaining, `verify_audit_chain` cron, external chain-head write.
- Deactivate and delete with a grace period.
- `send_email_otp` and `send_security_alert` workers.

**Mobile**
- Settings home.
- Theme picker with live preview.
- Reading size picker.
- Email add and verify with a masked display.
- Change password.
- Forgot password with the full typed-confirmation warning showing live item count and size.
- Recovery Kit creation with word confirmation.
- Recovery Kit use after a reset.
- Active sessions with revoke.
- Security activity log.
- Passcode management.
- Deactivate and delete.

**Definition of done**
- [ ] A password change preserves vault access; a reset destroys it and the app says so beforehand.
- [ ] The reset warning shows the real item count and byte total.
- [ ] A reset without `acknowledged_vault_loss` is rejected by the API.
- [ ] Orphaned items are listed as unrecoverable with no misleading retry affordance.
- [ ] A Recovery Kit restores vault access after a reset.
- [ ] Requesting a new OTP does not reset the failure counter.
- [ ] The reset-request endpoint responds identically for existing, existing-without-email, and nonexistent usernames.
- [ ] No endpoint returns a plaintext email address.
- [ ] Revoking a session logs that device out within one refresh cycle.
- [ ] The audit chain verifies; a manually tampered entry is detected.
- [ ] Theme choice survives a restart with no flash.

---

## Phase 6 — Admin and tickets

The escrow release flow, end to end.

**Backend**
- `support_tickets` with the full state machine.
- Ticket create with all five preconditions, per-ticket email verification, messaging.
- Role-based routing enforced by dependency.
- `require_step_up` with password, TOTP, and email OTP.
- Passcode release approval with justification and optional dual approval.
- Reveal token, one-time code, 24-hour expiry, `expire_reveal_links` cron.
- Every `/admin/*` endpoint.
- `reports` and the moderation queue: `GET /admin/moderation/queue`, `POST /admin/moderation/{review_id}/resolve`, `GET /admin/moderation/stats`.
- `content_appeal` tickets wired to `POST /stories/{id}/appeal`; an overturn republishes, notifies, and writes the case into the golden set.
- `expire_holds` cron — holds older than 24 hours auto-resolve to `allow` and page on-call.
- Full audit coverage of every privileged action.
- Staff TOTP enrolment, IP allowlist, idle timeout.

**Admin surface**
A minimal Next.js app — the one exception to S4, because it is staff-only, has no public surface, and does not consume the mobile component contract. Ticket queue, ticket detail, step-up approval, user metadata view, moderation queue, audit viewer.

**Mobile**
- Ticket creation from Settings.
- `TicketStatusCard` with the live timeline.
- Ticket messaging.
- The reveal screen with all three checks and a 10-minute countdown.

**Definition of done**
- [ ] A user with a verified email can open a passcode ticket; one without cannot.
- [ ] All five preconditions are individually enforced, each with a specific message.
- [ ] An `admin` cannot approve a `passcode_release`.
- [ ] Approval requires all three step-up factors plus a 50-character justification.
- [ ] The reveal link expires at 24 hours and the blob is destroyed.
- [ ] The reveal screen requires session, email OTP, and the one-time code — and **never asks for the account password**.
- [ ] A released passcode alone cannot decrypt anything (verified without the password).
- [ ] Every step appears in the user's Security activity log in plain language.
- [ ] `audit_logs` rejects an update attempt at the database-role level.
- [ ] No impersonation, password-set, or vault-read endpoint exists anywhere in the admin surface.
- [ ] A blocked story can be appealed, overturned, republished, and the overturned case appears in the golden set as a new test.
- [ ] A hold left untouched for 24 hours publishes itself and pages on-call. **A backlog must never become a silent ban.**
- [ ] A moderator reviewing content sees `user_id` and nothing else identifying — because nothing else exists.

---

## Phase 7 — AI suggestions, discovery, and tier 3

The last feature phase. The gate has been live since Phase 2; this phase adds the half of the AI layer that is a feature rather than a control, and closes the manual review loop by adding the hosted tier.

**Backend — suggestions**
- Local embedding pipeline: `embeddings.py` worker, `refresh_interest_embeddings`, story embeddings on publish for public stories only.
- `recommendations` collection and the nightly `recompute_recommendations` worker.
- `GET /recommendations/communities`, `/people`, `POST /dismiss`.
- Human-readable `reason` generation for every recommendation.
- `GET /stories/discover`.
- Improved avatar generation from the seed.

**Backend — tier 3**
- `ai_anthropic.py` and `ai_openai_compat.py`, both passing the adapter contract suite.
- Escalation on the uncertain slice only; `AI_TIER3_TIMEOUT_MS` and fallback to the tier-2 verdict.
- Prompt-injection fixtures added to the golden set and gating CI.
- The cost dashboard: `tier_reached` distribution and per-day hosted-call count.
- Config validator rejecting `AI_FAIL_MODE=allow` in `production`.

**Mobile**
- Suggested communities and people, each with its visible reason.
- Discover feed.
- Dismiss.
- Helpline resource sheet when a care signal fires.

**Definition of done**
- [ ] Recommendations are relevant to declared interests and joined communities (manual review of 20 accounts spanning at least six categories, not only the reflective ones).
- [ ] Every recommendation shows a reason a user can understand.
- [ ] Dismissal persists.
- [ ] The request path is a single primary-key read — no inference at request time.
- [ ] Embeddings are computed locally; the hosted provider bill contains zero embedding calls.
- [ ] A care signal never removes, hides, or reports content; it only offers resources to the author.
- [ ] No recommendation exposes any signal derived from a private story, a draft, a held story, or a vault item.
- [ ] Turning `AI_TIER3_ENABLED=false` leaves the platform fully safe, with more holds and no crashes.
- [ ] A hosted-provider outage produces holds, not published-unreviewed content, and not a broken publish button.
- [ ] Every injection fixture fails to change a verdict.
- [ ] Tier-3 share of total checks is under 15% on a week of real traffic.

The private-content item is a hard constraint. Feeding private content into a recommendation model would make private stories observable through their effects, which is a subtler but real violation of the product's promise. Only public stories, joined communities, and declared interests are inputs.

---

## Phase 8 — Hardening and mobile launch

No new features. Only the work that makes it safe to ship.

- Load test: feed, story creation, vault upload. Fix what the numbers expose.
- Index coverage verification via `explain()` on every query in the codebase.
- Full accessibility pass: screen reader end to end, 160% text, contrast per theme.
- Performance: cold start under 2 s, feed first paint under 1.5 s, 60 fps scroll, APK under 30 MB.
- Certificate pinning with a backup pin and a kill switch.
- Sentry with PII scrubbing verified.
- **External security review of [05](05-security-and-crypto.md) and its implementation.**
- Penetration test of auth, vault, and the admin surface.
- Privacy policy and terms, written to match what the system actually does — including what the AI layer reads, what leaves the platform, and what the hosted provider is contractually forbidden from doing with it.
- Moderation calibration review: overturn rate per rule over the beta, and a rubric revision for anything above threshold.
- App Store and Play Store listings, with the data-safety declarations completed honestly.
- Support runbooks for every ticket type.
- Incident response runbook and on-call rotation.
- Backup and restore drill, actually performed.
- Staging soak with synthetic load for one week.
- Closed beta with 50 real users; triage everything they hit.

**Definition of done**
- [ ] External security review passed with no unresolved high or critical findings.
- [ ] Penetration test findings resolved or explicitly accepted with a documented rationale.
- [ ] Store data-safety declarations match reality field by field.
- [ ] Every query is index-covered.
- [ ] Restore from backup verified end to end.
- [ ] Beta feedback triaged; every crash fixed.
- [ ] Transparency report template ready, including verdict distribution, appeal count, and overturn rate.
- [ ] No beta user reports a wrongly blocked story that survived appeal review.

---

## Phase 9 — Web

Begins only when Phase 8 is complete and the token file, component contract, and API contract are frozen.

**Order within the phase**
1. **Foundation.** Next.js scaffold, `tokens.css` wired into `@theme inline`, `apiCall` and `TResult`, `backendGet` and `forwardToBackend`, middleware with security headers and theme resolution.
2. **Components.** The full primitive set with props matching Flutter exactly, plus a `/gallery` route.
3. **Auth.** Signup, signin, keys initialization, session handling through the BFF.
4. **Public story pages.** `app/s/[slug]` — server-rendered, `generateMetadata`, Open Graph, indexable. **The reason Next.js was chosen**, so it lands early enough to validate the decision.
5. **Feed, stories, communities, social.**
6. **Vault.** Fully client-side with WebCrypto and a WASM Argon2id worker.
7. **Settings and tickets.**
8. **Polish.** Responsive layouts, keyboard navigation, `axe` on every route, Lighthouse.

**Definition of done**
- [ ] Every component's props match the Flutter implementation exactly; both galleries render identically.
- [ ] A public story page scores ≥ 95 on Lighthouse SEO and is indexable.
- [ ] A shared story link produces a correct preview in WhatsApp, iMessage, Slack, and X.
- [ ] Theme persists across reload with no flash.
- [ ] Vault upload, download, and unlock work in the browser with WebCrypto.
- [ ] No token is reachable from client JavaScript (verified in DevTools).
- [ ] `axe` reports zero violations on every route in both themes.
- [ ] Every flow is keyboard-operable end to end.
- [ ] Changing a token in `tokens.json` updates both apps in one commit.

---

## Cross-phase practices

| Practice | Applies |
|---|---|
| `main` deployable at all times | Every phase |
| Feature flags for incomplete work | Every phase |
| A phase is not done until its DoD is fully green | Every phase |
| Security-relevant code reviewed by a second person against [05](05-security-and-crypto.md) | Phases 1, 4, 5, 6 |
| Contract tests updated with every new route | Every phase |
| Golden tests updated with every component change | Every phase |
| Index declared in the same commit as the query that needs it | Every phase |
| Golden-set cases added in the same PR as any rubric or check change | Phases 2, 3, 6, 7 |
| A new external vendor arrives as an adapter behind an existing port, never as a direct import | Every phase |
| Docs updated in the same PR as the behaviour they describe | Every phase |

**The last row is the one that decays first.** These twelve documents are only useful while they are true. A PR that changes the token contract, adds an error code, or alters a collection and does not touch the corresponding document has introduced a second source of truth — and from that point on, nobody can trust either one. Reviewers should treat a stale doc as a defect on the same footing as a failing test.

## Explicitly deferred

Out of scope for everything above, listed so the boundary is not renegotiated mid-phase:

Direct messaging, video stories, live audio, user-created communities, story collections and series, reactions beyond a single like, push notifications, in-app search across comments, translation, monetization, story analytics for authors, group vaults or shared vault items, desktop apps, a dedicated vector database, on-device pre-checking in Flutter, multilingual fit checking, and any form of advertising.

Each of these is a reasonable future feature. None of them is required to prove that people will tell their story to strangers who cannot judge them, which is the only question the MVP exists to answer.
