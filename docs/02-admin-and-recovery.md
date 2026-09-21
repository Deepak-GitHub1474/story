# Admin and recovery

> Every privileged action is a ticket, every ticket is visible to the affected
> user, and every step is written to an append-only log. There is no back channel.

## The recovery matrix

Four things can be lost and they have four different outcomes. The interface
must communicate this *before* someone is in trouble, not after.

| Lost | Account back? | Vault back? | Chat history? | Path |
|---|---|---|---|---|
| Password, email set | yes | yes | **no** — cleared | email OTP → new password |
| Password, no email | **no** | no | no | nothing. The account is unreachable |
| Passcode, email set | never lost | yes | unaffected | release ticket → super_admin |
| Passcode, no email | never lost | **no** | unaffected | no ticket without a verified email |
| Label of a sealed item | fine | **no** — that item | unaffected | the label is not stored readably |
| Device, credentials known | yes | yes | yes | sign in again |

**A password reset does not touch the vault.** The UMK is wrapped under a key
derived from the *vault passcode*, not the account password. `complete_reset`
writes `password_hash` and revokes sessions, and never reads or writes
`user_keys`, `user_passcodes` or `vault_items`.

**A password reset does clear chat.** The chat identity key is backed up wrapped
under the account password. A forgotten password cannot unwrap it and neither can
the server, so the reset erases the caller's side rather than leaving unreadable
ciphertext behind a banner nobody can act on.

**Change and reset are different flows.** A *change* supplies the current
password, so the client re-wraps the same chat identity and nothing is lost. They
must never be merged into one screen.

Two names survive from an older design and are misleading: the reset body field
`acknowledged_vault_loss` now acknowledges **chat** loss, and
`vault_items.key_state` still accepts `"orphaned"` although nothing ever writes
it, because nothing destroys vault keys any more.

## The passcode release ticket

A ticket cannot be opened unless the user has a **verified email** — without it
there is no out-of-band channel and no identity signal beyond the session — and
no other passcode ticket is already open.

States: `submitted → under_review → needs_more_info → reveal_ready → closed`,
plus `rejected`. Every transition writes an audit entry, and both the user and
staff see the same timeline.

Release requires a live `passcode_release` ticket belonging to that account, a
justification of at least 50 characters, and a TOTP code from the acting staff
member's own authenticator. It moves the ticket to `reveal_ready` and writes
`passcode_release.approved` with the justification attached.

**The account password is deliberately not one of the checks.** The user is
already in a live session, so the password is already proven. Asking again would
add nothing except a screen, reachable from a link, that asks for an account
password — the exact shape of every credential-phishing page ever built.

## Roles

| Role | Handles |
|---|---|
| `user` | default, every account |
| `moderator` | content reports and appeals. No account access |
| `admin` | account, export and deletion tickets. No escrow access |
| `super_admin` | passcode releases. The only role that can release escrow |

A ticket type is never re-routable downward: an `admin` cannot take a
`passcode_release`, and the API enforces that at the dependency level, not with
an `if` inside a controller.

```python
@router.get("/tickets", dependencies=[Depends(MODERATOR)])
```

### What nobody can do

These rows are `❌` for **every** role, `super_admin` included, and they are the
load-bearing ones:

- **Decrypt vault content.** Not a policy — an absence of capability. No endpoint, no tool, no script.
- **Read a private story.** Moderation operates only on reported content.
- **Read an email in plaintext.** Staff tools show `d••••k@g••••.com`.
- **Change a password, or authenticate as a user.** There is no impersonation feature, and this is precisely why passcode escrow is safe.
- **Modify or delete the audit log.** Including the role that can read all of it.

A test asserts there is no `/items`, `/keys` or `/decrypt` route under
`/admin/vault`, so adding one is a visible act.

## The audit log

**Append-only.** No update path, no delete path.

**Hash-chained**, so a deletion or edit anywhere is detectable:

```
entry_hash = SHA256(prev_hash || entry_id || action || target_id || occurred_at)
```

**Visible to the subject.** Entries whose target is a user and whose
`visible_to_target` is true are served to that user at `GET /v1/security-activity`
in plain language. The log is not a staff-only artifact.

## The admin surface

A small Next.js app, staff only, `noindex`. It consumes the whole `/admin/*`
surface: report queue, ticket queue, account lookup and block, audit viewer,
escrow release, and staff TOTP enrolment.

It is not a convenience wrapper over the database. `audit.record` is called from
three places only — `admin/controllers.py`, `admin/vault_router.py` and
`totp/controllers.py`. Doing the same work by hand in MongoDB writes nothing to
the log, which is to say: **doing admin work outside this app is the back
channel.**

Reports have no sweeper. An open report stays open until a human resolves it.

## Not built

IP allowlisting for the admin surface, a 30-minute idle timeout, dual approval
for escrow release, and a job that walks the audit chain to detect a break.
