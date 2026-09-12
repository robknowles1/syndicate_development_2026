# Spec: Production Deployment, Domain Migration and Backups

**ID:** SPEC-017
**Status:** ready
**Priority:** high
**Created:** 2026-09-11
**Author:** devops-agent

---

## Goal

Take the Rails rebuild live. Provision production via Kamal on the existing OVH box alongside
staging, move the site onto `syndicatedevelopment.com` as its primary domain, redirect the
retiring `syndicate-development.com` to it without losing the search ranking the current static
React site has accumulated, carry Doug's real staging content across so he does not re-enter it,
and put a verified nightly backup in place **before** production holds anything worth losing.

This is a runbook as much as a spec. It is executed by hand, phase by phase, against a live
server, and each phase is a separate sitting with its own verification gate and its own rollback.
The phases have hard ordering constraints — TLS cannot issue before DNS resolves, Search Console
cannot be told about the move before both domains serve, backups cannot be proven after the data
they were supposed to protect is already at risk — and those dependencies are stated explicitly in
[Phase Ordering](#phase-ordering-and-hard-dependencies) rather than left implied by section order.

The server access facts, the Kamal secrets model, the accessory topology, the Solid Queue
arrangement and every existing recovery procedure live in
[`docs/deployment/ovh-server-access.md`](../deployment/ovh-server-access.md) and are **not**
restated here. This spec references that runbook and, in R66, specifies the edits it needs once
production exists — it currently states "Production is not provisioned via Kamal yet", which
this spec makes false.

---

## Non Goals

- **Moving Active Storage to object storage.** Both tiers keep `config.active_storage.service =
  :local` (`config/environments/production.rb:25`, `staging.rb`). Files stay on the box's Docker
  volume and are protected by the Phase 2 backup, not by a storage migration. Serving images from
  R2/S3 is a separate change with its own cache, URL-signing and cost questions, and nothing in
  this work needs it.
- **A second server.** Staging and production co-host on `15.204.81.231` (owner decision). The
  memory and image-retention consequences of that are in scope (R4-R9); splitting the tiers onto
  two boxes is not.
- **A production deploy job in CI.** Production deploys stay manual (owner decision). CI keeps
  auto-deploying staging on push to `main` and gains nothing here. See R3.
- **Zero-downtime or blue/green cutover.** The new domain has no existing traffic and the old
  domain is redirected at DNS/edge level; there is no window during which one request must be
  served by two systems. A load balancer in front of both boxes would add a failure mode to buy
  nothing.
- **Retiring `syndicate-development.com`'s registration.** It is paid for another year and stays
  registered, redirecting. Dropping it is a decision for 2027, noted in R63.
- **Application code changes beyond the host/domain constants.** R23, R26, R31 and R33 name the
  exact lines in `config/deploy.yml`, `config/environments/production.rb`,
  `config/deploy.staging.yml` and `config/mail_settings.rb` that must change because they hardcode
  a retiring domain. No feature work, no new endpoints, no schema change.
- **Monitoring or uptime alerting for the site itself.** Phase 2 makes *backup* failure loud. Site
  uptime alerting is a separate, worthwhile follow-up and is named in Open Questions, not solved
  here.
- **`db:rollback` in production.** Forbidden by `.claude/standards/practices/deployment-strategy.md`
  §1.4. Nothing in this spec rolls a migration back.

---

## Definitions

| Term | Definition |
|------|-----------|
| the box | OVH VPS `15.204.81.231`, hostname `vps-834393af`, Ubuntu 26.04, 2 vCPU / 3.7 GB RAM / 38 GB disk, user `ubuntu`, key `~/.ssh/id_ed25519`. Runs staging today and production after Phase 5. Nothing else is on it. |
| new domain | `syndicatedevelopment.com`. Cloudflare nameservers (`art.ns.cloudflare.com`, `veronica.ns.cloudflare.com`). No A record as of 2026-09-11. Becomes the primary domain. |
| old domain | `syndicate-development.com`. Google Cloud DNS nameservers (`ns-cloud-a*.googledomains.com`); apex resolves to `147.182.199.74`. Retiring, but registered and redirecting through 2027. |
| the old box | `147.182.199.74`, a DigitalOcean host serving a **static React SPA** via nginx/1.18.0 (last modified 2026-04-26). This is the site the Rails rebuild replaces. It is not the Rails app and has never run it. |
| canonical host | `syndicatedevelopment.com` — the apex, with no `www`. The single hostname that reaches Rails. See R27 for why apex rather than `www`. |
| grey cloud | A Cloudflare DNS record with proxying **off** (DNS-only). Traffic goes straight to the origin IP; Cloudflare sees nothing. |
| orange cloud | A Cloudflare DNS record with proxying **on**. Cloudflare terminates TLS and can apply Redirect Rules. Required for a Redirect Rule to fire; incompatible with this app's `trusted_proxies` (R25). |
| redirect-only record | An orange-clouded A record pointing at `192.0.2.1` (RFC 5737 TEST-NET-1, guaranteed unroutable) whose traffic a Cloudflare Redirect Rule answers with a 301. Cloudflare never contacts an origin, so the unroutable address is never dialled. |
| the restore | Phase 6: moving staging's application data **and** its Active Storage files into production as one unit. |
| the drill | Phase 2's performed-and-recorded restore rehearsal (R19-R20). Distinct from the restore: the drill proves the backup artifacts are usable; the restore is a one-off content migration. |
| overlap window | The ≥7 days after cutover during which the old box stays running and reachable at its IP as an instant rollback target. |

---

## Phase Ordering and Hard Dependencies

Phases run in numeric order. The arrows below are the constraints that are **not** merely
sequential preference — each is a case where running the later phase first fails, or succeeds
while leaving something silently broken.

```
Phase 1  Host housekeeping (swap, retention, ufw)
   │
   │  swap must exist before a second app tier competes for 3.7 GB;
   │  a reboot to prove fstab is only cheap while just staging is at risk
   ▼
Phase 2  Backups + restore drill
   │
   │  MUST complete before Phase 6. Phase 6 is the first moment production
   │  holds data that exists nowhere else in production. A backup proven
   │  after that point protects nothing that was at risk before it.
   ▼
Phase 3  DNS + TLS (new domain only; old zone NS move, no behaviour change)
   │
   │  kamal-proxy requests a Let's Encrypt certificate via HTTP-01 during
   │  `kamal setup`. The name must already resolve to the box and :80 must
   │  be reachable, or issuance fails. DNS therefore precedes Phase 5.
   ▼
Phase 4  Mail (verify new Resend sending domain)
   │
   │  Resend verification is DNS-record-based, so it needs Phase 3's zone.
   │  It must complete before DEFAULT_FROM_ADDRESS changes, because
   │  production sets raise_delivery_errors = true: an unverified sending
   │  domain turns a customer's contact-form submission into a 500.
   ▼
Phase 5  Production deploy (`kamal setup`)
   │
   │  Phases 5 and 6 are ONE maintenance window. See R43.
   ▼
Phase 6  Restore staging content into production
   │
   │  Smoke tests in Phase 7 assert Doug's content, not seeded defaults.
   ▼
Phase 7  Cutover, Search Console, decommission
```

Additional hard dependencies that are not adjacent in the sequence:

| Dependency | Why |
|---|---|
| R21 (lower TTLs) → everything in Phase 3 and Phase 7 | A TTL reduction only takes effect after the *previous* TTL has expired everywhere. Lowering TTLs on cutover day buys nothing; the rollback you need at 14:05 is governed by the TTL that was live at 14:00 minus one old TTL period. |
| R30 (old-zone nameserver migration, like-for-like) → R58 (old domain starts redirecting) | A registrar nameserver change propagates for up to 48 h. Doing it as a pure no-op in Phase 3 keeps that propagation off the cutover critical path, so Phase 7's redirect flip is a single record edit with a 60-second TTL. |
| R37 (`KAMAL_PRODUCTION_HOST` exported) → any production Kamal command | `config/deploy.yml` defaults the production host to `production-not-provisioned.invalid`, which does not resolve. Without the variable every production command fails at DNS — deliberately. |
| Both Search Console properties verified → R61 (change of address) | Google's change-of-address tool requires both the source and destination properties to be verified by the same account before it will accept the pair. |
| R20 (drill recorded) → R44 (restore begins) | Stated separately from the Phase 2 → Phase 6 arrow because the gate is the *recorded drill*, not merely a green backup run. |

---

## Interfaces

### Hostnames after this spec

| Name | Zone | Record | Cloud | Serves | In `config.hosts`? |
|---|---|---|---|---|---|
| `syndicatedevelopment.com` | Cloudflare (new) | A → `15.204.81.231` | **grey** | Rails production | **yes** (via `APP_HOST`) |
| `www.syndicatedevelopment.com` | Cloudflare (new) | A → `192.0.2.1` | orange | 301 → apex | no |
| `staging.syndicatedevelopment.com` | Cloudflare (new) | A → `15.204.81.231` | **grey** | Rails staging | yes (staging only) |
| `syndicate-development.com` | Cloudflare (old, after R30) | A → `192.0.2.1` | orange | 301 → new apex | no |
| `www.syndicate-development.com` | Cloudflare (old) | A → `192.0.2.1` | orange | 301 → new apex | no |
| `staging.syndicate-development.com` | Cloudflare (old) | A → `15.204.81.231` | grey | Rails staging (transitional, dropped at R32) | yes, transitionally |
| `mail.syndicate-development.com` | Cloudflare (old) | SPF/DKIM/MX | n/a | Resend, old sending domain — **kept** (R36) | n/a |
| `mail.syndicatedevelopment.com` | Cloudflare (new) | SPF/DKIM/(DMARC) | n/a | Resend, new sending domain | n/a |

Exactly one hostname reaches Rails in production. Every redirect is answered by Cloudflare before
any origin is contacted. See R28 for the argued alternative.

### Files this spec changes

| File | Change | Rule |
|---|---|---|
| `config/deploy.yml` | `proxy.host` and `env.clear.APP_HOST` → `syndicatedevelopment.com`; add top-level `retain_containers` | R23, R5 |
| `config/deploy.staging.yml` | `proxy.host` → comma-separated new+old staging names, then new only; `APP_HOST` → `staging.syndicatedevelopment.com` | R31, R32 |
| `config/environments/production.rb` | `APP_HOST` fallback default → new apex; **remove** the hardcoded `config.hosts << "syndicate-development.com"` | R26 |
| `config/environments/staging.rb` | `APP_HOST` fallback default → `staging.syndicatedevelopment.com`; transitionally allow the old staging name | R31 |
| `config/mail_settings.rb` | `DEFAULT_FROM_ADDRESS` → `noreply@mail.syndicatedevelopment.com` | R33 |
| `docs/deployment/ovh-server-access.md` | Production sections; DNS section; swap/ufw/retention; backup cross-reference | R66 |
| `docs/deployment/backup-restore-drills.md` | **New.** Append-only drill log | R20 |
| `docs/specs/README.md` | Index row for SPEC-017 | — |

No migration. No schema change. No new gem.

### On-box artifacts this spec creates

| Path | Owner / mode | Purpose |
|---|---|---|
| `/swapfile` | root, 0600 | 2 GB swap (R6) |
| `/etc/sysctl.d/60-swappiness.conf` | root, 0644 | `vm.swappiness=10` (R6) |
| `/usr/local/bin/syndicate-backup` | root, 0700 | Nightly dump + tar + upload (R11-R16) |
| `/usr/local/bin/syndicate-backup-verify` | root, 0700 | Weekly freshness check (R18) |
| `/etc/syndicate-backup/rclone.conf` | root, 0600 | R2 credentials (R15) |
| `/etc/syndicate-backup/alert.env` | root, 0600 | Alert-channel credential (R17) |
| `/etc/systemd/system/syndicate-backup.{service,timer}` | root, 0644 | Nightly schedule (R12) |
| `/etc/systemd/system/syndicate-backup-verify.{service,timer}` | root, 0644 | Weekly verifier (R18) |
| `/etc/systemd/system/syndicate-backup-alert@.service` | root, 0644 | `OnFailure=` handler (R17) |

### Environment variables

Required in the **deploying operator's shell** for any production Kamal command. None of these
belongs in CI — production deploys are manual (R3).

| Variable | Purpose | Example value |
|---|---|---|
| `KAMAL_PRODUCTION_HOST` | Production web + accessory host. Without it `config/deploy.yml` resolves `production-not-provisioned.invalid` and every command fails at DNS. | `15.204.81.231` |
| `PRODUCTION_DATABASE_PASSWORD` | Fanned out by `.kamal/secrets` to `POSTGRES_PASSWORD` (initdb) and `SYNDICATE_DEVELOPMENT_2026_DATABASE_PASSWORD` (`config/database.yml`). Both names, one value. | a 32+ char random string |
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc`. On a workstation `.kamal/secrets-common` reads `config/master.key` instead and the variable is unnecessary. | (32-byte hex) |
| `RESEND_API_KEY` | Outbound mail. Production refuses to boot without a resolvable key. | `re_...` |
| `ADMIN_SEED_PASSWORD` | Seeds the two admin accounts. 12+ characters, ≤72 bytes. **Use a production-specific value, not staging's or CI's** (R41). | a 20-char passphrase |
| `KAMAL_REGISTRY_PASSWORD` | ghcr.io token with `write:packages`. Needed even to boot the Postgres accessory. | `ghp_...` |

Not new, and not set by this spec: `APP_HOST`, `RAILS_ENV`, `WEB_CONCURRENCY`, `RAILS_MAX_THREADS`
and `SOLID_QUEUE_IN_PUMA` are supplied by `config/deploy.yml` (the last via the `solid_queue` env
tag on the production web host).

### Cloudflare R2

| Item | Value |
|---|---|
| Bucket | `syndicate-backups`, single region |
| Token scope | **Object Read & Write on `syndicate-backups` only** — not account-wide, not bucket-admin |
| Layout | `daily/YYYY-MM-DD/db.dump`, `daily/YYYY-MM-DD/storage.tar.gz`, `daily/YYYY-MM-DD/MANIFEST`; `monthly/YYYY-MM/…` for the 1st of each month |
| Client | `rclone` (R14) |

---

## Rules

### Cross-cutting

R1: Each phase has a **verification gate** and a **rollback**, both stated in its rules. A phase is
not complete until its verification commands have been run and their output matches what the rule
says it must. Do not begin a phase whose predecessor's gate has not passed.

R2: Where a step cannot be verified by an automated test — DNS propagation, a Cloudflare dashboard
setting, a Resend verification, a Google Search Console action, an OVH or DigitalOcean console
operation — the rule states the **manual verification** instead: the exact command to run and the
exact output to expect, or the exact screen to look at and what it must say. No rule in this spec
invents an RSpec example for something RSpec cannot observe. The Acceptance Tests section marks
every such item `MANUAL`.

R3: **No production deploy job is added to `.github/workflows/ci.yml`.** The `deploy_staging` job
and its six repository secrets are unchanged. Production is deployed by an operator from a
workstation, from a clean checkout, with the Interfaces-section variables exported.

### Phase 1 — Host housekeeping

R4: Record the starting state before changing anything, so the reclaim in R5 and the headroom in R6
can be measured rather than asserted:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@15.204.81.231 \
  'docker system df; free -m; swapon --show; df -h /; sudo ufw status'
```

Expected starting values (verified 2026-09-11): images 7.8 GB, volumes 130 MB, 12 GB used of 38 GB,
790 MB memory in use with 3.0 GB available, `swapon --show` **empty**, `ufw` inactive.

R5: Add `retain_containers: 3` as a top-level key in `config/deploy.yml`.

The 7 retained images are not neglect — they are the Kamal default working as designed.
`kamal deploy` already ends by invoking `prune all` (`Kamal::Cli::Main#deploy`), which prunes
stopped containers down to `retain_containers` (default **5**) and then removes every tagged image
not referenced by a surviving container. Five stopped containers plus the running one plus the
`latest` tag is exactly the seven images observed. **A manual prune today therefore reclaims
nothing**; only lowering the number changes the outcome. After the change, the next staging deploy
prunes automatically, or force it early with:

```bash
bin/kamal prune containers -d staging --retain 3
bin/kamal prune images -d staging
```

> **Do not substitute `docker image prune -a`.** It removes every image not used by a *running*
> container. Kamal's prune deliberately keeps images referenced by *stopped* containers, because
> those stopped containers are what `kamal rollback` boots. The hand-rolled command is strictly
> more destructive and its casualties are precisely the rollback targets.

R6: Add 2 GB of swap. There is none, so memory pressure on this box produces an OOM kill, not
degradation — and the kernel picks its victim by RSS, which on this box means Postgres or Puma.
Peak demand is a **deploy**, when Kamal runs the new container alongside the old until the health
check passes; once production is co-hosted that peak is two app tiers, two Postgres accessories, a
Solid Queue supervisor inside production's Puma, and briefly a duplicate app container, against
3.7 GB. 2 GB is sized to absorb that transient without being large enough that the box thrashes
indefinitely instead of failing visibly.

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
printf 'vm.swappiness=10\n' | sudo tee /etc/sysctl.d/60-swappiness.conf
sudo sysctl --system
```

`vm.swappiness=10` keeps swap as an overflow buffer rather than a routine paging target — the
default of 60 would page out idle Rails memory during normal operation and make request latency
disk-bound.

R7: **Reboot the box** once R6's fstab entry is in place, and confirm swap and all containers
return. An fstab entry that is syntactically wrong does not fail when written; it fails at the next
boot, which would otherwise be an unattended-upgrades reboot months later with production running.
Doing it now costs a staging outage of a minute.

```bash
sudo reboot
# wait, then:
ssh -i ~/.ssh/id_ed25519 ubuntu@15.204.81.231 'swapon --show; docker ps --format "{{.Names}}\t{{.Status}}"'
```

Swap must be listed. `syndicate_development_2026-web-staging`, `syndicate_development_2026-db-staging`
and `kamal-proxy` must all be `Up`. If a container did not return, its restart policy is wrong and
that must be fixed before production is added — not after.

R8: Check whether `unattended-upgrades` reboots automatically:

```bash
grep -r 'Automatic-Reboot' /etc/apt/apt.conf.d/
```

If `Automatic-Reboot "true"` is set, R7's reboot has already proven the box recovers, and no change
is required. If it is set with a `Automatic-Reboot-Time`, record that time in the runbook (R66) so
a future unexplained 03:00 blip is not investigated from scratch.

R9: Enable `ufw` with a default-deny inbound policy and explicit allowances for 22, 80 and 443.

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo ufw status verbose
```

Allow 22 **before** enabling, or the enabling command ends the session that would have fixed it.

> **`ufw` does not protect published Docker ports.** Docker inserts its own rules ahead of ufw's
> filter chain, so a container published on `0.0.0.0` stays reachable from the internet with ufw
> enabled and denying. The `127.0.0.1:` prefixes on `accessories.db.port` in **both**
> `config/deploy.yml` and `config/deploy.staging.yml` remain the only thing keeping Postgres off
> the public internet. Enabling ufw is not a reason to relax them.

What ufw does buy is coverage of host-level listeners — sshd and anything installed outside Docker
— and a default-deny posture for ports nothing is supposed to be on. That is worth having now that
a public production site lands here, provided it is not recorded as more than it is.

**Phase 1 verification gate:** R4's command re-run shows swap present, image usage measurably lower
than the 7.8 GB starting figure, `ufw` active, and all three containers `Up` after a reboot.

**Phase 1 rollback:** `sudo swapoff /swapfile && sudo rm /swapfile` plus removing the fstab line;
`sudo ufw disable`. Pruned images are **not** recoverable locally, but every one of them is still
in ghcr.io by tag and can be pulled — see R42.

### Phase 2 — Backups

R10: Back up the **production primary database only**, plus the production Active Storage volume.
The `cache`, `queue` and `cable` databases are excluded deliberately: all three are created and
loaded by `db:prepare` from `db/cache_schema.rb`, `db/queue_schema.rb` and `db/cable_schema.rb`
(`config/database.yml`), so losing them costs at most a warm cache and any in-flight jobs. Backing
them up would triple the artifact size to protect data that is regenerated on boot.

R11: **Dump the database first, then tar the storage volume.** The ordering is load-bearing, not
stylistic. An upload that lands between the two steps produces either a file with no database row
(if the tar runs second: harmless, an orphan on disk) or a database row with no file (if the tar
runs first: a broken image on a live page, and a restore that passes a row-count check while
rendering wrong). Only one order fails safely.

R12: Schedule with a **systemd timer**, not cron:

```ini
# /etc/systemd/system/syndicate-backup.timer
[Unit]
Description=Nightly Syndicate Development backup

[Timer]
OnCalendar=*-*-* 09:17:00 UTC
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

systemd is chosen over cron for four reasons that all bear on this job specifically: stdout and
stderr land in the journal automatically, where cron mails them to a local mailbox nobody reads —
the single most common way a backup failure goes unseen; `systemctl list-timers` shows last and
next run at a glance; `Persistent=true` runs a schedule missed while the box was down, which cron
does not; and a failed unit is both queryable (`systemctl is-failed`) and able to trigger
`OnFailure=` (R17), which cron has no equivalent for.

09:17 UTC is early morning in Pocatello year-round. The odd minute and `RandomizedDelaySec` avoid a
top-of-hour burst against R2.

R13: The backup script runs under `set -euo pipefail` so that any failing step fails the unit, and
reads the database password **out of the running Postgres container's own environment** rather than
from a second copy on disk:

```bash
docker exec syndicate_development_2026-db sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h 127.0.0.1 -U syndicate_development_2026 \
     -d syndicate_development_2026_production -Fc' > "${WORKDIR}/db.dump"
```

The credential already exists on the box, inside the container Kamal put it in. Copying it into a
backup config file creates a second place it can leak from and a second place it can go stale when
it is rotated.

`-Fc` (custom format) is compressed and lets `pg_restore` select individual tables during a drill.

R14: Tar the Active Storage volume read-only, into the same working directory:

```bash
docker run --rm \
  -v syndicate_development_2026_storage:/data:ro \
  -v "${WORKDIR}":/out \
  alpine tar czf /out/storage.tar.gz -C /data .
```

`:ro` is not decoration: a tar invocation with a typo in an archive path that can write into the
live volume is a backup job that corrupts the thing it backs up.

R15: Upload with `rclone` to Cloudflare R2, using a config file at `/etc/syndicate-backup/rclone.conf`
(root, 0600) holding an R2 API token scoped to **Object Read & Write on the `syndicate-backups`
bucket only**. The token is created in the Cloudflare dashboard and installed on the box by hand
over SSH. It is never committed, never placed in a Docker volume, and never written into
`.kamal/secrets*` — those files are committed and this credential has nothing to do with Kamal.

`rclone` over the AWS CLI: a single static binary with a native Cloudflare R2 S3 provider, built-in
retry, and `rclone delete --min-age` for retention without a separate lifecycle-rule dependency.

R16: Write a `MANIFEST` alongside each night's artifacts recording the UTC timestamp, the app image
version deployed at the time, `pg_dump`'s version, the row count of every table, and the
`active_storage_blobs` count. The drill (R19) checks its restore against this file; without it a
drill can only prove the restore did not error, not that it produced the right data.

R17: A failed run must alert. `syndicate-backup.service` carries
`OnFailure=syndicate-backup-alert@%n.service`, a oneshot unit that posts to the alert channel using
a credential in `/etc/syndicate-backup/alert.env` (root, 0600) and includes the failing unit name
and the last journal lines for it.

R18: `OnFailure=` only fires when the job **runs** and fails. The classic disaster — backups that
stopped months ago — is the job not running at all: a timer disabled by an upgrade, a unit file
lost, a `systemctl enable` never issued. A second, independent weekly timer
(`syndicate-backup-verify.timer`) lists R2 and alerts if the newest object under `daily/` is older
than 48 hours.

This does not cover a box that is entirely dead — but a dead box is a site that is down, which is
detected by other means. The gap it *does* cover is the one nothing else covers: box healthy, site
up, backups silently not running. A third-party dead-man's-switch (a scheduled external check that
alerts on the *absence* of a nightly ping) closes the remaining gap and is a recommended follow-up;
it is not specified here because its free-tier terms could not be verified from this environment
(see R67).

R19: **Perform a restore drill and record it.** The drill restores the previous night's artifacts
into throwaway targets on the box and verifies them against that night's `MANIFEST`:

1. `rclone copy` the previous night's `daily/` prefix to a scratch directory.
2. `createdb` a scratch database — name it `restore_drill_YYYYMMDD` — inside the **existing**
   production Postgres accessory.
3. `pg_restore` the dump into it.
4. Untar `storage.tar.gz` into a scratch directory.
5. Compare every table's row count to `MANIFEST`.
6. For every row in the restored `active_storage_blobs`, assert a file exists at the disk service's
   path for that key (`key[0,2]/key[2,2]/key`) inside the untarred tree. **This is the check that
   matters** — a database restored without its files passes every row count and renders broken
   images.
7. Drop the scratch database and delete the scratch directory.

> **The drill must never restore into `syndicate_development_2026_production`.** Restoring "into
> production to check it works" is the variant that looks efficient and destroys the live database.
> The scratch name is dated precisely so a copy-pasted command cannot silently target the real one.

R20: Record each drill as an append-only entry in a new `docs/deployment/backup-restore-drills.md`:
date, artifact prefix restored, `pg_restore` exit status, row-count comparison result, blob-presence
result (checked/missing counts), operator, and anything that had to be fixed. **The first drill is a
hard gate on Phase 6** — an untested backup is not a backup, and Phase 6 is the first moment
production holds data that exists nowhere else in production. Thereafter: quarterly.

**Phase 2 verification gate:** `systemctl list-timers syndicate-backup.timer` shows a next run;
`journalctl -u syndicate-backup.service` shows one successful run; the R2 bucket contains that
night's three objects; `docs/deployment/backup-restore-drills.md` contains a passing dated entry.

**Phase 2 rollback:** `systemctl disable --now syndicate-backup.timer`. Nothing in Phase 2 modifies
production data; its only write targets are the scratch database and directory the drill creates
and removes.

### Phase 3 — Domain and TLS

R21: **Lower the TTL on every record that might need to be rolled back — the old apex, old `www`,
and old `staging` — to 60 seconds, and do it at the very start of Phase 3.** A TTL reduction is
only in force once the *previous* TTL has expired in every resolver that cached it. Lowering TTLs
on cutover day is a no-op for the rollback you need that day. Record the pre-change TTL; the
reduction must be live for at least that long before Phase 7 begins.

R22: Before touching the old zone at all, export every record it currently serves, from its current
authoritative nameservers, and keep the output:

```bash
for t in SOA NS A AAAA CNAME MX TXT CAA SRV; do
  dig +noall +answer "$t" syndicate-development.com @ns-cloud-a1.googledomains.com
done
for n in www staging mail; do
  for t in A AAAA CNAME MX TXT; do
    dig +noall +answer "$t" "$n.syndicate-development.com" @ns-cloud-a1.googledomains.com
  done
done
```

This is the only reference against which R30's like-for-like migration can be checked. Reconstructing
a DKIM TXT record from memory after the fact is not possible.

R23: `config/deploy.yml`: `proxy.host` and `env.clear.APP_HOST` both become
`syndicatedevelopment.com`. These are two encodings of one fact and the runbook already records
that they must agree — `APP_HOST` sets `config.hosts` and the mailer's canonical host, `proxy.host`
sets what kamal-proxy requests a certificate for.

R24: Create the new zone's records: apex `A → 15.204.81.231` **grey**, `staging A → 15.204.81.231`
**grey**, `www A → 192.0.2.1` **orange**. Verify before proceeding:

```bash
dig +short syndicatedevelopment.com            # must be 15.204.81.231, and nothing else
dig +short staging.syndicatedevelopment.com    # must be 15.204.81.231
```

If the apex answer is a Cloudflare edge address (104.x, 172.6x.x) the record is orange-clouded.
Fix that before Phase 5 — see R25.

R25: **Every record that reaches the box stays grey-clouded, permanently — not only during
certificate issuance.** Two independent reasons:

1. **TLS issuance.** kamal-proxy requests a Let's Encrypt certificate over HTTP-01 when
   `proxy.ssl: true`. With the record orange-clouded, Cloudflare answers :80 and :443 at its edge
   and the challenge does not reliably reach kamal-proxy — the failure is a certificate that never
   issues, on the one deploy where it matters most. This is the single most likely thing to break
   silently in Phase 5.
2. **Client IP, which is the reason it stays grey afterwards.**
   `config/environments/production.rb:52-59` lists `trusted_proxies` as loopback plus the private
   ranges a container network is allocated from, and its own comment states the consequence of a
   missing range: "makes the proxy itself look like a client and collapses every caller onto one
   rate-limit bucket." Cloudflare's edge addresses are **public** and are not in that list. Orange-
   clouding the origin record would put every visitor behind one apparent IP, and SPEC-012's
   contact-form rate limiting counts per IP. The form would throttle the whole internet as one
   caller.

Orange-clouding the origin later is therefore not a free optimisation: it requires adding
Cloudflare's published ranges to `trusted_proxies` **and** setting the zone's SSL mode to **Full
(strict)**. A `Flexible` setting sends plaintext to the origin, kamal-proxy redirects it to HTTPS,
Cloudflare returns that redirect to the browser, and the browser comes back to the same plaintext
hop — an infinite loop. (Rails is not the redirector here: `config.assume_ssl = true` makes Rails
treat every request as already-HTTPS, so `force_ssl` never fires. The loop is kamal-proxy's.)

R26: `config/environments/production.rb`: change the `APP_HOST` fallback default from
`www.syndicate-development.com` to `syndicatedevelopment.com`, and **remove** the hardcoded
`config.hosts << "syndicate-development.com"` line. Under the Interfaces-section design exactly one
hostname reaches Rails, so `config.hosts` needs exactly one entry and every other `Host` header
correctly 403s.

> Removing that line is safe **only** while the old domain is answered by Cloudflare and never
> reaches the app. If the Rails-middleware redirect (R28's rejected alternative) is ever adopted,
> this line must go back **first** — host authorization runs before routing, so the redirect would
> 403 before it could run, and the symptom is a hard 403 on the domain that carries the search
> ranking.

R27: The canonical form is the **apex**, `syndicatedevelopment.com`, with `www` 301ing to it. The
owner named the domain in apex form when designating it primary; Cloudflare serves an apex A record
natively so no CNAME flattening is involved; and it is one label less on the signage and business
cards of a local shop. The choice is arbitrary in SEO terms — what is not arbitrary is that exactly
one of the two is canonical and the other permanently redirects, because
`MetaTagsHelper#page_canonical_url` derives the canonical tag from `request.base_url`
(`app/helpers/meta_tags_helper.rb:11`) and `SitemapsController` builds its URLs from `root_url`.
Serving the same pages on two hostnames would emit two different canonical tags and two different
sitemaps for one site.

R28: **All three 301s — old apex, old `www`, new `www` — live in Cloudflare Redirect Rules, on
orange-clouded records pointing at `192.0.2.1`.** Cloudflare answers them at its edge and never
contacts an origin.

The alternative considered was Rails middleware. It is the better fit for this codebase in every
respect but the decisive one: the redirect would be code, covered by RSpec, versioned with the app,
and it would need no nameserver migration of the old zone — only a single A-record change at Google
DNS. Against that:

- The old domain is the one Google has indexed. Its redirect is what carries four years of ranking
  across, and it must be durable — surviving deploys, restarts and outages. A Rails-served redirect
  shares its fate with the app, and the runbook's own accepted tradeoff on the Solid Queue
  supervisor is that a queue failure signals the Puma master and takes the web tier down with it.
  Coupling the SEO-critical redirect to that is the wrong dependency.
- It requires the old hostnames in `proxy.host` so kamal-proxy issues certificates for them, which
  means four names resolving to the box at issuance time during Phase 5 — more moving parts at the
  riskiest moment, and Let's Encrypt rate limits punish retry loops (R65).
- Every old-domain request would consume a Puma thread on a 2 vCPU box shared with staging.

The cost of the Cloudflare choice is honest and real: routing logic is split across two systems, no
RSpec example can cover it, and it requires R30's nameserver migration of the old zone as a
prerequisite. R59's manual verification exists because of that.

R29: Each Redirect Rule is a **301** (permanent — 302 does not pass ranking) and **preserves the
path and query string**, so `syndicate-development.com/gallery?x=1` lands on
`syndicatedevelopment.com/gallery?x=1`. A rule that drops the path sends every indexed deep link to
the home page, which Google treats as a soft 404 and which is the difference between preserving
rankings and discarding them.

R30: Migrate `syndicate-development.com`'s nameservers from Google Cloud DNS to Cloudflare as a
**pure no-op**: recreate every record from R22's export verbatim — apex still `A → 147.182.199.74`,
`www` still CNAME to apex, `staging` still `A → 15.204.81.231` grey, and every `mail.` SPF/DKIM/MX
record byte-for-byte — then change the nameservers at the registrar. Behaviour before and after must
be identical.

Doing the slow, hard-to-reverse part here, decoupled from any behaviour change, is the point.
Nameserver propagation takes up to 48 hours; Phase 7's redirect flip is then a single record edit at
a 60-second TTL. Verify with the same `dig` loop from R22, against the Cloudflare nameservers, and
diff the two outputs. A DKIM record that differs by one character is a silent mail failure that
surfaces days later as "customers stopped getting replies".

R31: Move staging to `staging.syndicatedevelopment.com` without a gap. Kamal 2.12 accepts multiple
proxy hosts — `Kamal::Configuration::Proxy#hosts` resolves `proxy_config["hosts"] ||
proxy_config["host"]&.split(",")` — so set, transitionally:

```yaml
proxy:
  ssl: true
  host: staging.syndicatedevelopment.com,staging.syndicate-development.com
```

and add the new name to `config/environments/staging.rb`'s `config.hosts` alongside the old.
**Both names must already resolve to the box when the deploy runs**, or issuance fails for the one
that does not. Check each name's certificate individually afterwards — a partial failure leaves the
other name working and looks like success:

```bash
for h in staging.syndicatedevelopment.com staging.syndicate-development.com; do
  echo | openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null \
    | openssl x509 -noout -subject -dates
done
```

R32: Once the new staging name has served for a week, drop
`staging.syndicate-development.com` from `proxy.host`, from `config.hosts`, and from the old zone.
Not before — it is the rollback for R31.

**Phase 3 verification gate:** both new names resolve to `15.204.81.231` from at least two
resolvers; neither returns a Cloudflare edge address; the old zone's `dig` output diffs clean
against R22's export; staging serves on both names with valid certificates.

**Phase 3 rollback:** point the registrar's nameservers back at Google Cloud DNS (slow — treat as
one-way after ~48 h, see R65) and delete the new zone's records. Staging reverts by restoring the
single-host `proxy.host` line and redeploying.

### Phase 4 — Mail

R33: `config/mail_settings.rb`'s `DEFAULT_FROM_ADDRESS` is currently
`noreply@mail.syndicate-development.com` — the domain being retired. It becomes
`noreply@mail.syndicatedevelopment.com`. It is a constant, not an environment variable, so this is a
code change that ships with a deploy.

R34: **Verify `mail.syndicatedevelopment.com` in Resend before R33's change deploys.** Add the
SPF/DKIM records Resend issues to the new Cloudflare zone and wait for Resend's dashboard to show
the domain verified. Ordering matters concretely:
`config/environments/production.rb:105` sets `raise_delivery_errors = true`, and
`ContactsController` delivers synchronously (`deliver_now`), so sending from an unverified domain
turns a customer's contact-form submission into a 500 rather than a queued retry.

*Manual verification:* Resend dashboard shows the domain **Verified**, and a test send from the
production console arrives:

```bash
bin/kamal app exec --reuse "bin/rails runner 'ContactMailer.with(name: %q(deploy check), email: %q(robknowles105@gmail.com), message: %q(SPEC-017 R34)).contact_email.deliver_now'"
```

R35: `APP_HOST` drives `config.action_mailer.default_url_options[:host]`
(`config/environments/production.rb:109-112`), from which password-reset and invitation links are
built as absolute URLs. It changes with R23 in the same deploy as R33; the two must not be split
across deploys, or reset links are issued for a host that is no longer canonical. Links already in
flight at cutover still work — Cloudflare's path-preserving 301 (R29) carries them — and reset
tokens are short-lived anyway.

R36: **Do not delete `mail.syndicate-development.com`'s records, and do not remove the old sending
domain from Resend, at cutover.** Two reasons: R30 must recreate them verbatim in Cloudflare or mail
breaks *before* the new sending domain exists; and keeping the old domain verified through the
overlap window makes a mail rollback a one-line revert of R33 rather than a 48-hour DNS wait. Retire
it with the old domain itself, in 2027.

**Phase 4 verification gate:** Resend shows both sending domains verified; a test send from the new
address arrives with SPF and DKIM passing in the received headers.

**Phase 4 rollback:** revert R33 and redeploy; the old sending domain is still verified (R36).

### Phase 5 — Production deploy

R37: Export `KAMAL_PRODUCTION_HOST=15.204.81.231` in the deploying shell. `config/deploy.yml`
defaults it to `production-not-provisioned.invalid`, which does not resolve — so an accidental
`bin/kamal deploy` without it fails at DNS instead of deploying production onto the staging box.
That default is a guard; do not replace it with the IP in the committed file.

R38: Verify every secret resolves **before** deploying. An unset variable resolves to an empty
string, `kamal config` renders clean with nothing exported, and Kamal writes `KEY=` into the
container — so a missing secret travels into the deploy and surfaces later as a registry auth
failure, a container that never becomes healthy, or a raise from `db/seeds.rb`. The production loop
is in the runbook's Secrets section; run it, plus `KAMAL_PRODUCTION_HOST`.

R39: **Use `bin/kamal setup`, not `bin/kamal deploy`, for the first production run.** Only `setup`
boots accessories (it calls the same deploy path with `boot_accessories: true`). `kamal deploy`
leaves a running accessory alone and never creates a missing one, so on a box with no production
Postgres container the app deploys **successfully** and then cannot reach a database. The failure
looks like an application bug rather than a missing container.

```bash
bin/kamal setup
```

R40: Verify the accessory actually survived. `kamal accessory boot` issues `docker run --detach` and
reports success without waiting on the result; the `postgres:16` image refuses to initdb with an
empty `POSTGRES_PASSWORD` and exits immediately, leaving a "booted" accessory that is not running.

```bash
bin/kamal accessory details db
bin/kamal accessory logs db
bin/kamal app details
curl -sS -o /dev/null -w '%{http_code}\n' https://syndicatedevelopment.com/up   # 200
```

R41: Use a **production-specific `ADMIN_SEED_PASSWORD`**, not staging's and not CI's. Between R39
and the Phase 6 restore, production contains two admin accounts holding this password and is
reachable on the public internet. Phase 6 replaces those rows (R47), so the value is dead
afterwards — which is exactly why it should not be a value that also unlocks staging.

R42: **The production rollback path is `bin/kamal deploy --skip-push --version=<sha>`, not
`bin/kamal rollback <sha>`.**

`Kamal::Cli::Main#rollback` calls `container_available?(version)` and, if the container is gone,
declines with a red message and does nothing. Whether the container is still there is decided by
`retain_containers` — and Kamal's prune filters on `label=service=#{config.service}`, which is
`syndicate_development_2026` for **both** destinations. Staging and production stopped containers
are therefore pooled on this shared box, and because `kamal deploy` ends by pruning, a few staging
deploys after a production release can prune production's rollback container away.

`--skip-push --version=` takes the `kamal:cli:build:pull` path, which pulls the tag from ghcr.io and
does not depend on local retention at all. It fails loudly if the tag is gone from the registry,
which is the failure mode you want. Confirm ghcr.io has no package retention policy that would
expire old tags.

R43: **Phases 5 and 6 are one maintenance window. Do not stop between them.** Between `kamal setup`
completing and the restore finishing, `https://syndicatedevelopment.com` serves seeded placeholder
content, and `RobotsController` sets `@crawlable = Rails.env.production?` — so production's
`robots.txt` says `Allow: /` and a crawler that finds the new apex during the window may index
placeholder copy. The exposure is small (the apex is unlinked, unannounced, and not yet in Search
Console — the old domain still serves the old site) but it is real, and it is bounded only by how
long the operator takes.

**Phase 5 verification gate:** `/up` returns 200 over HTTPS on the canonical host; the certificate's
subject is `syndicatedevelopment.com` and its issuer is Let's Encrypt; `bin/kamal app details` shows
one running web container; `bin/kamal accessory details db` shows a running Postgres; admin login at
`/admin` succeeds **and the session persists across a page load** (the `assume_ssl`/`force_ssl`
trap — a session that silently fails to persist means the proxy is not terminating TLS).

**Phase 5 rollback:** `bin/kamal app stop`. The new domain is not yet advertised and the old domain
still serves the old box, so stopping production affects no traffic. Nothing in Phase 5 touches the
old site, the old domain, or staging.

### Phase 6 — Restore staging content into production

R44: **Take a rollback dump first.** Before restoring anything, run the Phase 2 backup script
manually against the freshly-seeded production database and keep its artifacts. This is the rollback
for the whole phase, and it doubles as the first real exercise of the Phase 2 tooling against
production.

R45: Dump staging's primary database, excluding two tables:

```bash
docker exec syndicate_development_2026-db-staging sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h 127.0.0.1 -U syndicate_development_2026 \
     -d syndicate_development_2026_staging -Fc --clean --if-exists \
     --exclude-table=ar_internal_metadata --exclude-table=schema_migrations' \
  > /tmp/staging-to-production.dump
```

The dump covers the 13 application tables in `db/schema.rb`, including `active_storage_blobs`,
`active_storage_attachments` and `active_storage_variant_records`. Staging's tables are
application-only — it has no `solid_queue_*`, `solid_cache_*` or `solid_cable_*` tables, because
staging runs a single primary database (`config/database.yml`). Staging therefore maps exactly onto
production's **primary**, and production's other three databases are not touched by this phase.

R46: **`ar_internal_metadata` must not arrive from staging.** It holds `environment=staging`, and
the consequence is not cosmetic. `ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!`
decides whether a destructive rake task may proceed by reading the **stored** value in that table
and testing it against `ActiveRecord::Base.protected_environments` (default `["production"]`). A
production database stamped `staging` is therefore **not protected**: `db:drop`, `db:schema:load`
and friends would run against live production data without the refusal that normally stops them.
The guard reads the row, not `Rails.env`.

Excluding the table at dump time (R45) is the primary mechanism — the bad row can never arrive, and
production's own correct row, written by `db:prepare` on first boot, survives untouched. The
post-restore assertion in R52 is the backstop, because someone re-deriving this dump without the
exclusion flag is a realistic failure and it is otherwise invisible.

`schema_migrations` is excluded for a different reason: production's rows were written by
`db:prepare` from the deployed image and are already correct; importing staging's would at best be a
no-op and at worst collide.

R47: **The restore happens after production's first boot, not before.** `db:prepare` runs from
`bin/docker-entrypoint` on server boot; on a fresh database it creates the schema and runs
`db/seeds.rb`. Both orderings work — `db/seeds.rb` is idempotent (`first_or_initialize`,
`find_or_create_by!`, and its FAQ block is guarded on `Faq.count.zero?`), so it would no-op against
restored data, and the two seed admin emails (`robknowles105@gmail.com`, `haskettd@live.com`) are
already among staging's 3 `admin_users`. Restoring second is chosen because it **separates two
variables that would otherwise fail as one**: with restore-after, first boot proves the image, the
proxy, TLS, the accessory and the seed path independently, and the restore is then a single change
whose effect is directly observable (seeded copy before, Doug's copy after) and whose rollback is
R44's dump taken minutes earlier. With restore-before, the first boot is simultaneously the first
test of the deployment and the first test of the restore, and a failure is ambiguous between them.

The costs of this ordering are R43's public placeholder window and R41's seed-password window; both
are named and mitigated there rather than hidden.

`ADMIN_SEED_PASSWORD` must still be set and valid at first boot regardless — `db/seeds.rb` raises
without it, `bin/docker-entrypoint` runs under `bash -e`, and the result is a container restart loop
*after* the databases have been created, which redeploying does not repair.

R48: Restore into production's primary with the app container stopped:

```bash
bin/kamal app stop
docker exec -i syndicate_development_2026-db sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_restore -h 127.0.0.1 -U syndicate_development_2026 \
     -d syndicate_development_2026_production --clean --if-exists --no-owner --single-transaction' \
  < /tmp/staging-to-production.dump
```

`--clean --if-exists` drops and recreates the application tables, which removes the seeded rows
cleanly; the two excluded tables are not dropped and keep production's own values.
`--single-transaction` means a partial restore is not a possible outcome.

R49: **Copy the Active Storage files in the same window as the database.** Blobs are referenced by
`key`, and the Disk service resolves a key to `storage/<key[0,2]>/<key[2,2]>/<key>`; a database
restored without its files passes every row count and renders broken images on every page. Both
volumes are on this one box, so this is a local volume copy, not a network transfer:

```bash
docker run --rm \
  -v syndicate_development_2026_staging_storage:/from:ro \
  -v syndicate_development_2026_storage:/to \
  alpine sh -c 'cp -a /from/. /to/'
```

Source mounted `:ro` — staging's volume is the only copy of these originals until Phase 2's first
production backup runs against them.

R50: **`service_name` needs no rewrite.** Both environments set
`config.active_storage.service = :local` (`production.rb:25`, `staging.rb`) against the same
`config/storage.yml` `local:` entry rooted at `Rails.root.join("storage")` → `/rails/storage` in the
container. Every blob's `service_name` is already `local` and stays correct. Assert it rather than
assume it (R52).

R51: **Copy the variant files; do not regenerate them.** 34 of staging's 45 attachments are
`ActiveStorage::VariantRecord` attachments, and R49's `cp -a` carries them for free. Regenerating
instead would mean deleting the `active_storage_variant_records` rows (otherwise they point at blobs
whose files are missing) and then running 34 libvips transforms on a 2 vCPU box — either eagerly via
a one-off task, or lazily on first request, which is exactly the cold-variant latency SPEC-013 R20
exists to prevent. Rows and files move together as one unit, variants included.

R52: Verify the restore concretely, not by row counts alone:

```bash
bin/kamal app exec --reuse "bin/rails runner '
  meta = ActiveRecord::InternalMetadata.new(ActiveRecord::Base.connection).[](:environment)
  abort(\"environment=#{meta}\") unless meta == \"production\"
  services = ActiveStorage::Blob.distinct.pluck(:service_name)
  abort(\"service_name=#{services.inspect}\") unless services == [\"local\"]
  missing = ActiveStorage::Blob.find_each.reject { |b| ActiveStorage::Blob.service.exist?(b.key) }
  abort(\"missing #{missing.size} blob files\") if missing.any?
  puts \"OK: #{ActiveStorage::Blob.count} blobs, all files present\"
'"
```

Expected counts after the restore (verified against staging 2026-09-11): 3 `admin_users`,
2 `social_media_links` (Instagram and Facebook, both active), 9 `gallery_photos`, 6 `faqs`,
3 `service_sections`, 1 `business_hours`, 1 `site_settings`, 45 `active_storage_attachments`
(9 GalleryPhoto/image + 2 AboutPageContent slideshow + 34 VariantRecord), 45 `active_storage_blobs`,
zero orphaned attachments, zero unattached blobs.

Do not verify by comparing the file **count** in the volume to the blob count: staging's volume held
46 files against 45 blobs on 2026-09-11, and the per-key existence check above is exact where a
count is not.

R53: **`home_page_contents.published` and `about_page_contents.published` are both `false` on
staging, and they arrive that way.** This is the item most likely to be missed, because nothing
errors and the site looks fine — it just is not Doug's site.

With `published: false`:

- the Home hero, mission and CTA copy render bundled `I18n.t("pages.home.*")` defaults, not Doug's
  edits, and both background slots render their bundled static images rather than his uploads
  (SPEC-006, SPEC-013 R7);
- the About shop details, bio and slideshow render bundled defaults (SPEC-007, SPEC-009);
- `og:image`, `twitter:image` and the schema.org `image` all fall back to `BUSINESS_IMAGE`, so
  shared links preview the bundled photo too (SPEC-013 R12, AC-9);
- meanwhile `gallery_photos` has **no** `published` column, so the Gallery renders Doug's 9 real
  photos regardless. The result is a site that is half his and half placeholder, which reads as a
  half-finished launch rather than as a configuration flag.

R54: The flags are a **decision point in the pre-cutover checklist, not a SQL statement in the
restore script.** Doug reviews Home and About in the production admin after R52 passes and publishes
each from the UI — a one-click action he already knows. `published` is admin-facing state meaning
"I am happy for this to be live"; flipping it on his behalf publishes copy he may not consider
finished. Phase 7 does not begin until both are `true` **or** the owner has explicitly decided to
launch with defaults on one of them and recorded that decision.

R55: `site_settings` carries `services_page_published`, which gates `/services` and its inclusion in
`sitemap.xml` (`SitemapsController#show`). Whatever value staging holds is what production gets.
Confirm its intended value in the same review as R54 — a Services page that is live in the sitemap
but disabled, or disabled but expected, is discovered by a visitor, not by a test.

R56: Restart the app and re-run the Phase 5 gate plus a visual check of `/`, `/about` and `/gallery`
with images loading.

**Phase 6 verification gate:** R52's runner prints `OK`; the row counts match R52's table; Home and
About render Doug's content and his uploaded images; the Gallery renders 9 photos; both social icons
appear.

**Phase 6 rollback:** restore R44's dump over the production primary by the same `pg_restore`
command, and `rm -rf` the copied files from production's storage volume. Staging is untouched
throughout — it was read from, never written to — so the source of truth still exists either way.

### Phase 7 — Cutover and post-launch

R57: Pre-cutover checklist, all items confirmed before any DNS change:

- [ ] R20's drill recorded and passing
- [ ] R52's verification printed `OK`
- [ ] R54 decided and, if publishing, both flags `true` in production
- [ ] R55 confirmed
- [ ] R34's test send arrived with SPF/DKIM passing
- [ ] R21's 60-second TTLs live for longer than the previous TTL's duration
- [ ] Both Search Console properties verified (R60)
- [ ] The old box confirmed running and reachable at `147.182.199.74`

R58: Cut over by editing the old zone's records at Cloudflare: apex and `www` become
`A → 192.0.2.1`, orange-clouded, with the R28/R29 Redirect Rules enabled. The old box is not
touched and keeps serving on its IP.

R59: Verify the redirects from a machine outside the network, checking status, `location` and path
preservation. *Manual — no automated test can assert Cloudflare's behaviour:*

```bash
for u in https://syndicate-development.com/gallery \
         https://www.syndicate-development.com/gallery \
         https://www.syndicatedevelopment.com/gallery; do
  curl -sS -o /dev/null -w '%{url_effective} -> %{http_code} %{redirect_url}\n' "$u"
done
curl -sSI https://syndicatedevelopment.com/ | head -1        # 200, not a redirect
```

All three must return **301** with a `location` of `https://syndicatedevelopment.com/gallery`. A 302
does not pass ranking (R29); a `location` without `/gallery` means the rule dropped the path and
every indexed deep link is going to the home page.

R60: Smoke tests against the real domain, after DNS has settled:

| Check | Expected |
|---|---|
| `GET /up` | 200 |
| `GET /` | 200, Doug's hero copy and hero image — not the bundled defaults |
| `GET /about`, `/gallery` | 200, images load |
| `GET /services` | matches R55's decision |
| `GET /sitemap.xml` | 200, every URL on `https://syndicatedevelopment.com` |
| `GET /robots.txt` | `Allow: /`, `Disallow: /admin`, `Sitemap: https://syndicatedevelopment.com/sitemap.xml` |
| TLS certificate | subject `syndicatedevelopment.com`, issuer Let's Encrypt, not expired |
| `GET /admin`, log in | session persists across a page load |
| Contact form submit | delivers; a failure is a 500, not a silent drop (`raise_delivery_errors`) |
| A gallery image URL | 200 with `image/*` — proves R49 |
| `staging.syndicatedevelopment.com/robots.txt` | `Disallow: /` — staging stays out of the index (`RobotsController`) |

R61: Google Search Console, in this order — *manual, no automated verification exists*:

1. Verify **both** properties, old and new, under the same account. Use a DNS TXT record in each
   Cloudflare zone: it survives deploys, container replacement and image rebuilds, where an
   HTML-file or meta-tag method does not.
2. Submit the change of address from the **old** property to the **new** one. Google requires both
   verified and the old site 301ing to the new, which R58 satisfies. The exact property type the
   tool accepts could not be verified from this environment (R67) — if it rejects the pair, add the
   missing property type and retry rather than skipping the step. This is what carries the existing
   indexed site's ranking across.
3. Submit `https://syndicatedevelopment.com/sitemap.xml` under the new property.
4. Leave the old property in place and do **not** remove its sitemap. Google uses the old property
   to observe the redirects.
5. Record the date the change of address was submitted; Google's guidance is that the redirects stay
   in place for at least 180 days afterwards, which R63's retention through 2027 comfortably covers.

R62: Watch for a week: Search Console coverage on both properties, `bin/kamal app logs` for 5xx, and
`journalctl -u syndicate-backup.service` for the first post-launch nightly runs.

R63: Decommission `147.182.199.74` only after **all** of: ≥7 days since R58; the old domain's DNS no
longer resolving to it; and a full copy of its nginx docroot taken and stored in R2 alongside the
backups. The static React build on that box is the only copy of the old site, and once the box is
destroyed nothing reconstructs it. Take a provider snapshot first if one is available — whether
DigitalOcean offers it on this plan, and at what cost, could not be verified from this environment
(R67).

R64: Keep the old domain registered and redirecting through 2027 (owner decision). Retiring it is a
separate decision and a separate change.

R65: **What is and is not reversible.**

Reversible, quickly:

| Action | How to undo | Time |
|---|---|---|
| Cutover (R58) | Disable the Redirect Rules; set the old apex back to `A → 147.182.199.74`, grey | ~1 min at a 60 s TTL |
| A bad production release | `bin/kamal deploy --skip-push --version=<previous-sha>` (R42) | minutes |
| The restore (Phase 6) | `pg_restore` R44's dump | minutes |
| `published` flags (R54) | Admin UI | seconds |
| Staging's rename (R31) | Restore the single-host `proxy.host` and redeploy | one deploy |

Reversible slowly, or effectively one-way:

- **The old zone's nameserver migration (R30).** Reversible in principle by pointing the registrar
  back at Google Cloud DNS, but the Google zone may be deleted and propagation is up to 48 hours.
  Treat as one-way after a few days.
- **Let's Encrypt issuance failures.** Rate limits are per exact name set and per week. **Do not
  loop `bin/kamal deploy` trying to force a certificate through** — a handful of failed attempts can
  lock issuance for that name for a week, turning a DNS misconfiguration into a week-long outage.
  Diagnose with `bin/kamal proxy logs` and fix DNS first.
- **Search Console change of address.** Cancellable, but repeatedly flapping it is worse than either
  state.

Not reversible:

- **Destroying the old box (R63).** Permanent; R63's docroot copy is the only mitigation.
- **`docker volume rm` on a pgdata or storage volume.** Permanent, and it is a plausible typo during
  a recovery — the staging recovery procedure in the runbook legitimately calls for it.
- **A pruned image whose ghcr.io tag has also been removed.** R42's rollback path depends on the
  registry still holding it.

R66: Update `docs/deployment/ovh-server-access.md` in the same PR as the phase that makes each part
false — not in one pass at the end:

| Section | Change | After phase |
|---|---|---|
| **Connecting** | Add swap to the Resources line; note `ufw` is now active | 1 |
| **DNS** | Rewrite. It currently says the domain is at Squarespace with Google nameservers and that the apex resolves to `147.182.199.74`, and it does not mention the new domain at all. Replace with the Interfaces-section hostname table and the grey-cloud rule (R25). | 3, 7 |
| **Production is not provisioned via Kamal yet** | Delete the heading and replace with production's real host, the `KAMAL_PRODUCTION_HOST` requirement, the `setup`-not-`deploy` rule (R39), and the `--skip-push --version=` rollback path (R42) | 5 |
| **The database accessory** | Note both accessories now exist on this box, and that the loopback binding — not `ufw` — is what protects them (R9) | 5 |
| **Rollback** | Add R42's shared-label pruning caveat: `kamal rollback` can find its container pruned by the *other* tier's deploy | 5 |
| **New: Backups** | Point to the systemd units, the R2 bucket, the drill cadence, and `backup-restore-drills.md` | 2 |

R67: **What could not be verified from the authoring environment**, recorded rather than asserted,
in the manner of SPEC-013 R10. Each must be confirmed by the operator at the point of use; none
blocks the spec, and none should be treated as settled because it appears here:

- Cloudflare's free-plan Redirect Rules quota and whether three rules fit within it (R28).
- Cloudflare R2's free-tier storage allowance and egress terms, and therefore whether R16's
  retention fits inside it (R15).
- Whether R2 offers object-lock/immutability on this plan. If it does not, a compromised box can
  delete its own backups — R15's read/write-only token scope limits but does not remove that.
- Google Search Console's current requirements for the change-of-address tool, including which
  property types it accepts (R61).
- Resend's current required DNS record set for a new sending domain, and whether it requires DMARC
  (R34).
- Whether DigitalOcean offers a snapshot on the old box's plan, and its cost (R63).
- Whether ghcr.io has a package retention policy on this account that would expire the image tags
  R42's rollback depends on.

---

## Edge Cases

E1: **The Let's Encrypt certificate does not issue during `kamal setup`.** Most likely cause is an
orange-clouded apex record (R25). Check `dig +short syndicatedevelopment.com` — a `104.x`/`172.6x.x`
answer is Cloudflare's edge, not the box. Fix the record, wait for the 60 s TTL, then redeploy
**once**. Do not loop (R65).

E2: **The certificate issues for one staging name but not the other** during R31's transitional
two-host config. The working name masks the failure; only the per-name `openssl s_client` loop in
R31 detects it.

E3: **`kamal setup` succeeds and the app cannot reach a database.** The accessory reported a boot it
did not survive (R40). `bin/kamal accessory logs db` carries initdb's complaint, which is usually an
empty `POSTGRES_PASSWORD` from an unexported `PRODUCTION_DATABASE_PASSWORD`.

E4: **The app container restart-loops on first boot.** `db/seeds.rb` raised on
`ADMIN_SEED_PASSWORD` after `db:prepare` had already created the databases. Fixing the secret and
redeploying does **not** produce the admin accounts, because `db:prepare` seeds only databases it
created in that same run. Recovery is the runbook's manual `db:seed`.

E5: **The restore runs but images are broken.** R49's volume copy did not run, ran against the wrong
volume name, or ran before the app was stopped and raced an upload. R52's per-key existence check is
what detects it; row counts do not.

E6: **The restore runs and the site shows placeholder copy.** Not a failure — R53. Both `published`
flags arrived `false`. Resolve via R54, not by editing the database.

E7: **`ar_internal_metadata` says `staging` after the restore.** The dump was re-derived without
R45's `--exclude-table`. Fix with
`UPDATE ar_internal_metadata SET value = 'production' WHERE key = 'environment';` and re-run R52.
Do not leave it — R46 explains what protection is lost.

E8: **A staging deploy prunes production's rollback container.** Expected on a shared box (R42).
Roll back through the registry instead.

E9: **The nightly backup fails.** `OnFailure=` alerts (R17). If the alert itself is the thing that
failed, R18's weekly verifier catches the resulting staleness within seven days.

E10: **The backup timer stops running entirely.** R18's independent verifier is the only thing that
detects this; `OnFailure=` cannot, because nothing runs to fail.

E11: **The old domain 301s to the new one, but without the path.** R29's rule was configured to
redirect to a fixed URL rather than preserving the path. Every indexed deep link becomes a soft 404.
R59 detects it; fix the rule before Search Console observes the pattern.

E12: **A customer's contact-form submission 500s after cutover.** The new sending domain is not
verified in Resend, or `DEFAULT_FROM_ADDRESS` shipped ahead of verification (R34). Revert R33 — the
old sending domain is still verified (R36).

E13: **The box OOM-kills a container under deploy pressure.** Phase 1's swap should have absorbed
it. Check `swapon --show` survived the last reboot (R7) and `dmesg -T | grep -i oom` for the victim.

E14: **A visitor's contact-form submission is rate-limited unexpectedly, for everyone at once.** The
origin record was orange-clouded and every visitor now shares one apparent IP (R25). Grey-cloud it.

E15: **The old box is needed back mid-overlap.** Disable the Redirect Rules, set the old apex to
`A → 147.182.199.74` grey. The new domain keeps serving Rails throughout — the two are independent,
which is the reason Phase 3 never touched the old zone's behaviour.

---

## Acceptance Criteria

### Phase 1

AC-1: `swapon --show` on the box lists a 2 GB swap area, and it is still listed after a reboot.

AC-2: `vm.swappiness` reads `10`.

AC-3: `config/deploy.yml` contains a top-level `retain_containers` key.

AC-4: `docker system df` reports image usage measurably below the 7.8 GB recorded in R4, after a
prune with the new retention in force.

AC-5: `sudo ufw status verbose` reports active, default deny incoming, with 22, 80 and 443 allowed.

AC-6: After a deliberate reboot, `syndicate_development_2026-web-staging`,
`syndicate_development_2026-db-staging` and `kamal-proxy` are all running.

### Phase 2

AC-7: `systemctl list-timers syndicate-backup.timer` shows an enabled timer with a next elapse.

AC-8: A completed run has written `db.dump`, `storage.tar.gz` and `MANIFEST` under
`daily/YYYY-MM-DD/` in the R2 bucket.

AC-9: The backup script dumps the database before tarring the storage volume (R11).

AC-10: The backup script contains no database password; it reads `POSTGRES_PASSWORD` from the
running container's environment.

AC-11: `/etc/syndicate-backup/rclone.conf` is mode 0600 and owned by root, and no R2 credential
appears anywhere in the repository.

AC-12: A deliberately failed run produces an alert naming the failing unit.

AC-13: `syndicate-backup-verify.timer` exists, is enabled, and alerts when the newest `daily/`
object is older than 48 hours.

AC-14: `docs/deployment/backup-restore-drills.md` exists and contains at least one dated, passing
entry recording row counts and the blob-presence result — dated **before** Phase 6 was run.

AC-15: The drill restored into a dated scratch database, not into
`syndicate_development_2026_production`.

### Phase 3

AC-16: `dig +short syndicatedevelopment.com` returns exactly `15.204.81.231`.

AC-17: `dig +short staging.syndicatedevelopment.com` returns exactly `15.204.81.231`.

AC-18: Neither name returns a Cloudflare edge address — both records are grey-clouded.

AC-19: The old zone's `dig` export, taken from Cloudflare after R30, matches R22's pre-migration
export from Google Cloud DNS record for record, including every `mail.` SPF/DKIM/MX record.

AC-20: `config/deploy.yml`'s `proxy.host` and `env.clear.APP_HOST` both read
`syndicatedevelopment.com`.

AC-21: `config/environments/production.rb` no longer contains the literal
`"syndicate-development.com"`, and its `APP_HOST` fallback default is the new apex.

AC-22: Staging serves a valid certificate on `staging.syndicatedevelopment.com`, verified per name
rather than by a single request.

### Phase 4

AC-23: `config/mail_settings.rb`'s `DEFAULT_FROM_ADDRESS` reads
`noreply@mail.syndicatedevelopment.com`.

AC-24: Resend shows `mail.syndicatedevelopment.com` verified **and**
`mail.syndicate-development.com` still verified.

AC-25: A test mail sent from production arrives with SPF and DKIM passing.

AC-26: R33's and R23's changes ship in the same deploy (R35).

### Phase 5

AC-27: `https://syndicatedevelopment.com/up` returns 200.

AC-28: The served certificate's subject is `syndicatedevelopment.com` and its issuer is Let's
Encrypt.

AC-29: `bin/kamal app details` shows a running production web container and
`bin/kamal accessory details db` a running production Postgres — checked with the accessory command,
not inferred from a successful deploy.

AC-30: Admin login at `https://syndicatedevelopment.com/admin` succeeds and the session persists
across a subsequent page load.

AC-31: `config/deploy.yml` still defaults the production host to
`production-not-provisioned.invalid`; the real host comes from `KAMAL_PRODUCTION_HOST`.

AC-32: No production deploy job exists in `.github/workflows/ci.yml`.

### Phase 6

AC-33: A rollback dump of the pre-restore production database exists in R2 before the restore runs.

AC-34: After the restore, `ar_internal_metadata`'s `environment` row reads `production`.

AC-35: After the restore, `SELECT DISTINCT service_name FROM active_storage_blobs` returns exactly
`local`.

AC-36: After the restore, every row in `active_storage_blobs` has a corresponding file present, as
asserted per key by R52's runner — not inferred from a file count.

AC-37: Row counts match: 3 `admin_users`, 2 `social_media_links`, 9 `gallery_photos`, 6 `faqs`,
3 `service_sections`, 1 `business_hours`, 1 `site_settings`, 45 `active_storage_attachments`,
45 `active_storage_blobs`.

AC-38: `active_storage_variant_records` and their files are present after the restore — variants were
copied, not regenerated.

AC-39: The `published` state of `home_page_contents` and `about_page_contents` has been explicitly
reviewed and decided before Phase 7 begins, and the decision is recorded.

AC-40: `site_settings.services_page_published` has been explicitly confirmed.

AC-41: No admin account in production authenticates with staging's or CI's `ADMIN_SEED_PASSWORD`.

### Phase 7

AC-42: `https://syndicate-development.com/gallery` returns **301** to
`https://syndicatedevelopment.com/gallery` — path preserved.

AC-43: `https://www.syndicate-development.com/gallery` returns 301 to the same URL.

AC-44: `https://www.syndicatedevelopment.com/gallery` returns 301 to the same URL.

AC-45: `https://syndicatedevelopment.com/` returns 200 and is not itself a redirect.

AC-46: `/sitemap.xml` lists only `https://syndicatedevelopment.com` URLs.

AC-47: `/robots.txt` on production reads `Allow: /` with `Disallow: /admin` and a `Sitemap:` line on
the new apex; on staging it reads `Disallow: /`.

AC-48: A gallery image URL returns 200 with an `image/*` content type.

AC-49: Both Search Console properties are verified by DNS TXT before the change of address is
submitted, and the submission date is recorded.

AC-50: `147.182.199.74` is still running and reachable at its IP for at least 7 days after cutover.

AC-51: A copy of the old box's nginx docroot exists in R2 before the box is destroyed.

AC-52: `docs/deployment/ovh-server-access.md` no longer states that production is not provisioned
via Kamal, and its DNS section describes the two-zone arrangement.

---

## Acceptance Tests

Every test below is `MANUAL` unless marked otherwise. This spec's subject is server and DNS state,
which RSpec cannot observe; the four `AUTOMATED` entries are the repository-file assertions that
genuinely can be. Inventing request specs for DNS or Cloudflare would produce tests that pass
without proving anything.

AT1 — MANUAL
Given the box after Phase 1
When `swapon --show`, `sysctl vm.swappiness`, `docker system df` and `sudo ufw status verbose` are run
Then swap is 2 GB, swappiness is 10, image usage is below R4's recorded figure, and ufw is active with 22/80/443 allowed
Covers: R5, R6, R9, AC-1, AC-2, AC-4, AC-5

AT2 — MANUAL
Given R6's fstab entry is in place
When the box is rebooted
Then swap is still listed and all three staging containers are running
Covers: R7, AC-1, AC-6, E13

AT3 — AUTOMATED
Given `config/deploy.yml`
When inspected
Then it contains a top-level `retain_containers` key, `proxy.host` and `APP_HOST` read `syndicatedevelopment.com`, and the production host still defaults to `production-not-provisioned.invalid`
Covers: R5, R23, R37, AC-3, AC-20, AC-31

AT4 — MANUAL
Given the Phase 2 units are installed
When `systemctl list-timers syndicate-backup.timer` is run and one cycle has completed
Then the timer is enabled with a next elapse, and the R2 bucket holds that night's `db.dump`, `storage.tar.gz` and `MANIFEST`
Covers: R10, R12, R16, AC-7, AC-8

AT5 — AUTOMATED
Given `/usr/local/bin/syndicate-backup` as specified
When inspected
Then `pg_dump` precedes the storage `tar`, and no database password literal appears in the file
Covers: R11, R13, AC-9, AC-10

AT6 — MANUAL
Given a deliberately broken backup run (for example, an unreachable R2 endpoint)
When the timer fires
Then the unit fails and an alert naming the failing unit is received
Covers: R17, AC-12, E9

AT7 — MANUAL
Given the newest `daily/` object in R2 is older than 48 hours
When `syndicate-backup-verify` runs
Then an alert is received
Covers: R18, AC-13, E10

AT8 — MANUAL
Given the previous night's artifacts in R2
When the drill in R19 is performed end to end
Then `pg_restore` exits 0 into a dated scratch database, every table's row count matches `MANIFEST`, every blob key has a file in the untarred tree, and a dated entry is appended to `docs/deployment/backup-restore-drills.md`
Covers: R19, R20, AC-14, AC-15

AT9 — MANUAL
Given the new zone's records after R24
When `dig +short` is run for the apex and the staging name from at least two resolvers
Then both return exactly `15.204.81.231` and neither returns a Cloudflare edge address
Covers: R24, R25, AC-16, AC-17, AC-18, E1, E14

AT10 — MANUAL
Given R22's pre-migration export and the old zone after R30
When the same `dig` loop is run against the Cloudflare nameservers and diffed against the export
Then the two match record for record, including every `mail.` SPF/DKIM/MX record
Covers: R22, R30, R36, AC-19

AT11 — MANUAL
Given staging deployed with R31's two-host `proxy.host`
When `openssl s_client` is run separately against each staging hostname
Then each presents a valid, unexpired certificate for the name requested
Covers: R31, AC-22, E2

AT12 — AUTOMATED
Given `config/environments/production.rb` and `config/mail_settings.rb`
When inspected
Then `production.rb` contains no literal `"syndicate-development.com"` and defaults `APP_HOST` to the new apex, and `DEFAULT_FROM_ADDRESS` is `noreply@mail.syndicatedevelopment.com`
Covers: R26, R33, AC-21, AC-23

AT13 — MANUAL
Given Resend's dashboard after Phase 4
When both sending domains are inspected and a test mail is sent from production
Then both show verified, and the received message passes SPF and DKIM
Covers: R34, R36, AC-24, AC-25, E12

AT14 — MANUAL
Given `KAMAL_PRODUCTION_HOST` and the five secrets exported, and `bin/kamal setup` run
When `bin/kamal app details`, `bin/kamal accessory details db` and `curl https://syndicatedevelopment.com/up` are run
Then one web container and one Postgres container are running and `/up` returns 200
Covers: R37, R38, R39, R40, AC-27, AC-29, E3

AT15 — MANUAL
Given production is deployed
When the certificate is inspected and an admin logs in at `/admin` and then loads another admin page
Then the certificate names `syndicatedevelopment.com` and is issued by Let's Encrypt, and the session persists
Covers: R23, R25, AC-28, AC-30

AT16 — AUTOMATED
Given `.github/workflows/ci.yml`
When inspected
Then it contains `deploy_staging` and no production deploy job
Covers: R3, AC-32

AT17 — MANUAL
Given the pre-restore production database
When the Phase 2 backup script is run manually before Phase 6 begins
Then a dated artifact set exists in R2 and is recorded as the phase's rollback
Covers: R44, AC-33

AT18 — MANUAL
Given the staging dump taken per R45 and restored per R48, with files copied per R49
When R52's runner is executed in the production container
Then it prints `OK` with 45 blobs and aborts on none of its three assertions
Covers: R45, R46, R48, R49, R50, R52, AC-34, AC-35, AC-36, E5, E7

AT19 — MANUAL
Given the restore has completed
When each table's row count is compared to R52's expected values
Then all nine counts match and `active_storage_variant_records` and their files are present
Covers: R45, R51, AC-37, AC-38

AT20 — MANUAL
Given the restored production database
When `home_page_contents.published`, `about_page_contents.published` and
`site_settings.services_page_published` are read and reviewed with the owner
Then each value is explicitly decided and the decision recorded before Phase 7 begins
Covers: R53, R54, R55, AC-39, AC-40, E6

AT21 — MANUAL
Given production after the restore
When `/`, `/about` and `/gallery` are loaded in a browser
Then Doug's copy and uploaded images render — not the bundled i18n defaults and static fallbacks — and the Gallery shows 9 photos
Covers: R53, R54, R56, AC-37

AT22 — MANUAL
Given cutover per R58
When the three redirect URLs in R59 are fetched with `curl`
Then each returns 301 to `https://syndicatedevelopment.com/gallery`, path preserved, and the canonical apex itself returns 200
Covers: R28, R29, R58, R59, AC-42, AC-43, AC-44, AC-45, E11

AT23 — MANUAL
Given production after cutover
When every row of R60's table is checked
Then each matches its expected value, including staging's `robots.txt` still reading `Disallow: /`
Covers: R60, AC-46, AC-47, AC-48

AT24 — MANUAL
Given both Search Console properties
When each is verified by DNS TXT and the change of address is submitted from old to new
Then Google accepts the pair, the new sitemap is submitted, and the submission date is recorded
Covers: R61, AC-49

AT25 — MANUAL
Given ≥7 days have passed since cutover
When `147.182.199.74` is checked and its nginx docroot copied to R2
Then the box is still reachable, the copy exists, and only then is decommissioning authorised
Covers: R62, R63, AC-50, AC-51, E15

AT26 — MANUAL
Given a rollback is required at any point
When the corresponding row of R65's table is executed
Then the previous state is restored within the stated time, and no step listed as irreversible was taken
Covers: R42, R65, E8

AT27 — AUTOMATED
Given `docs/deployment/ovh-server-access.md` after Phase 5 and Phase 7
When inspected
Then it no longer contains "Production is not provisioned via Kamal yet", and its DNS section describes both zones
Covers: R66, AC-52

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-11 | All three 301s live in Cloudflare Redirect Rules on orange-clouded redirect-only records; the origin record stays grey-clouded permanently (R25, R28) | Rails middleware was the better fit for this codebase on three counts — it would be code, covered by RSpec, and it would avoid R30's nameserver migration entirely (a single A-record edit at Google DNS would do). It was rejected on durability. The old domain carries the ranking, so its redirect must outlive the app, and this deployment couples job failure to web availability by design (the runbook's accepted tradeoff: Puma's `solid_queue` plugin signals the master when the supervisor dies). A redirect that shares its fate with the app is the wrong dependency for the one piece of routing that must never be down. Secondary: it would put the old hostnames into `proxy.host`, meaning four names resolving to the box at Let's Encrypt issuance time during the single riskiest command in this spec, with rate limits that punish retries. The grey/orange split falls out cleanly because the zones do different jobs — the redirect-only records never contact an origin, so they can be proxied without touching the app, while the origin record must stay unproxied because `config/environments/production.rb`'s `trusted_proxies` list contains only private ranges and Cloudflare's edge is public. Orange-clouding the origin would collapse every visitor onto one rate-limit bucket, which the file's own comment warns about in as many words. |
| 2026-09-11 | Apex `syndicatedevelopment.com` is canonical; `www` redirects to it (R27) | Arbitrary in SEO terms — Google treats either as fine so long as one is chosen and the other permanently redirects. Chosen on three small grounds: the owner named the domain in apex form when designating it primary, Cloudflare serves an apex A record natively so no CNAME flattening is involved, and it is one label shorter on a local shop's signage. What is *not* arbitrary is that exactly one hostname reaches Rails: `page_canonical_url` derives the canonical tag from `request.base_url` and `SitemapsController` builds from `root_url`, so serving both would emit two canonical tags and two sitemaps for one site. |
| 2026-09-11 | The restore happens after production's first boot, not before (R47) | Both orderings work on the merits — `db/seeds.rb` is idempotent and its two admin emails are already among staging's three rows, so seeding either no-ops against restored data or is overwritten by it. The deciding factor is diagnosis. Restore-after means the first boot proves the image, kamal-proxy, TLS, the accessory and the seed path on their own, and the restore is then one change with a directly observable effect and a rollback dump taken minutes earlier. Restore-before makes the first boot simultaneously the first test of the deployment and the first test of the restore, so a failure is ambiguous between them and the box has to be unpicked to find out which. The costs — a public window serving placeholder content, and an admin account holding `ADMIN_SEED_PASSWORD` for that window — are real, and are handled by R43 (do not stop between Phases 5 and 6) and R41 (a production-specific seed value that the restore then destroys) rather than by pretending they do not exist. |
| 2026-09-11 | `ar_internal_metadata` excluded at dump time, with a post-restore assertion as backstop (R45, R46, R52) | Excluding it means the bad row can never arrive and production's own correct row, written by `db:prepare` on first boot, survives untouched — better than importing and rewriting, which depends on remembering a second step. The assertion in R52 is not redundant: someone re-deriving this dump without the `--exclude-table` flag is a realistic failure and it is otherwise completely invisible. What makes it worth two mechanisms is the consequence, which is not cosmetic: `check_protected_environments!` decides whether a destructive rake task may proceed by reading the **stored** value and testing it against `protected_environments`, which defaults to `["production"]`. A production database stamped `staging` is not protected, so `db:drop` and `db:schema:load` would run against live data without the refusal that normally stops them. |
| 2026-09-11 | Active Storage variants are copied, not regenerated (R51) | Both volumes are on the same box, so `cp -a` carries all 34 variant files for free. Regenerating would first require deleting the `active_storage_variant_records` rows — they would otherwise reference blobs whose files are absent — and then running 34 libvips transforms on a 2 vCPU box, either eagerly as a one-off task or lazily on first request, which is precisely the cold-variant latency SPEC-013 R20 was written to prevent. Copying also keeps the invariant this phase rests on: rows and files move together as one unit. |
| 2026-09-11 | `published` flags are surfaced as a decision point, not flipped in SQL (R53, R54) | The flags are admin-facing state whose meaning is "I am happy for this to be live". Setting them on Doug's behalf during a migration publishes copy he may consider unfinished, and it does so invisibly. Surfacing them as a checklist gate costs one round trip and keeps the decision where it belongs. The reason this needs a rule at all rather than a line in a checklist is that the failure is silent: with both flags false the site renders the bundled i18n defaults and static fallback images and looks entirely fine, while the Gallery — which has no `published` column — renders Doug's nine real photos, producing a site that is half his and half placeholder. |
| 2026-09-11 | systemd timer rather than cron for backups (R12) | Four reasons that all bear on this job in particular: journald captures stdout and stderr automatically where cron mails them to a local mailbox nobody reads, which is the single most common way a backup failure goes unnoticed; `systemctl list-timers` answers "is this actually scheduled" at a glance; `Persistent=true` catches up a run missed while the box was down, which cron does not; and `OnFailure=` gives a failed run somewhere to go, which cron has no equivalent for. |
| 2026-09-11 | Database dumped before the storage volume is tarred (R11) | An upload landing between the two steps produces an orphan file if the tar runs second, or a row with no file if the tar runs first. The first is harmless and invisible; the second is a broken image on a live page and a restore that passes every row-count check while rendering wrong. Only one order fails safely, and the ordering is not recoverable by inspection afterwards. |
| 2026-09-11 | Production rollback goes through the registry (`--skip-push --version=`), not `kamal rollback` (R42) | Verified against Kamal 2.12.0: `Kamal::Cli::Main#rollback` calls `container_available?(version)` and declines if the container is gone, and `Kamal::Commands::Prune` filters on `label=service=#{config.service}` — which is `syndicate_development_2026` for both destinations, because `service` is the base key and only `service_and_destination` carries the suffix. Staging and production stopped containers are therefore pooled on this shared box, and since every `kamal deploy` ends by invoking `prune all`, a few staging deploys after a production release can prune production's rollback container away. `--skip-push --version=` takes the `build:pull` path, which pulls the tag from ghcr.io and does not depend on local retention. It fails loudly if the tag is gone, which is the right failure mode. |
| 2026-09-11 | `ufw` enabled, but recorded as covering host listeners only (R9) | Docker inserts its own rules ahead of ufw's filter chain, so a container published on `0.0.0.0` stays reachable with ufw enabled and denying. Enabling ufw is still worth doing — it covers sshd and anything installed outside Docker, and gives a default-deny posture now that a public production site lands here — but recording it as "Postgres is now firewalled" would be false and would invite someone to widen the `127.0.0.1:` binding in the deploy configs on the strength of it. The loopback prefix remains the load-bearing control and the rule says so. |
| 2026-09-11 | 2 GB swap rather than none, 4 GB, or a smaller box change (R6) | With no swap, memory pressure produces an OOM kill rather than degradation, and the kernel picks by RSS — meaning Postgres or Puma. Peak demand is a deploy, when Kamal runs the new container alongside the old until the health check passes; co-hosted, that peak is two app tiers, two Postgres accessories, a Solid Queue supervisor inside production's Puma, and briefly a duplicate app container against 3.7 GB. 2 GB absorbs that transient. More would let the box thrash indefinitely instead of failing visibly, which on a marketing site is worse than a restart. Disk cost is negligible against 27 GB free, more after R5. |

---

## Dependencies

- **`docs/deployment/ovh-server-access.md`** — the authority on SSH access, the `ubuntu`-not-`root`
  rule, the Kamal secrets model, the accessory topology, the Solid Queue arrangement, the CI
  host-key pin and every existing recovery procedure. Not restated here. R66 specifies the edits it
  needs once production exists.
- **`.claude/standards/practices/deployment-strategy.md`** — §1.2 and §1.6 require that the same
  image built for staging is *promoted* to production rather than rebuilt. The owner's decision that
  production deploys are a manual `bin/kamal deploy` is in tension with that: a plain `deploy`
  builds. R42's `--skip-push --version=<sha>` is the promotion path that satisfies both, and the
  operator should use it for every production release after the first. The first run is necessarily
  `kamal setup` (R39), which builds, because there is no prior production release to promote. **This
  tension is flagged, not resolved by fiat** — if the owner prefers strict promotion from the first
  release, that is a change to R39 and should be decided before Phase 5.
- **SPEC-012 (SEO/AEO Pass)** — owns `SitemapsController`, `RobotsController`, `MetaTagsHelper` and
  the contact-form rate limiting. R25's client-IP argument and R27's canonical argument both rest on
  its behaviour; R60 smoke-tests it.
- **SPEC-013 (Home Hero and CTA Image Uploads)** — R53's `og:image` fallback behaviour is SPEC-013
  R12/AC-9. R51's variant-copy decision cites its R20.
- **SPEC-006, SPEC-007, SPEC-009** — establish the `published` gating on `HomePageContent` and
  `AboutPageContent` that R53 depends on.
- **ADR-005 (Photo Upload Data Model and Active Storage Strategy)** — establishes the local Disk
  service and the variant strategy that Phases 2 and 6 move.
- **Cloudflare account** — already held for the new domain's DNS; also hosts the R2 bucket and,
  after R30, the old zone.
- **Resend account** — already in use; needs the new sending domain verified.
- **Google Search Console access** — needed for R61. Confirm the account that will hold both
  properties before Phase 7.
- No new gems. No migration.

---

## Proposed Task Breakdown

| Task | Description | Phase | Points |
|------|-------------|-------|--------|
| T1 | Record baseline (R4); add `retain_containers` to `config/deploy.yml`; prune; add swap and swappiness; reboot and verify containers return; check unattended-upgrades reboot policy; enable ufw | 1 | 3 |
| T2 | Write `syndicate-backup` and its systemd unit + timer; `OnFailure=` alert unit; R2 bucket, scoped token, rclone config; `MANIFEST` generation; retention | 2 | 4 |
| T3 | Write `syndicate-backup-verify` and its timer; run one full cycle; perform the restore drill; create `docs/deployment/backup-restore-drills.md` with the first entry | 2 | 3 |
| T4 | Lower TTLs; export old zone (R22); create new zone records grey/orange per the Interfaces table; update `config/deploy.yml` and `config/environments/production.rb` host constants | 3 | 3 |
| T5 | Like-for-like nameserver migration of the old zone to Cloudflare; diff against R22's export | 3 | 3 |
| T6 | Staging rename: two-host `proxy.host`, `config.hosts`, deploy, per-name certificate check | 3 | 2 |
| T7 | Verify new Resend sending domain; update `DEFAULT_FROM_ADDRESS`; test send with SPF/DKIM check | 4 | 2 |
| T8 | Export production secrets; `bin/kamal setup`; verify accessory, `/up`, certificate, admin session | 5 | 3 |
| T9 | Rollback dump; staging dump with exclusions; `pg_restore`; volume copy; R52 verification; row-count check | 6 | 4 |
| T10 | `published` / `services_page_published` review with the owner; record the decision | 6 | 1 |
| T11 | Cutover: old-zone redirect records and rules; redirect verification; full smoke-test table | 7 | 3 |
| T12 | Search Console: verify both properties by DNS TXT, submit change of address, submit sitemap, record dates | 7 | 2 |
| T13 | Week of observation; old box docroot copy to R2; decommission | 7 | 2 |
| T14 | `docs/deployment/ovh-server-access.md` updates, landed alongside the phase that makes each section false (R66) | 1-7 | 3 |

Total estimated points: 38. T2 and T9 are at the 4-point guardrail and should each be reviewed
before the next task begins.

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-09-11 | Initial draft | All | Translates the owner's eight settled decisions into an executable, phase-ordered runbook. Records the ordering constraints as hard dependencies with their failure modes rather than as section order. Argues the 301's placement (R28) rather than asserting it, and grounds the grey-cloud rule in `config/environments/production.rb`'s own `trusted_proxies` comment (R25) rather than in generic Cloudflare advice. Surfaces four things verified against the installed sources that the existing configuration does not anticipate: that `ar_internal_metadata` carrying `environment=staging` disables Rails' destructive-task protection outright rather than merely mislabelling the database (R46); that Kamal's prune filters on a service label shared by both destinations, so staging deploys can prune production's rollback container and `kamal rollback` then declines (R42); that the 7.8 GB of images is `retain_containers: 5` working as designed, so a manual prune reclaims nothing and only lowering the number helps (R5); and that `ufw` does not cover Docker-published ports, so the loopback bindings remain load-bearing (R9). Records the `published = false` flags as a gated decision point rather than a SQL statement (R53, R54), and the seven things that could not be verified from the authoring environment as open items rather than as settled facts (R67). |

---

## Open Questions

1. **Strict image promotion from the first release?** `.claude/standards/practices/deployment-strategy.md`
   §1.6 requires the staging-tested image be promoted, never rebuilt. R39's first run is
   `kamal setup`, which builds. Every release after it can use R42's `--skip-push --version=<sha>`.
   If the owner wants strict promotion from release one, R39 changes and the mechanism needs
   rehearsing on staging first.
2. **Site uptime alerting.** Out of scope here (Phase 2 makes *backup* failure loud, not site
   failure). Worth a follow-up: with staging and production sharing one box and a Solid Queue
   supervisor that can signal Puma's master, an outage currently has no notification path.
3. **Staging's `WEB_CONCURRENCY`.** Both tiers run 2 workers × 5 threads on a 2 vCPU box. Dropping
   staging to 1 would free memory, but `.claude/standards/practices/deployment-strategy.md` §1.1
   requires staging be an infrastructure replica of production. Phase 1's swap is the chosen answer;
   revisit only if swap is seen in steady use rather than at deploy peaks.
4. **Third-party dead-man's-switch for backups.** R18's weekly verifier covers "box healthy,
   backups silently stopped". An external check that alerts on the absence of a nightly ping would
   close the remaining gap; its free-tier terms could not be verified from here (R67).
