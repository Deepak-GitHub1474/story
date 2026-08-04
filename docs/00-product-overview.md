# 00 — Product Overview

> STORY is a social platform where nobody knows who you are, and that is the point.

## 1. The problem

There is a category of human experience that people cannot talk about anywhere.

A heartbreak that ended years ago but still aches. A grief that the people around you have moved on from. A dream you gave up so somebody else could have theirs. A relationship that never became anything and now exists only as a folder of photos you cannot keep on your phone because someone might see it.

Existing social platforms are structurally incapable of holding this content. Instagram and LinkedIn are **identity amplifiers** — their entire value proposition is that the audience knows exactly who posted. That is precisely what makes them unusable for the things that matter most. To share the story, you would have to reveal yourself, and revealing yourself means being judged, or damaging a current relationship, or hurting someone who is still in your life.

So people carry it alone.

## 2. The product

STORY gives that content a home by removing identity from the equation entirely.

Two pillars:

**Pillar 1 — Anonymous storytelling.** Users publish long-form written stories to communities of people who are going through something similar. No real names, no phone numbers, no email required to join, no profile photos of real faces. Every user is unknown to every other user, permanently and by design. Because there is nothing personal in the system, there is nothing personal to leak.

**Pillar 2 — The private vault.** Encrypted storage for the memories that cannot live on a personal device. Photos, videos, documents, voice notes. Encrypted on the device before upload, with a key the platform cannot assemble. Optionally hidden entirely from the app's own interface, findable only by typing an exact label the user chose.

The two pillars share one foundation: **the platform is deliberately built so that it cannot betray the user, even if it wanted to, even if it were compromised, even if it were compelled.**

## 3. The USP, stated precisely

Anonymity is a claim every platform makes and almost none can back. Ours is enforceable, and it is enforceable because of three structural decisions:

1. **We never collect the identifiers.** Signup requires a username and a password. Not an email. Not a phone number. Not a device contact list. There is no OAuth provider handing us a real name. The absence of data is the strongest privacy guarantee that exists — you cannot leak what you never had.

2. **The optional identifiers we do collect are unreadable to us.** If a user later adds an email for recovery, it is stored as ciphertext plus a keyed hash. We can verify a match and send an OTP; we cannot read the address, and neither can anyone who steals the database.

3. **Vault decryption requires two secrets that no single party ever holds together.** The account password (user only, never recoverable) and the vault passcode (user, plus an audited escrow for support cases). Staff with the escrowed passcode still cannot decrypt anything, because they have no path to the password. See [05-security-and-crypto.md](05-security-and-crypto.md) for the full construction.

This is the whole company. Every product decision downstream is subordinate to it.

## 4. Design principles

These are the tie-breakers. When two implementations are otherwise equal, the one that better satisfies the higher-numbered principle wins.

**P1 — Collect nothing.** Every field is guilty until proven necessary. The default answer to "should we also capture X?" is no. If a feature requires personal data to work, the feature is wrong, not the principle.

**P2 — Cannot beats will not.** "We promise not to look" is worthless. Architect so that looking is impossible. Prefer a design where a hostile administrator with full database access learns nothing over a design that relies on policy, access control, or good intentions.

**P3 — No pages, only people.** There are no brand accounts, no business pages, no verified badges, no ad accounts. This kills the entire spam, influencer, and impersonation economy in one stroke, and it is why communities can stay safe without heavy moderation.

**P4 — Never encourage exposure.** The platform must never nudge a user toward revealing themselves. Avatars are platform-generated, not uploaded. Story composition warns before attaching identifiable media. There is no "connect your contacts", no "people you may know", no location tagging, no read receipts.

**P5 — One place to change anything.** Colors, spacing, type, copy, icons, images, error messages — each has exactly one definition. Changing a brand color is a one-line diff. This is a hard engineering constraint, enforced in CI, not a style preference. See [03-design-tokens.md](03-design-tokens.md).

**P6 — Honest about limits.** Where a guarantee has an edge, we document the edge and we tell the user in the interface. A user who resets their password loses their vault forever; they will be told this in unmissable language before it happens, not discovered afterwards.

**P7 — Text first.** The core content type is written language. No video posts, no reels, no live streams, no ephemeral 24-hour content. Long-form text is what the product is for, and it is also what makes anonymity durable — faces and voices are identifying, prose is not.

## 5. Who this is for

Four personas, each mapping to a community archetype. These are the shapes the product optimizes for; they are not exhaustive.

**The Griever.** Lost a person, a relationship, or a version of their future. Needs to say it out loud, exactly once, to people who will not flinch. Primary need: publish a long story, be read, receive comments that are not advice. Also the heaviest vault user — photos and messages of someone who is gone.

**The Sacrificer.** Gave something up for family, duty, or someone else's dream, and made peace with the decision without making peace with the cost. Needs recognition, not resolution. Primary need: a community where the pattern is understood without explanation.

**The Professional Under Pressure.** Corporate, senior enough that complaining is career-ending. Burnout, a hostile manager, imposter syndrome, a decision they regret. Cannot post any of it on LinkedIn where their VP follows them. Primary need: peer discussion with zero attribution risk.

**The Lonely.** Not in crisis, just unseen. Wants low-stakes connection with people who are also not performing. Primary need: gentle feeds, small communities, connection without commitment.

Common thread: **every persona is here because the alternative is silence.** The product's job is to lower the cost of speaking to zero.

## 6. Feature scope

### v1 — Mobile app (Flutter)

| # | Feature | Summary |
|---|---|---|
| 1 | **Onboarding** | Signup and signin with username + password. Platform-assigned avatar. Terms acceptance. No email, no phone. |
| 2 | **Communities & connections** | Interest-based communities. Follow other users. AI-assisted community and people suggestions based on declared interests and reading behaviour. |
| 3 | **Stories** | Create, edit, publish. Visibility: `draft` (default), `public`, `private`, `scheduled`. Rich text with emoji, optional images. Likes, comments, shares. |
| 4 | **Vault** | Encrypted personal storage for any file type. Two visibility modes: `normal` (listed) and `hidden` (findable only by exact label search). Passcode-gated. |
| 5 | **Settings** | Optional email with OTP verification. Theme switching. Active sessions and devices. Passcode management. Recovery ticket status. |

### v2 — Web (Next.js)

Feature parity with the mobile app, plus public story pages that are server-rendered and indexable. **Web work begins only after the mobile app is finalized**, and reuses the same design tokens, the same API, and the same component contract. See [11-mvp-roadmap.md](11-mvp-roadmap.md).

### Explicitly out of scope for v1

Direct messaging, video posts, live audio, groups with admins, monetization, story reactions beyond a single like, notifications beyond in-app, web push, and any form of advertising.

## 7. Non-goals

Things we are choosing not to be, permanently:

- **Not a confession wall.** Stories are long-form and attached to a persistent pseudonymous account with a history, not one-off anonymous drops. Persistence is what makes community possible; anonymity is what makes honesty possible. We need both.
- **Not a therapy service.** No professional counselling, no clinical claims, no crisis intervention beyond surfacing regional helpline resources where a story trips a risk signal.
- **Not a dating app.** Connection is about being understood, not being matched. No swiping, no romantic intent signalling, no proximity features.
- **Not a marketing channel.** P3. No pages means no brands.
- **Not a cloud drive.** The vault is for memories that must not exist elsewhere, not for bulk file sync. Quotas will reflect this.
- **Not fully zero-knowledge for public content.** Stories are server-readable — they have to be, for feeds, search, moderation, and AI recommendation. Only vault content is end-to-end encrypted. We will say so plainly rather than overclaiming.

## 8. Glossary

Canonical vocabulary. These exact terms are used in code, in the database, in the API, and in user-facing copy. Synonyms are not permitted — if the concept is a Story, it is never called a post, an entry, or a confession anywhere in the system.

| Term | Meaning |
|---|---|
| **Story** | A published piece of long-form text, optionally with images. The core content unit. Never "post". |
| **Draft** | A Story that exists but has never been published. The default state on creation. |
| **Visibility** | A Story's audience: `draft`, `private`, `public`, or `scheduled`. |
| **Community** | An interest-based collection of users. Users join; there is no owner or admin. |
| **Connection** | A one-directional follow between two users. |
| **Vault** | A user's encrypted private storage area. |
| **Vault item** | One encrypted file in the Vault, with metadata and a visibility mode. |
| **Label** | The user-chosen search string that reveals a hidden Vault item. |
| **Passcode** | The secret that gates Vault decryption. Separate from the account password. Escrowed. |
| **Password** | The account login secret. Argon2id-hashed, never recoverable by anyone. |
| **UMK** | User Master Key. Random 32 bytes, unwrapped by the password at login, never leaves the device in plaintext. |
| **Recovery Kit** | An optional, user-held backup of the UMK. Never stored server-side. |
| **Ticket** | A tracked support request, e.g. a passcode release. Visible to both user and staff. |
| **Reveal** | The audited, time-limited disclosure of escrowed passcodes to a user via a Ticket. |
| **user_id** | Immutable internal identifier. Never displayed. Used in every foreign key. |
| **username** | The public, unique login handle. What a user types to sign in. |
| **display_name** | Free-text, changeable, non-unique name shown alongside stories. |
| **Avatar** | A platform-generated visual identity. Never a user-uploaded photo. |

## 9. Document map

Read in order; each builds on the previous.

| Doc | Contents |
|---|---|
| **00** — this file | Product, principles, personas, scope, glossary |
| [01-tech-stack.md](01-tech-stack.md) | Stack decisions with rationale, dependencies, infrastructure |
| [02-repo-structure-and-conventions.md](02-repo-structure-and-conventions.md) | Monorepo layout, colocation rule, naming, CI gates |
| [03-design-tokens.md](03-design-tokens.md) | The complete token contract and its generators |
| [04-component-library.md](04-component-library.md) | Shared component APIs, icons, images, accessibility |
| [05-security-and-crypto.md](05-security-and-crypto.md) | Key hierarchy, vault encryption, threat model |
| [06-recovery-and-admin-flows.md](06-recovery-and-admin-flows.md) | Recovery, ticket lifecycle, roles, audit log |
| [07-data-model.md](07-data-model.md) | Every collection, field, and index |
| [08-api-contract.md](08-api-contract.md) | Envelope, error codes, all endpoints |
| [09-backend-conventions.md](09-backend-conventions.md) | FastAPI structure and patterns |
| [10-client-conventions.md](10-client-conventions.md) | Flutter and Next.js structure and patterns |
| [11-mvp-roadmap.md](11-mvp-roadmap.md) | Phased build order and definition of done |
