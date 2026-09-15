# Backup Restore Drills

Append-only log of restore rehearsals. SPEC-017 R19-R20.

**An untested backup is not a backup.** Each entry below records a rehearsal that was
actually performed, not a procedure that was described. The first passing entry is a hard
gate on SPEC-017 Phase 6 — the first moment production holds data that exists nowhere else.

**Cadence:** the first drill gates Phase 6; quarterly thereafter, and once more immediately
after any change to `deploy/backup/` or to the Postgres accessory.

**How to run one:**

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@15.204.81.231
sudo syndicate-backup-drill              # newest daily prefix
sudo syndicate-backup-drill 2026-09-11   # a specific night
```

The script restores into `restore_drill_YYYYMMDD` and drops it again on exit. It prints a
`--- drill report ---` block; paste its figures into a new row below, newest last.

> The drill must never restore into `syndicate_development_2026_production`. The dated
> scratch name is checked against a regex before `createdb` runs, and against the live
> database name, precisely so a copy-pasted `-d` argument cannot silently target the real
> one. Do not relax either check.

---

## 2026-09-12 — first drill (staging), PASS

| | |
|---|---|
| **Operator** | devops-agent, on behalf of robknowles1 |
| **Tier drilled** | staging — production does not exist yet (`KAMAL_PRODUCTION_HOST` unset, no production Postgres accessory has ever booted) |
| **Artifact prefix** | `r2:syndicate-backups/staging/daily/2026-09-12` |
| **Backup taken** | 2026-09-12T15:34:26Z, 9 s wall, 29 MB peak RSS |
| **Drill run twice** | Once against an earlier working copy (04:52 artifacts, PASS), then again against the committed scripts. Only the second is recorded as the gate — the artifacts it used are the ones in R2 now, and a drill that rehearses code which is not committed proves nothing durable. Both agreed on every figure below. |
| **App image at backup time** | `ghcr.io/robknowles1/syndicate_development_2026:7070ea6d9090b55614c53e151a060a95cb4b9bf5` |
| **`pg_dump` version** | 16.14 (from inside the accessory, matching the server) |
| **Scratch database** | `restore_drill_20260912`, created in and dropped from `syndicate_development_2026-db-staging` |
| **Artifact checksums** | `db.dump` and `storage.tar.gz` downloaded from R2 matched the SHA-256 recorded in `MANIFEST` |
| **`pg_restore` exit status** | 0 |
| **Row-count comparison** | 15 tables compared against `MANIFEST`, **0 mismatches** |
| **Blob-presence check** | 45 blob rows checked, **0 missing files** |
| **Cleanup** | scratch database dropped, `/var/tmp/syndicate-drill.*` removed, in-container dump removed — all verified afterwards |
| **Box left clean** | no failed systemd units; all three staging containers (`-web-staging`, `-db-staging`, `kamal-proxy`) still `Up` and untouched throughout |
| **Result** | **PASS** |

Row counts, identical in `MANIFEST` and in the restored scratch database:

| Table | Rows |
|---|---|
| `about_page_contents` | 1 |
| `active_storage_attachments` | 45 |
| `active_storage_blobs` | 45 |
| `active_storage_variant_records` | 34 |
| `admin_users` | 3 |
| `ar_internal_metadata` | 2 |
| `business_hours` | 1 |
| `faqs` | 6 |
| `gallery_photos` | 9 |
| `home_page_contents` | 1 |
| `schema_migrations` | 16 |
| `service_bullets` | 15 |
| `service_sections` | 3 |
| `site_settings` | 1 |
| `social_media_links` | 2 |

### Things that had to be fixed or clarified

- **The R2 credentials were in the wrong place.** They had been staged at
  `/etc/syndicate-backup.env` (root, 0600) in plain `KEY=value` form before the spec
  merged. R15 requires `/etc/syndicate-backup/rclone.conf` in rclone config format. The
  values were transposed into an rclone `[r2]` section on the box and the provisional file
  was shredded. No credential left the box.
- **`no_check_bucket = true` is mandatory in `rclone.conf`**, not a tuning option. The R2
  token is scoped to Object Read & Write on `syndicate-backups` alone and cannot
  `ListBuckets`; rclone's default pre-flight bucket check would fail every upload with
  `AccessDenied`. Recorded in `/etc/syndicate-backup/README`.
- **SPEC-017 R52's "46 files against 45 blobs" is explained.** The 46th file is
  `storage/.keep`, tracked in the repository. Every one of the 45 blob rows has its file;
  there are no orphans and nothing is missing. A future drill seeing 46 archived files
  against 45 blobs is seeing the same `.keep`, not a defect.
- **Row counts in `MANIFEST` are taken immediately after `pg_dump`, not inside its
  snapshot.** A write landing in that window would show as a drill mismatch. See
  "Consistency guarantee" in `ovh-server-access.md#backups` — this is a known and accepted
  limitation, and it fails towards a loud drill failure rather than a quiet bad restore.

### Not proven by this drill

- **The alert channel has not sent a real message.** `/etc/syndicate-backup/alert.env`
  holds the placeholder `RESEND_API_KEY=REPLACE_ME`. The `OnFailure=` chain was exercised
  end to end and does fire with the correct failing unit name, but the final HTTP call to
  Resend is unproven until the owner populates the key. SPEC-017 AC-12 is therefore
  **partially** satisfied; finish it per `ovh-server-access.md#backups`.
- **Production.** Every figure above is staging's. Repointing
  `/etc/syndicate-backup/backup.env` at production in Phase 5 is a configuration change,
  not a rewrite — but it is a change, and Phase 6's gate is a drill against *production's*
  artifacts, not this one.

---

## 2026-09-15 — production rollback backup (R44) + Phase 6 restore, PASS

Not a rehearsal. This entry records the first real exercise of the backup tooling against
production (R44) and the live Phase 6 restore of staging's content into it (R45-R52).

| | |
|---|---|
| **Operator** | devops-agent, on behalf of robknowles1 |
| **Scope** | SPEC-017 Phase 6, R44 through R52 |
| **Artifact prefix** | `r2:syndicate-backups/production/daily/2026-09-15` — the first `production/` prefix in the bucket |
| **Backup taken** | 2026-09-15T04:28:12Z, 1 s wall |
| **App image** | `ghcr.io/robknowles1/syndicate_development_2026:67126023c8a1f35ea22083075ba852a321e46a59` |
| **`pg_dump` version** | 16.14 |
| **R44 artifacts** | `db.dump` 43446 B, `storage.tar.gz` 123 B, `MANIFEST` 1208 B — all three verified present in R2 and re-downloaded to `/var/tmp/spec017-phase6/rollback-r44/` with matching SHA-256 |
| **`pg_restore` exit status** | 0, `--single-transaction`, no warnings |
| **Blob-presence check** | every blob row checked against the disk service path, **0 missing files** — verified twice, once via `ActiveStorage::Blob.service.exist?` and once directly against the volume, and again at 49 blobs once the count had drifted |
| **Key-set check** | all 45 of staging's blob keys present in production, set difference in that direction **empty** |
| **`ar_internal_metadata`** | `environment=production` before and after, asserted through both the Rails API and the raw row |
| **Staging** | read-only throughout; row counts, `ar_internal_metadata` and volume file count all identical afterwards |
| **Result** | **PASS** |

Row counts, production after the restore against staging as the source:

| Table | Staging | Production | |
|---|---|---|---|
| `about_page_contents` | 1 | 1 | match |
| `active_storage_attachments` | 45 | 47 → 49 | grows, see below |
| `active_storage_blobs` | 45 | 47 → 49 | grows, see below |
| `active_storage_variant_records` | 34 | 36 → 38 | grows, see below |
| `admin_users` | 3 | 3 | match |
| `business_hours` | 1 | 1 | match |
| `faqs` | 6 | 6 | match |
| `gallery_photos` | 9 | 9 | match |
| `home_page_contents` | 1 | 1 | match |
| `service_bullets` | 15 | 15 | match |
| `service_sections` | 3 | 3 | match |
| `site_settings` | 1 | 1 | match |
| `social_media_links` | 2 | 2 | match |
| `ar_internal_metadata` | 2 | 2 | excluded from the dump (R45) |
| `schema_migrations` | 16 | 16 | excluded from the dump (R45) |

### Things that had to be fixed or clarified

- **R52's verification snippet does not run on Rails 8.1.** As printed in the spec it calls
  `ActiveRecord::InternalMetadata.new(ActiveRecord::Base.connection)`, and
  activerecord-8.1.3.1 raises `NoMethodError: undefined method 'db_config'` because
  `InternalMetadata` takes a connection **pool**. The working form is
  `ActiveRecord::InternalMetadata.new(ActiveRecord::Base.connection_pool)`. The assertion
  was also widened to read the raw `ar_internal_metadata` row directly, so the backstop no
  longer depends on an ActiveRecord API that has already moved once.
- **Production does not settle on R52's expected 45 blobs, and this is correct.** It was 47
  immediately after the restore and 49 a few minutes later. Every extra row is an
  `ActiveStorage::VariantRecord` blob that production's own app generated lazily as pages
  were rendered for the first time, each one timestamped after the restore. Every one of
  staging's 45 keys is present in production and the set difference in that direction is
  empty, so production is a strict superset, not a partial restore. **The blob count is a
  moving number on a live site; verify a restore by key set and per-key file existence, and
  treat R52's "45" as the count of keys that must be present rather than the total.**
- **`site_settings` is a key/value table, not a column-per-setting table.** R55 reads as
  though `services_page_published` were a column; it is a row with `key` and `value`
  columns holding the string `"true"`. Staging held `"true"` and production held `"false"`,
  so the restore flipped `/services` from 302 to 200 and added it to `sitemap.xml`.
- **R53 is out of date.** It states both `published` flags arrive `false`. Both were
  already `true` on staging at restore time, so Home and About render Doug's copy
  immediately and R54's decision point was resolved before the restore rather than after.

### Not proven by this entry

- **No restore drill has been run against production's own artifacts.** R44's dump was
  verified to exist in R2 with correct checksums and a correct `MANIFEST`, but it has not
  been restored into a scratch database per R19. It was taken from a freshly-seeded
  database and so contains none of Doug's content; the artifact that would matter in a real
  recovery is the *next* one.
- **Production has no scheduled backup.** `/etc/syndicate-backup/backup.env` still targets
  staging, so the nightly timer continues to back up staging only. Production now holds
  content that exists in exactly two places — production and staging — and neither copy is
  on a schedule that protects production. This is the single largest open risk at the end
  of Phase 6.
