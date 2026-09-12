# Security and cryptography

> The platform must be structurally incapable of reading a user's vault. Not
> unwilling — incapable.

Read this before touching `users`, `user_keys`, `user_passcodes`, `vault_items`
or `audit_logs`.

## The six requirements

Every construction below exists to satisfy one of these. When a feature
conflicts with one, the feature loses.

1. A full dump of MongoDB, Redis and the buckets reveals nothing about vault contents.
2. A malicious operator with database access *and* the escrow key still cannot decrypt a vault.
3. A vault is decryptable only by someone holding **both** the account password and the vault passcode.
4. Nobody, at any privilege level, can authenticate as a user.
5. Every privileged access to escrowed material leaves an immutable record the affected user can read.
6. Absence of collected data is the primary defence. No email, phone, real name or location — unless the user opts in, and then only in a form we cannot read.

## Three secrets, three fates

| Secret | Held by | Recoverable by us | Unlocks |
|---|---|---|---|
| Account password | the user only | **never** — Argon2id hash only | login |
| User Master Key (UMK) | derived on device | **never** — stored only as ciphertext | half of every item key |
| Vault passcode | the user, plus an escrowed copy | **yes**, via an audited ticket | the other half |

The load-bearing property: **the escrowed secret is useless alone.** A
super_admin can release a passcode but has no path to the UMK, so no path to a
single decrypted byte.

## Key derivation

```
salt_pw     = 16 random bytes, per user       (historic name — it salts the passcode)
salt_pc     = 16 random bytes, per passcode
salt_item   = 16 random bytes, per vault item

KEK_pw      = Argon2id(password, salt_pw)                        → 32 bytes
KEK_pc      = Argon2id(passcode, salt_pc)                        → 32 bytes

UMK         = CSPRNG(32)
wrapped_umk = nonce || AES-256-GCM(KEK_pw, nonce, UMK,
                                   aad = "story.umk.v1|" || user_id)

KEK_item    = HKDF-SHA256(ikm  = UMK || KEK_pc,
                          salt = salt_item,
                          info = "story.vault.item.v1|" || item_id,
                          len  = 32)

DEK         = CSPRNG(32)
wrapped_dek = nonce || AES-256-GCM(KEK_item, nonce, DEK,
                                   aad = "story.dek.v1|" || item_id)

ciphertext  = AES-256-GCM over 1 MiB chunks, per-chunk nonce from
              HKDF(DEK, "chunk|" || index)
```

**One key from two secrets, in one step.** HKDF over the concatenation makes both
halves mandatory by construction rather than by policy, and neither input is
recoverable from the output.

**`item_id` in `info`** domain-separates every item, so a key recovered for one
item is worthless for another.

**AAD binds ciphertext to its record.** An attacker with database write access
cannot move user A's `wrapped_dek` onto user B's item — the tag check fails.

**Chunked, not whole-file.** Vault items are gigabyte-scale. Chunking allows
constant-memory streaming on a phone, resumable upload and range playback.

**Compression happens before encryption, never after.** Ciphertext does not
compress; gzipping it spends CPU to add a header.

### Argon2id parameters

```
client, per unlock    memory 64 MiB   iterations 3   parallelism 4
server, per login     memory 64 MiB   iterations 3   parallelism 2
```

Parameters are stored **with each hash** in PHC string format, so the cost factor
can be raised later: on successful login a below-policy hash is re-computed
inside the same request. Hardcoding them at the verification site would make
migration impossible.

Server-side derivation is a denial-of-service vector — a login that allocates
64 MiB per request is trivially exhaustible. Rate limiting runs **before** the
hash, and parallelism is reduced so per-request CPU is predictable.

### Password and passcode

- **Password** — minimum 10 characters, no composition rules, no rotation. Composition rules push people toward `Password1!` and measurably reduce entropy.
- **Passcode** — a 6-digit PIN or an 8+ character passphrase. The PIN's weak entropy is tolerable only because it is never verifiable offline: an attacker also needs the UMK, which needs the password, which is rate-limited server-side.
- **Lockout** — 5 consecutive failures, then 15 minutes with exponential backoff. The counter is server-side in Redis, so reinstalling the app does not reset it.

## Tokens

**Access** — JWT, HS256, 30 minutes. Carries `user_id`, `role`, `status`,
`family_id`, `jti`. Deliberately carries no mutable profile data, so a renamed
user is never stale.

**Refresh** — not a JWT. 32 random bytes, stored as a SHA-256 hash in Redis,
30 days, belonging to a **family** representing one device lineage.

**Rotation with reuse detection.** On refresh the presented token is deleted and
a tombstone written. A token that matches a tombstone is a replay of a stolen
token: the whole family is revoked and the user notified. Token theft becomes a
detectable, self-limiting event rather than a silent persistent compromise.

**Timing.** A login for an unknown username verifies against a fixed dummy hash
so it takes the same wall-clock time as a real one. Otherwise the endpoint is a
username enumeration oracle — a real leak for an anonymity product.

## Anonymity

Anonymity is not achieved by omitting a name field.

| Vector | Measure |
|---|---|
| IP address | truncated before storage, kept 30 days for abuse only, never joined to content |
| Device fingerprint | coarse by design: platform, OS major, app version, model. Never an advertising or device ID |
| Story images | EXIF stripped server-side before storage (`app/core/images.py`) |
| Publish time | stored to the minute, so two accounts cannot be linked by microsecond co-occurrence |
| Share links | opaque slug, never a `user_id`, no referrer leaked |
| Social graph import | no such feature. No contact upload, no address-book permission |
| Writing style | an unmitigated risk, stated plainly: stylometry can deanonymize long-form text against a known corpus |

**The AI boundary.** Content sent to a hosted model carries no `user_id`, no
username, no fingerprint, no session id — the request is the text and the rubric.
Drafts are never sent at all. Vault content is never sent, and that is a
statement of fact rather than policy: it is ciphertext and the server holds no
key. **Any proposal requiring a model to read vault content is a proposal to
delete the vault**, and is refused on that basis.

## What must hold

- `wrapped_dek` moved from one user's item to another fails to decrypt.
- Vault search returns byte-identical, timing-equivalent responses for a nonexistent label and a wrong passcode.
- A login for a nonexistent username takes the same time as one for an existing username.
- Refresh-token reuse revokes the entire family.
- A password **change** preserves vault access; a password **reset** leaves the vault untouched and clears chat only — asserted by `backend/tests/api/test_reset_forgets_chat.py`.
- A full database dump plus escrow access yields no plaintext vault file.

## Not built

Screenshot blocking (`FLAG_SECURE`) on vault screens, crash reporting with PII
scrubbing, an external audit-chain head store, and an external cryptographic
review. Named here so their absence is deliberate rather than assumed.
