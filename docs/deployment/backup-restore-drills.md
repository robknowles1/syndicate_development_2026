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
| **Backup taken** | 2026-09-12T04:52:05Z, completed 04:52:11Z (6 s) |
| **App image at backup time** | `ghcr.io/robknowles1/syndicate_development_2026:7070ea6d9090b55614c53e151a060a95cb4b9bf5` |
| **`pg_dump` version** | 16.14 (from inside the accessory, matching the server) |
| **Scratch database** | `restore_drill_20260912`, created in and dropped from `syndicate_development_2026-db-staging` |
| **Artifact checksums** | `db.dump` and `storage.tar.gz` downloaded from R2 matched the SHA-256 recorded in `MANIFEST` |
| **`pg_restore` exit status** | 0 |
| **Row-count comparison** | 15 tables compared against `MANIFEST`, **0 mismatches** |
| **Blob-presence check** | 45 blob rows checked, **0 missing files** |
| **Cleanup** | scratch database dropped, `/var/tmp/syndicate-drill.*` removed, in-container dump removed — all verified afterwards |
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
