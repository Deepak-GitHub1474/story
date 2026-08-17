# 15 — Storage: security, cleanup and scale

> Mostly design. Orphan sweeping (§5.4) is built; everything else here is still
> a plan, and each section says which it is. It covers where uploaded bytes
> live, who can reach them, what happens when something is deleted, and how this
> stops filling a disk we pay for.

---

## 1. Where things stand

Verified against the code, not assumed.

**Vault is already zero-knowledge.** Files are encrypted on the device before
upload. The server stores `wrapped_dek` and ciphertext and never holds a key.
There is not one `decrypt` call on the server side. Nobody on the team can read
a vault file, and that includes anyone with database access, a disk image, or a
backup.

**Story images are public content and are not encrypted.** They are attachments
on public stories; other people must be able to see them.

**Media has a minimal database record.** `upload_image` writes one document to
`media` — `_id` and `created_at`, nothing more. It exists so an upload nobody
attached can still be found and erased (§5.4). There is still no owner, no size
accounting and no quota.

Whether an object is referenced is answered by querying `stories` for the URL,
not by a stored count. The query is derived state and cannot drift; a `refcount`
is a second source of truth that has to be kept correct on every path. §5.2
keeps the counter as a design option for when the query stops being cheap.

**Bytes live on one EC2 disk.** `STORAGE_PROVIDER=local` writes to
`/srv/storage-data`, a Docker volume on the instance. Every image view is served
by a Python request that reads the file and returns it.

---

## 2. What we are actually defending against

Naming the threats first, because they need different answers.

| Threat | Applies to | Answer |
|---|---|---|
| Someone reads a user's private files | vault | already solved: client-side encryption |
| Someone guesses or enumerates object paths | both | unguessable keys, §3 |
| Someone with a username finds that person's files | both | keys derived from nothing public, §3 |
| Deleted content lingers on disk | both | refcounted delete + sweeper, §5 |
| One person fills the disk | both | quota, §6 |
| Disk runs out as the product grows | both | object storage, §7 |

**A note on story images, stated plainly.** They cannot be made unreadable by
the team. A stranger must be able to view them, so the server must be able to
serve the bytes, so any key that decrypts for a stranger is a key we also hold.
Encrypting them would be theatre. What they need is not secrecy but ownership,
unguessable addressing, and reliable deletion.

The split we already have is the correct one: **vault is zero-knowledge, media
is public.** Do not blur it.

---

## 3. Object keys must reveal nothing and be unguessable

The requirement: someone who knows a username — or the whole database of
usernames — must not be able to construct a path to that person's files, or
recognise which files are theirs.

### 3.1 What not to do

```
vault/deepak/holiday.jpg          leaks the owner and the filename
vault/usr_01KZ.../item_01KZ...    leaks the owner, and ids appear in the API
media/med_01KZQNP3YWRXXXHY1FF     current scheme: ULIDs are time-ordered,
                                  so neighbouring uploads are guessable
```

ULIDs are the specific problem worth naming: they encode a timestamp in their
prefix and are lexicographically ordered. Given one media id, the ids created
around it are a small search space.

### 3.2 What to do

**Store a random key in the database; derive it from nothing.**

```
key = 32 random bytes, hex encoded
path = <shard>/<key>
shard = first 2 chars of key, then next 2       e.g. 4f/a2/4fa2c1...
```

Properties this gives:

- Nothing in the path comes from the username, user id, item id, filename or
  upload time. Knowing any of those tells an attacker nothing.
- 256 bits of entropy. Not enumerable.
- The two-level shard keeps directories small — a flat directory with a million
  entries is slow on most filesystems — and, importantly, **files are not
  grouped by user**, so a directory listing does not reveal who owns what or how
  much any one person has stored.

The mapping from `item_id` to `key` lives in Mongo, reachable only through an
authorised request.

### 3.3 Original filenames never touch storage

The vault already treats the filename as user data. Keep it that way: the
filename is part of the encrypted payload, never part of the path, never a
column on its own. A path must not say `passport.pdf`.

---

## 4. Keep the server out of the download path

Today an image view is: device → API → disk → API → device. Every view costs a
Python request and holds a worker.

**Move to presigned URLs.** The API answers with a short-lived signed URL and
the device fetches the bytes directly from storage.

- **Vault:** already has `PRESIGN_DOWNLOAD_TTL_SECONDS = 300`. On object storage
  the ciphertext goes device↔storage directly and the server never touches it.
  That strengthens the zero-knowledge claim rather than weakening it.
- **Media:** public story images are served from a CDN. Because keys are random
  and content never changes under a key, they can be cached forever:
  `Cache-Control: public, max-age=31536000, immutable`.

The signature is what makes an unguessable key safe to hand out: even if a URL
leaks, it expires.

---

## 5. Deletion must actually delete

The rule: **when the last reference goes, the bytes go.** Nothing else is
acceptable, because unreferenced files are pure cost.

### 5.1 A media record, finally

**Built, in its smallest form.** One document per stored object:

```
media/
  _id           the media id from §3
  created_at    when it was uploaded
```

The document is written *before* the bytes. If the write then fails we are left
with a record and no object, which the sweep tidies away; the other order would
leave bytes nothing knows about — exactly the leak being closed.

`drop_unused` deletes the record in the same step as the bytes, so a swept id is
never revisited.

**Still designed, not built:** `owner_id`, `bytes`, `sha256`, `refcount`,
`last_seen_at`. Each is wanted by a different section below — quota needs
`bytes`, dedup needs `sha256`, §5.5 wants `owner_id`. None of them are needed to
stop the leak, so none were added.

### 5.2 Reference counting, not story-based deletion

**Design.** What is built instead is the reference *query*: `drop_unused` asks
`stories` whether any live document still holds the URL, and only erases when
none does. It already survives the shared-picture case a naive story-based
delete would break — there is a test for exactly that. A counter becomes worth
its upkeep only when that query is too expensive to run per candidate.

```
attach image to story      refcount += 1
detach / delete story      refcount -= 1
refcount reaches 0         delete the object, delete the record
```

The decrement and the object delete belong in the same code path as the story
delete, so there is no window where the story is gone and the file is not.

### 5.3 Deduplication, and where it must not be used

For **media**, key by content hash: the same image uploaded by ten people is one
object with a refcount of ten. Re-uploading costs nothing — hash it, find it,
increment.

For **vault**, do not deduplicate. Encrypting the same plaintext twice produces
different ciphertext, so it cannot work — and if it somehow did, matching
objects would leak that two people hold the same file. Every vault object stays
distinct.

### 5.4 Sweeping orphans

**Built.** Some objects never get attached: a person picks a photo, then
abandons the draft. Nothing ever pointed at them, so no delete path reaches
them.

`sweep_orphans` in `app/api/endpoints/media/cleanup.py`, scheduled hourly beside
`publish_scheduled_stories`:

```
every hour:
  ids = media where created_at < now - MEDIA_ORPHAN_GRACE_SECONDS
  drop_unused(their urls)          # erases only what no live story holds
```

It reuses `drop_unused` rather than repeating the reference check, so a picture
can never be erased out from under a story that still shows it.

`MEDIA_ORPHAN_GRACE_SECONDS` defaults to 24 hours. The grace exists so a slow
compose session is not swept mid-write; the composer's own autosave is five
seconds, so the margin is enormous on purpose.

Uploads made before this shipped have no record, so the sweep cannot see them.
That is deliberate — a backfill would have to infer intent about bytes nothing
describes, and the safe reading of an unknown object is to keep it.

### 5.5 Deleting an account

Account deletion is already scheduled 14 days out, and `workers/deletion.py`
already erases the pictures hanging off that user's stories. What it cannot
reach is an upload they never attached to anything — the record from §5.1 holds
no `owner_id`, so there is nothing to enumerate by. The sweep collects those
within the grace period instead, which is slower but leaves nothing behind.

Adding `owner_id` would close the gap immediately, at the cost of a stored link
between a person and a picture they never published. That trade is worth stating
out loud before anyone makes it on autopilot.

---

## 6. Quotas, so one person cannot fill the disk

`VAULT_QUOTA_BYTES` already exists at 2 GB per user, but there is no equivalent
for media, and neither can be enforced without size accounting.

- Sum `bytes` for the owner at upload; refuse past the limit with a clear error.
- Keep the media allowance far smaller than the vault allowance — story images
  are incidental, vault is the storage product.
- Show usage in the UI before the refusal, not after.

---

## 7. Getting off the EC2 disk

The disk is the real constraint: it is finite, it is on one machine, growing it
costs money, and losing the instance loses everything.

**Cloudflare R2 is the recommendation**, for one reason above the others:
**zero egress fees.** Image-serving is almost entirely egress, and egress is
what makes object storage expensive elsewhere. R2 also has a free tier covering
storage and operations; check the current allowances before committing, as
pricing changes.

The code is already ready. `STORAGE_PROVIDER=r2` plus five `STORAGE_S3_*` values
switches the adapter with no code change — the port exists precisely so this is
a config edit.

**Do this after §5, not before.** Moving an unaccounted, uncleaned pile of files
into object storage gives you an unaccounted, uncleaned pile of files you now
pay for per gigabyte.

### What changes for cost

| | Now | After |
|---|---|---|
| Storage | EC2 volume, grows, must be resized | R2, pay per GB stored |
| Serving | Python request per view | CDN, cached, no API involvement |
| Egress | EC2 bandwidth | zero on R2 |
| Losing the box | loses every file | files unaffected |

---

## 8. Order of work

Each step is useful on its own and safe to ship alone.

1. ~~**Media record**~~ — **done**, in the minimal form of §5.1: `_id` and
   `created_at`. `owner_id`, `bytes` and `sha256` are still open, each blocking
   a different step below.
2. ~~**Orphan sweeper**~~ — **done**, §5.4. Hourly, reusing `drop_unused`.
3. **Random opaque keys with sharding** — §3. Do it before there is a large
   corpus to migrate.
4. **Refcounted deletion** — only if the reference query gets expensive; the
   query is correct today and a counter is not free. See §5.2.
5. **Quotas** — media allowance, and enforce the vault one that already exists.
   Needs `bytes` on the record.
6. **Account deletion clears unattached uploads** — needs `owner_id`; weigh
   §5.5 first. Attached pictures are already erased.
7. **Move to R2** — config, once the rest holds.
8. **CDN and immutable caching for media** — after 7.

1 and 2 are what stop the disk filling, and they are in. The rest is worth
finishing **before real users arrive**, because retrofitting ownership onto
files already on disk means guessing who owns what, and that guess cannot be
made safely.

---

## 9. Things deliberately not done

**Encrypting story images.** Explained in §2. It would not protect anything and
would break public serving.

**Deduplicating vault objects.** §5.3. Cannot work, and would leak.

**Storing files in MongoDB.** GridFS puts image bytes in the database, inflating
backups and slowing every query on the same instance. Object storage is what
this is for.

**Keeping deleted files for recovery.** A soft-deleted image is an image we
still pay for and still have to defend. Deletion means deletion; the 14-day
account window is the one deliberate exception, and it is a scheduled delete
rather than a retained copy.
