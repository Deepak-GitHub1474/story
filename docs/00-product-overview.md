# 00 — Product Overview

> STORY is a social platform where nobody knows who you are, and that is the point.

## 1. The problem

There is a category of human experience that people cannot talk about anywhere.

A heartbreak that ended years ago but still aches. A grief the people around you have moved on from. A dream you gave up so somebody else could have theirs. A relationship that never became anything and now exists only as a folder of photos you cannot keep on your phone because someone might see it.

That is the sharpest version of the problem, but it is not the only one. The same wall stands in front of far more ordinary things:

- You were laid off six weeks ago and everyone in your feed thinks you are still employed. You need to ask a hundred practical questions and you cannot ask a single one under your own name.
- You are ready to meet someone again after a long time alone, and saying so publicly, to the people who watched the last one end, is unthinkable.
- You are in debt. You are caring for a parent. You are failing a course. You are the only person in your family who left. You hate a job everyone congratulated you for getting.

The common structure is not sadness. It is this: **the thing you need to say is attached to a name that would be damaged by saying it.**

Existing social platforms are structurally incapable of holding any of this content. Instagram and LinkedIn are **identity amplifiers** — their entire value proposition is that the audience knows exactly who posted. That is precisely what makes them unusable for the things that matter most. To share the story, you would have to reveal yourself, and revealing yourself means being judged, or damaging a current relationship, or losing a job offer, or hurting someone who is still in your life.

So people carry it alone.

## 2. The product

STORY gives that content a home by removing identity from the equation entirely.

Three pillars:

**Pillar 1 — Anonymous storytelling.** Users publish long-form written stories to communities of people who are going through the same thing. No real names, no phone numbers, no email required to join, no profile photos of real faces. Every user is unknown to every other user, permanently and by design. Because there is nothing personal in the system, there is nothing personal to leak.

**Pillar 2 — The private vault.** Encrypted storage for the memories that cannot live on a personal device. Photos, videos, documents, voice notes. Encrypted on the device before upload, with a key the platform cannot assemble. Optionally hidden entirely from the app's own interface, findable only by typing an exact label the user chose.

**Pillar 3 — The sanity layer.** Anonymity without moderation produces a sewer; that is the lesson of every anonymous platform that came before. STORY's answer is that **every piece of content is machine-reviewed before it is published, not after it is reported.** The same layer suggests where a user belongs, warns them when their own words would expose them, and offers help when a story carries risk. It is described in full in [12-ai-layer.md](12-ai-layer.md).

The three pillars share one foundation: **the platform is deliberately built so that it cannot betray the user, even if it wanted to, even if it were compromised, even if it were compelled.**

## 3. The USP, stated precisely

Anonymity is a claim every platform makes and almost none can back. Ours is enforceable, and it is enforceable because of four structural decisions:

1. **We never collect the identifiers.** Signup requires a username and a password. Not an email. Not a phone number. Not a device contact list. There is no OAuth provider handing us a real name. The absence of data is the strongest privacy guarantee that exists — you cannot leak what you never had.

2. **The optional identifiers we do collect are unreadable to us.** If a user later adds an email for recovery, it is stored as ciphertext plus a keyed hash. We can verify a match and send an OTP; we cannot read the address, and neither can anyone who steals the database.

3. **Vault decryption requires two secrets that no single party ever holds together.** The account password (user only, never recoverable) and the vault passcode (user, plus an audited escrow for support cases). Staff with the escrowed passcode still cannot decrypt anything, because they have no path to the password. See [05-security-and-crypto.md](05-security-and-crypto.md).

4. **Content is reviewed before it lands, and the review is explainable.** Instagram's model is publish-then-report-then-maybe-remove, which means the harm has already been delivered by the time anything happens. STORY's model is check-then-publish. Every hold, redirect, or block cites the specific rule it applied, and every one of them can be appealed to a human. See [12-ai-layer.md](12-ai-layer.md).

This is the whole company. Every product decision downstream is subordinate to it.

## 4. Design principles

These are the tie-breakers. When two implementations are otherwise equal, the one that better satisfies the higher-numbered principle wins.

**P1 — Collect nothing.** Every field is guilty until proven necessary. The default answer to "should we also capture X?" is no. If a feature requires personal data to work, the feature is wrong, not the principle.

**P2 — Cannot beats will not.** "We promise not to look" is worthless. Architect so that looking is impossible. Prefer a design where a hostile administrator with full database access learns nothing over a design that relies on policy, access control, or good intentions.

**P3 — No pages, only people.** There are no brand accounts, no business pages, no verified badges, no ad accounts. This kills the entire spam, influencer, and impersonation economy in one stroke, and it is why communities can stay safe without heavy moderation.

**P4 — Never encourage exposure.** The platform must never nudge a user toward revealing themselves. Avatars are platform-generated, not uploaded. There is no "connect your contacts", no "people you may know", no location tagging, no read receipts. Where the user is about to expose *themselves* — a real name, an employer, a city, a phone number in the body of a story — the composer says so before they publish.

**P5 — One place to change anything.** Colors, spacing, type, copy, icons, images, error messages — each has exactly one definition. Changing a brand color is a one-line diff. This is a hard engineering constraint, enforced in CI, not a style preference. See [03-design-tokens.md](03-design-tokens.md).

**P6 — Honest about limits.** Where a guarantee has an edge, we document the edge and we tell the user in the interface. A user who resets their password loses their vault forever; they will be told this in unmissable language before it happens, not discovered afterwards. The same applies to AI: a hold says it was a machine, and offers a human.

**P7 — Text first.** The core content type is written language. No video posts, no reels, no live streams, no ephemeral 24-hour content. Long-form text is what the product is for, and it is also what makes anonymity durable — faces and voices are identifying, prose is not.

**P8 — AI protects the reader, never the metrics.** Every model in the system exists to keep a room safe, to help someone find the right room, or to warn an author about their own exposure. No model exists to maximize time-in-app, to rank by outrage, or to decide who deserves an audience. A proposed AI feature whose success metric is engagement is rejected on sight.

**P9 — Nothing is welded to a vendor.** Object storage, the AI provider, the email sender, and the KMS are reached through a narrow port with one adapter per vendor, selected by configuration. Swapping R2 for Backblaze, or a hosted model for a local one, is an environment variable and one adapter file — never a change to a controller. This is the difference between a cheap MVP that can grow up and a cheap MVP that has to be rewritten.

## 5. Who this is for

STORY is not a grief app. Grief is the sharpest case, which makes it the right first case, but the product is for anyone whose situation is attached to a name they need to protect.

Eight personas, each mapping to one or more community categories. These are the shapes the product optimizes for; they are not exhaustive, and the taxonomy in §6 is deliberately open-ended so the ninth shape does not need a code change.

**The Griever.** Lost a person, a relationship, or a version of their future. Needs to say it out loud, exactly once, to people who will not flinch. Primary need: publish a long story, be read, receive comments that are not advice. Also the heaviest vault user — photos and messages of someone who is gone.

**The Sacrificer.** Gave something up for family, duty, or someone else's dream, and made peace with the decision without making peace with the cost. Needs recognition, not resolution. Primary need: a community where the pattern is understood without explanation.

**The Professional Under Pressure.** Corporate, senior enough that complaining is career-ending. Burnout, a hostile manager, imposter syndrome, a decision they regret. Cannot post any of it on LinkedIn where their VP follows them. Primary need: peer discussion with zero attribution risk.

**The Job Seeker.** Laid off, rejected, or quietly looking while still employed. Needs concrete, practical answers — how to explain a nine-month gap, whether a salary number is insulting, what happened in that interview — and every one of those questions is unaskable under a real name. Primary need: a room that is useful rather than consoling, where the answers come from people in the same position and nothing said there can reach a recruiter.

**The One Starting Over.** Divorced, widowed, or a long time alone, and finally ready to want something again. Needs to talk about that readiness with people who are also in it, without the performance, the profile, or the appraisal that a dating product forces on them. Primary need: honest conversation about beginning again. **Explicitly not matching** — see the non-goal in §7.

**The Carer.** Looking after a parent, a partner, or a child with a long illness. Exhausted, guilty about being exhausted, and unable to say so to the family who would be hurt by hearing it. Primary need: to be the one who is asked how they are.

**The Student.** Exam pressure, a course going wrong, first time away from home, an expectation they did not choose. Primary need: proof that the collapse they are having is common, from people close enough in age to be believed.

**The Lonely.** Not in crisis, just unseen. Wants low-stakes connection with people who are also not performing. Primary need: gentle feeds, small communities, connection without commitment.

Common thread: **every persona is here because the alternative is silence.** The product's job is to lower the cost of speaking to zero.

## 6. Feature scope

### 6.1 The community taxonomy

Two levels, one of them data.

**Category** — the shelf. A broad area of life, seeded by the platform. Held in the `community_categories` collection, **not** as an enum in code, so adding one is a seed row rather than a deploy. Each category carries a `tone` that tells the AI layer and the UI what kind of room this is.

| Category | Tone | About |
|---|---|---|
| `grief` | reflective | Bereavement, loss, anniversaries |
| `heartbreak` | reflective | Breakups, divorce, unrequited, endings |
| `sacrifice` | reflective | Duty, family obligation, the road not taken |
| `loneliness` | reflective | Being unseen, quiet company |
| `mental-health` | supportive | Anxiety, burnout, low periods. Peer support, never clinical |
| `health` | supportive | Chronic illness, diagnosis, recovery |
| `caregiving` | supportive | Looking after someone, and the cost of it |
| `family` | supportive | Parents, estrangement, parenting, in-laws |
| `identity` | supportive | Belonging, faith, culture, migration, coming out |
| `work` | practical | Burnout, managers, workplace decisions |
| `job-search` | practical | Layoffs, applications, interviews, offers, gaps |
| `money` | practical | Debt, financial shame, first salary, supporting a family |
| `study` | practical | Exams, courses, campus, first year away |
| `starting-over` | open | Ready for something new after a long time. Conversation, not matching |
| `everyday` | open | Small wins, gratitude, ordinary days worth saying out loud |

**Community** — the room. A specific group inside a category, e.g. `quiet-grief` and `first-year-without-them` both under `grief`; `nine-month-gap` and `offer-or-not` under `job-search`. v1 communities are platform-curated; user-created communities are a later phase.

`tone` is load-bearing rather than decorative. It selects the community's copy, its empty state, its default sort, and — most importantly — **the fit-check rubric the AI layer applies to a story published there.** A blunt, practical answer belongs in `job-search` and is jarring in `grief`; a long unresolved reflection is right in `grief` and useless in `job-search`. One rubric for both rooms would be wrong in both.

### 6.2 v1 — Mobile app (Flutter)

| # | Feature | Summary |
|---|---|---|
| 1 | **Onboarding** | Signup and signin with username + password. Platform-assigned avatar. Terms acceptance. No email, no phone. |
| 2 | **Categories, communities, connections** | Browse by category, join communities, follow other users. AI-assisted community and people suggestions based on declared interests and reading behaviour. |
| 3 | **Stories** | Create, edit, publish. Visibility: `draft` (default), `public`, `private`, `scheduled`. Rich text with emoji, optional images. Likes, comments, shares. |
| 4 | **The sanity layer** | Pre-publication safety gate, community fit check, self-exposure warning, care signal. Every verdict explained and appealable. See [12-ai-layer.md](12-ai-layer.md). |
| 5 | **Vault** | Encrypted personal storage for any file type. Two visibility modes: `normal` (listed) and `hidden` (findable only by exact label search). Passcode-gated. |
| 6 | **Settings** | Optional email with OTP verification. Theme switching. Active sessions and devices. Passcode management. Recovery ticket status. |

### 6.3 v2 — Web (Next.js)

Feature parity with the mobile app, plus public story pages that are server-rendered and indexable. **Web work begins only after the mobile app is finalized**, and reuses the same design tokens, the same API, and the same component contract. See [11-mvp-roadmap.md](11-mvp-roadmap.md).

### 6.4 Explicitly out of scope for v1

Direct messaging, video posts, live audio, groups with admins, monetization, story reactions beyond a single like, notifications beyond in-app, web push, and any form of advertising.

## 7. Non-goals

Things we are choosing not to be, permanently:

- **Not a confession wall.** Stories are long-form and attached to a persistent pseudonymous account with a history, not one-off anonymous drops. Persistence is what makes community possible; anonymity is what makes honesty possible. We need both.
- **Not a therapy service.** No professional counselling, no clinical claims, no crisis intervention beyond surfacing regional helpline resources where a story trips a care signal.
- **Not a dating app.** This is the one non-goal that the `starting-over` category comes close to, so the line is drawn precisely: **the category is a room to talk in, not a pool to search.** No swiping, no browsing people by attractiveness or availability, no romantic-intent flag on a profile, no matching algorithm, no proximity, no photos of real faces, and no ranked people-directory anywhere in the product. What exists is the same thing every other category has: stories, comments, and following. If a feature would only make sense to someone shopping for a partner, it does not ship.
- **Not a job board.** `job-search` is a room to ask and answer, not a place to post vacancies or collect applications. No listings, no company pages (P3 forbids them anyway), no CV uploads — a CV is the single most identifying document a person owns.
- **Not a marketing channel.** P3. No pages means no brands.
- **Not a cloud drive.** The vault is for memories that must not exist elsewhere, not for bulk file sync. Quotas will reflect this.
- **Not fully zero-knowledge for public content.** Stories are server-readable — they have to be, for feeds, search, moderation, and AI recommendation. Only vault content is end-to-end encrypted. We will say so plainly rather than overclaiming.
- **Not an AI content farm.** No model writes a story, rewrites a story into something more engaging, or generates a persona. The AI layer reads; it does not author. See P8.

## 8. Glossary

Canonical vocabulary. These exact terms are used in code, in the database, in the API, and in user-facing copy. Synonyms are not permitted — if the concept is a Story, it is never called a post, an entry, or a confession anywhere in the system.

| Term | Meaning |
|---|---|
| **Story** | A published piece of long-form text, optionally with images. The core content unit. Never "post". |
| **Draft** | A Story that exists but has never been published. The default state on creation. |
| **Visibility** | A Story's audience: `draft`, `private`, `public`, or `scheduled`. |
| **Category** | A broad area of life that communities are filed under, e.g. `grief`, `job-search`. Seeded data, not a code enum. |
| **Tone** | A category's character — `reflective`, `supportive`, `practical`, or `open`. Selects copy, default sort, and the fit-check rubric. |
| **Community** | An interest-based collection of users inside one Category. Users join; there is no owner or admin. |
| **Connection** | A one-directional follow between two users. |
| **Sanity layer** | The complete set of AI checks and suggestions. Never called "moderation AI" in user-facing copy. |
| **Safety gate** | The pre-publication policy check. Can block. |
| **Fit check** | The pre-publication check that content matches the community's tone and subject. Redirects rather than blocks. |
| **Exposure check** | The pre-publication scan for content that would deanonymize its own author. Warns; never blocks. |
| **Care signal** | A risk indicator on a story that surfaces helpline resources to the author. Never removes content, never notifies anyone else. |
| **Verdict** | The sanity layer's decision on one piece of content: `allow`, `warn`, `redirect`, `hold`, or `block`. |
| **Vault** | A user's encrypted private storage area. |
| **Vault item** | One encrypted file in the Vault, with metadata and a visibility mode. |
| **Label** | The user-chosen search string that reveals a hidden Vault item. |
| **Passcode** | The secret that gates Vault decryption. Separate from the account password. Escrowed. |
| **Password** | The account login secret. Argon2id-hashed, never recoverable by anyone. |
| **UMK** | User Master Key. Random 32 bytes, unwrapped by the password at login, never leaves the device in plaintext. |
| **Recovery Kit** | An optional, user-held backup of the UMK. Never stored server-side. |
| **Ticket** | A tracked support request, e.g. a passcode release or a moderation appeal. Visible to both user and staff. |
| **Reveal** | The audited, time-limited disclosure of escrowed passcodes to a user via a Ticket. |
| **Port** | A narrow interface to an external vendor — storage, AI, mail, KMS — with one adapter per vendor, chosen by config. P9. |
| **user_id** | Immutable internal identifier. Never displayed. Used in every foreign key. |
| **username** | The public, unique login handle. What a user types to sign in. |
| **display_name** | Free-text, changeable, non-unique name shown alongside stories. |
| **Avatar** | A platform-generated visual identity. Never a user-uploaded photo. |

## 9. Document map

Read in order; each builds on the previous.

| Doc | Contents |
|---|---|
| **00** — this file | Product, principles, personas, taxonomy, scope, glossary |
| [01-tech-stack.md](01-tech-stack.md) | Stack decisions with rationale, provider ports, infrastructure |
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
| [12-ai-layer.md](12-ai-layer.md) | The sanity layer: checks, verdicts, providers, appeals |
