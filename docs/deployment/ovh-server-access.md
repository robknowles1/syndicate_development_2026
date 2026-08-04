# OVH Staging Server — Access and Deploy Runbook

How to reach the staging box, how to deploy to it, and how to recover it when a deploy
leaves it half-provisioned. No secrets are recorded here; passwords and tokens are
deliberately excluded.

**Last verified:** 2026-07-28

Staging runs on a single OVH box and is deployed automatically by the `deploy_staging`
job in `.github/workflows/ci.yml` on every push to `main`. Everything below is either a
prerequisite for that job, or what to do by hand when it is not the right tool.

- [Connecting](#connecting) · [Why `ubuntu` and not `root`](#why-ubuntu-and-not-root) ·
  [Rebuilt or replacement server](#establishing-access-on-a-rebuilt-or-replacement-server)
- [DNS](#dns) · [Before the first deploy](#before-the-first-deploy) ·
  [Secrets](#secrets) · [Deploying](#deploying)
- [The database accessory](#the-database-accessory) ·
  [The Solid Queue supervisor](#the-solid-queue-supervisor) ·
  [Recovery](#recovery)

---

## Connecting

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@15.204.81.231
```

| | |
|---|---|
| Provider | OVH |
| IPv4 | `15.204.81.231` |
| User | `ubuntu` — **not** `root` |
| Key | `~/.ssh/id_ed25519` |
| OS | Ubuntu 26.04 LTS (kernel 7.0.0) |
| Resources | 2 vCPU · 3.7 GB RAM · 38 GB disk |
| Hostname | `staging.syndicate-development.com` |

Key authentication works without a password. Verify with:

```bash
ssh -o BatchMode=yes -i ~/.ssh/id_ed25519 ubuntu@15.204.81.231 whoami
```

`BatchMode=yes` disables password prompting, so a successful result proves the key
itself is working rather than a password silently filling in.

---

## Why `ubuntu` and not `root`

Root SSH login is disabled on this image (`PermitRootLogin no`), which is the default
for modern Ubuntu cloud images. The server still advertises `publickey,password` as
available authentication *methods*, so `root` attempts fail with a plain
`Permission denied` that looks identical to a wrong password — no message says root is
refused outright. Every root attempt will fail no matter how correct the password is.

Kamal defaults to `root`, which is why `config/deploy.yml` sets `ssh.user: ubuntu`.
Without that, every Kamal command fails with the same bare `Permission denied` that
looks like a bad key.

OVH emails a one-time secret link containing an initial password. That password belongs
to the `ubuntu` user, not `root`, and the secret page does not say so.

The initial password was changed on first login and is not recorded here. It is no
longer needed for anything — key authentication has replaced it.

---

## Establishing access on a rebuilt or replacement server

If this box is rebuilt, or a second one is added, the same sequence applies.

1. Accept the host key on first contact:

   ```bash
   ssh -o StrictHostKeyChecking=accept-new ubuntu@NEW_IP whoami
   ```

   Without this, a non-interactive shell fails with `Host key verification failed`
   because it cannot prompt for confirmation.

2. Install the public key — **run this in a real terminal**, not through tooling that
   lacks a TTY, or the password prompt cannot be answered and it will report
   `Permission denied` after submitting nothing:

   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@NEW_IP
   ```

3. If the IP was previously used by a different server, clear the stale host key first:

   ```bash
   ssh-keygen -R NEW_IP
   ```

A rebuild also invalidates the CI host-key pin and wipes the deploy key CI uses. See
[A deploy fails with a host-key fingerprint
mismatch](#a-deploy-fails-with-a-host-key-fingerprint-mismatch).

---

## DNS

The domain is registered at **Squarespace**, which also serves DNS (nameservers are
`ns-cloud-*.googledomains.com`, inherited from Google Domains). DNS records are edited
in the Squarespace panel, not at OVH.

The apex currently resolves to `147.182.199.74` — a **DigitalOcean** host serving the
existing live site. Staging must therefore use a subdomain; repointing the apex would
take the current site down.

Resend sends from the verified subdomain `mail.syndicate-development.com`, whose
SPF/DKIM/MX records are already live in Squarespace DNS.

**DNS must be pointed before the first deploy, not after.** The `proxy:` block sets
`ssl: true`, which makes kamal-proxy request a Let's Encrypt certificate for
`proxy.host`. That requires the name to already resolve to this server and port 443 to
be reachable from the internet.

---

## Before the first deploy

### Do not install Docker by hand

Docker is **not installed** on a fresh box, and `ubuntu` is **not** in the `docker`
group. Leave it that way.

`kamal server bootstrap` — which `kamal setup` invokes automatically — tests `docker -v`
and, **only on failure**, installs Docker, runs `sudo -n usermod -aG docker "$USER"`,
then refreshes the session. Passwordless sudo is already in place, so it needs nothing
from an operator.

Getting this wrong is quiet rather than loud. Pre-install Docker yourself and Kamal
skips that entire block — including the group membership — and every subsequent command
fails against the Docker socket instead. Running `usermod -aG docker ubuntu` ahead of
time does not help either: it fails outright, because the group does not exist until
Docker is installed.

### Configuration prerequisites

These are enforced by application config, not by convention — the app refuses to start
if they are missing. Each traces to a specific review finding.

- **`ADMIN_SEED_PASSWORD`, 12+ characters, set before the first deploy.**
  `bin/docker-entrypoint` runs `db:prepare` under `bash -e`, and `db/seeds.rb` aborts
  without it. Because that runs before the server starts, a missing value produces a
  **container restart loop** — after the databases have already been created. See
  [The admins were not seeded](#the-admins-were-not-seeded).
- **The `proxy:` block in `config/deploy.yml` must be enabled.** Production sets
  `assume_ssl`, which makes Rails trust proxy headers about HTTPS. With no terminating
  proxy, plaintext requests are read as secure, `force_ssl` stops redirecting, and the
  admin session cookie is marked `Secure` over HTTP — browsers then refuse to send it
  back and **admin login silently fails to persist**.
- **`RESEND_API_KEY` and the Rails master key.** Production and staging refuse to boot
  without them, deliberately: previously a missing key booted clean and failed only when
  a customer submitted the contact form. `config/application.rb` can fall back to the
  encrypted credential `resend.api_key`, but that key is not present in credentials, so
  the environment variable is currently mandatory.
- **`STAGING_DATABASE_PASSWORD`** — staging does not fall back to production's.
- **Host authorization is active.** Any `Host` header not in `config.hosts` gets a 403.
  Production lists `www.syndicate-development.com` and the apex; staging lists
  `staging.syndicate-development.com`. DNS must match one of these, and `APP_HOST` must
  match `proxy.host` in the Kamal config.
- **`CONTACT_RECIPIENT_EMAIL` needs no value on either tier.**
  `config/mail_settings.rb` returns the developer address for every non-production
  environment regardless of what is set, and falls back to the shop address in
  production. Setting it outside production has no effect.

---

## Secrets

### Which files Kamal reads

Kamal reads exactly two secrets files per invocation, and which two depends on the
destination:

| Command | Files read |
|---|---|
| `bin/kamal deploy` (no destination) | `.kamal/secrets-common` + `.kamal/secrets` |
| `bin/kamal deploy -d staging` | `.kamal/secrets-common` + `.kamal/secrets.staging` |

The base `.kamal/secrets` file is **not** read when a destination is given. Anything
shared between destinations therefore has to live in `secrets-common`.

All three files are committed. None of them holds a value: every line reads from the
deploying shell's environment. Never paste a real credential into one.

Each destination file fans its one exported database password out to two names, because
two different consumers read it: `POSTGRES_PASSWORD` is read by the `postgres:16` image's
initdb when the accessory first boots, and the tier-specific name
(`STAGING_DATABASE_PASSWORD`, `SYNDICATE_DEVELOPMENT_2026_DATABASE_PASSWORD`) by the
matching block in `config/database.yml`. Both lines are required; they are not a
duplicate to be deduplicated.

### Verify the values are present before deploying

An unset variable resolves to an **empty string** rather than an error. `kamal config`
renders clean with nothing exported, and Kamal writes `KEY=` into the container rather
than omitting the key — so a missing secret travels all the way into the deploy and
surfaces much later, as a registry auth failure, a container that never becomes
healthy, or a raise from `db/seeds.rb`.

Check before deploying. The list differs per destination, because the database password
is not shared:

```bash
# staging — bin/kamal deploy -d staging
for v in KAMAL_REGISTRY_PASSWORD RESEND_API_KEY ADMIN_SEED_PASSWORD \
         STAGING_DATABASE_PASSWORD; do
  [ -n "${!v}" ] && echo "$v set" || echo "$v MISSING"
done
```

```bash
# production — bin/kamal deploy, no destination (not provisioned yet)
for v in KAMAL_REGISTRY_PASSWORD RESEND_API_KEY ADMIN_SEED_PASSWORD \
         PRODUCTION_DATABASE_PASSWORD; do
  [ -n "${!v}" ] && echo "$v set" || echo "$v MISSING"
done
```

`RAILS_MASTER_KEY` is absent from both loops on purpose. On a workstation,
`.kamal/secrets-common` reads `config/master.key` and the variable is not needed. In CI
that file does not exist (`.gitignore` excludes `config/*.key`) and the variable is
mandatory — which is why the deploy job checks it alongside the other five.

`KAMAL_REGISTRY_PASSWORD` is needed even to boot the Postgres accessory, not only to
deploy the app: `Kamal::Cli::Accessory#prepare` runs `docker login` against the **root**
registry config before it pulls `postgres:16`. The accessory declares no registry of its
own, so it inherits that one.

### `ADMIN_SEED_PASSWORD` bounds

At least **12 characters**, at most **72 bytes**. The two bounds are in different units
on purpose:

- **12 characters** is `AdminUser::MINIMUM_PASSWORD_LENGTH`, which the model validates
  with a character-counted length validator.
- **72 bytes** is bcrypt's input limit, which `has_secure_password` enforces on encoded
  bytes.

For an ASCII password the two numbers coincide. For a multi-byte passphrase they do not,
and a byte-counted *minimum* would wave through a value that `db/seeds.rb` then rejects
— the exact mid-deploy failure the checks exist to prevent. `db/seeds.rb` reads both
bounds from those sources rather than restating them.

`db/seeds.rb` validates the value **before writing anything** and raises naming the
variable when it is unset, blank, too short or too long. It reads `ENV[...]` rather than
`ENV.fetch`, because Kamal writes `KEY=` into the container when a secret resolves to
nothing — present but empty, a case a `fetch` default block never sees.

What that guard cannot do is fail *cheaply*. See
[The admins were not seeded](#the-admins-were-not-seeded).

### GitHub Actions secrets

The `deploy_staging` job needs six repository secrets, under
**Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|---|---|
| `DEPLOY_SSH_PRIVATE_KEY` | deploy key for `ubuntu@15.204.81.231` |
| `RAILS_MASTER_KEY` | decrypts `config/credentials.yml.enc` |
| `KAMAL_REGISTRY_PASSWORD` | ghcr.io token with `write:packages` |
| `RESEND_API_KEY` | outbound mail |
| `ADMIN_SEED_PASSWORD` | seeds both admin accounts — bounds above |
| `STAGING_DATABASE_PASSWORD` | staging Postgres |

`${{ secrets.X }}` renders as an empty string when the secret is not set, and the
`.kamal/secrets*` files resolve an unset variable the same way — so a blank secret is
never rejected at the point it is supplied. The **Verify deploy secrets are usable**
pre-flight step is what stops that. It runs first, before checkout and before Ruby, so a
misconfigured repository fails in seconds without loading an SSH key or contacting the
server.

That step measures `ADMIN_SEED_PASSWORD` with `wc -m` for the minimum and `wc -c` for
the maximum, mirroring the character/byte split above rather than averaging over it.
`wc -c` counts bytes regardless of locale; `wc -m` counts characters only under a UTF-8
locale, hence the explicit `LC_ALL` on that one line. The numbers there are a third
encoding of one rule and must be updated whenever `AdminUser::MINIMUM_PASSWORD_LENGTH`
changes. No secret value, prefix, or length is ever printed.

---

## Deploying

### Routine deploys

Merging to `main` deploys staging. CI runs `bin/kamal deploy -d staging` after
`scan_ruby`, `scan_js`, `lint`, `test` and `system-test` are all green. Deploys are
serialised by a `deploy-staging` concurrency group with `cancel-in-progress: false`,
because killing a deploy mid-flight can strand the box between releases.

To deploy the same thing by hand:

```bash
bin/kamal deploy -d staging
```

### Production is not provisioned via Kamal yet

`config/deploy.yml` defaults the production host to the RFC 2606 placeholder
`production-not-provisioned.invalid`, overridable with `KAMAL_PRODUCTION_HOST`. That name
does not resolve, so `kamal config` still renders while an accidental `bin/kamal deploy`
with no destination fails immediately at DNS rather than deploying production onto the
staging box. Replace it — or export the variable — when production is provisioned.

### First deploy on a fresh box

Use `setup`, not `deploy`:

```bash
bin/kamal setup -d staging
```

**`kamal deploy` does not boot accessories.** Only `kamal setup` does — it calls the
same deploy path with `boot_accessories: true`, and additionally runs
`kamal server bootstrap` to install Docker. `kamal deploy` leaves a running accessory
alone and never creates a missing one, so on a box with no Postgres container the app
deploys successfully and then cannot connect to a database.

To boot or reboot the accessory on its own:

```bash
bin/kamal accessory boot db -d staging
```

Read [The accessory says it booted but nothing is
running](#the-accessory-says-it-booted-but-nothing-is-running) before trusting the
output of that command.

### Aliases

Defined in `config/deploy.yml`; all accept `-d staging`.

```bash
bin/kamal console -d staging   # rails console
bin/kamal shell   -d staging   # bash in the app container
bin/kamal logs    -d staging   # tail app logs
bin/kamal dbc     -d staging   # rails dbconsole
```

### Rollback

```bash
bin/kamal app containers -d staging   # find the previous version tag
bin/kamal rollback <version> -d staging
```

Rollback re-points the proxy at a previous container; it does not undo migrations. Roll
the database forward with a new migration instead.

---

## The database accessory

Postgres 16 runs as a Kamal accessory on the same box. The app reaches it by container
name over the shared `kamal` Docker network — `syndicate_development_2026-db-staging`,
which is what `STAGING_DATABASE_HOST` must match — not over the published host port.

The published port is bound to **loopback only**, on both tiers. `ufw` is inactive on
this box, so publishing on `0.0.0.0` would put Postgres directly on the public internet.

Neither accessory container names nor published host ports are namespaced by
destination, and the two are kept apart differently. Kamal derives an accessory's
container name as `<service>-<name>` and appends nothing for the destination, so
`config/deploy.staging.yml` sets `service: syndicate_development_2026-db-staging`
explicitly — without that line staging and production would both claim
`syndicate_development_2026-db`. Host ports cannot be disambiguated that way at all,
which is why staging publishes on **5433** rather than 5432: if production is ever
deployed to this same box, whichever accessory started second would fail to bind. Only
the host side moves — the container still listens on 5432, so `STAGING_DATABASE_HOST`
resolving to the service name is unaffected. The mapping cannot simply be dropped
either: Kamal validates `port` as a string, so a null fails with
`accessories/db/port: should be a string`, and an inherited key can be overridden but
not removed.

What the mapping buys is host-side access for debugging. Tunnel from a workstation:

```bash
ssh -L 5433:127.0.0.1:5433 ubuntu@15.204.81.231
psql -h 127.0.0.1 -p 5433 -U syndicate_development_2026 \
     -d syndicate_development_2026_staging
```

Or skip the tunnel and go through Kamal:

```bash
bin/kamal accessory exec db -d staging --interactive --reuse \
  "psql -U syndicate_development_2026 syndicate_development_2026_staging"
```

`POSTGRES_USER` is created by initdb as a superuser, which is what lets `db:prepare`
create the databases it needs without a separate `CREATEDB` grant. Data lives in a named
Docker volume rather than a bind mount: a bind mount is created on the host owned by the
SSH user, and initdb — running as uid 999 inside the image — cannot write to it.

### Connection budget

`RAILS_MAX_THREADS` sets both Puma's thread count and the Active Record pool —
`config/database.yml` reads the same variable — so `WEB_CONCURRENCY` × `RAILS_MAX_THREADS`
is the ceiling on connections from the web tier. At 2 × 5 that is 10, against Postgres'
default limit of 100. Raising either knob spends that budget, as does each Solid Queue
process: `config/queue.yml` runs `JOB_THREADS` (default 3) worker threads across
`JOB_CONCURRENCY` (default 1) processes, and `config/database.yml` sizes the `queue` pool
at `JOB_THREADS + 2`, as Solid Queue requires. Both tiers are sized for the 2 vCPU /
3.7 GB OVH box.

---

## The Solid Queue supervisor

Production runs the Solid Queue supervisor inside its Puma process, via
`SOLID_QUEUE_IN_PUMA=true`. It needs one: `config/environments/production.rb` sets
`queue_adapter = :solid_queue`, so without a supervisor every `deliver_later` — admin
password-reset email included — is written to the queue database and never run. No
error, no failed deploy, no email.

Staging must **not** have it. `config/environments/staging.rb` leaves the Active Job
adapter at its default and staging runs a single primary database with no
`solid_queue_*` tables, so the supervisor would die on boot — and Puma's `solid_queue`
plugin answers a dead supervisor by signalling the Puma master, taking staging's whole
web tier down with it, not just its jobs.

Neither failure has a runtime signature, so the arrangement is enforced by
`spec/config/solid_queue_supervisor_spec.rb`, which fails if the deploy config and the
Rails environments disagree. It discovers destinations by glob, so one added later is
checked the day it is added.

The flag is attached to the production web host by a `solid_queue` env tag in
`config/deploy.yml`, never set in the shared `env.clear` block. That is deliberate:
`env.clear` deep-merges into every destination, and a destination can override an
inherited key but **cannot remove one** — so setting the flag once at the top would hand
it to staging, which could then only override the value, never drop the variable. Tags
behave the other way round. Kamal replaces arrays wholesale, so a destination declaring
its own `servers.web` list does not inherit the base's tagged hosts: a new destination
starts with the supervisor **off** and has to opt in by tagging a host, which is the
safe direction to fail.

`config/puma.rb` gates the plugin on the exact string — `ENV["SOLID_QUEUE_IN_PUMA"] ==
"true"` — so a value that is empty or `"false"` cannot start a supervisor. Absence
remains the intended state for a host that should not run one.

**The accepted tradeoff:** running the supervisor inside Puma couples job availability to
web availability. Puma's `solid_queue` plugin monitors the supervisor fork and, if it
dies, issues `Process.kill(:INT, $$)` on the Puma master — so a queue failure takes the
public site down with it. That is backwards in principle for a marketing site, where the
site is the product and email is secondary. It is accepted because a dedicated job host
means paying for a second server to run what is currently only contact-form and
password-reset email, and because Kamal restarts the container on exit, making the
realistic failure mode a restart rather than a sustained outage.

When that stops being acceptable: add a `job:` role under `servers:` with
`cmd: bin/jobs`, tag the job host `solid_queue`, and drop the tag from web. Moving one
tag is the whole change.

---

## Recovery

### The accessory says it booted but nothing is running

`kamal accessory boot db -d staging` **reports success whether or not the container
survives**. It issues `docker run --detach` and does not wait on the result. The
`postgres:16` image refuses to initdb with an empty `POSTGRES_PASSWORD` and exits
immediately — leaving a "booted" accessory that is not running, and an app that then
cannot connect.

An empty password is exactly what a missing `STAGING_DATABASE_PASSWORD` produces, since
an unset variable resolves to an empty string rather than an error.

```bash
bin/kamal accessory details db -d staging     # is it actually up?
bin/kamal accessory logs db -d staging        # initdb's complaint lands here
```

To recover: export the password, then reboot the accessory. If initdb never ran, the
data volume is empty and rebooting is enough. If a partially-initialised volume is in
the way, remove it (`docker volume rm syndicate_development_2026_staging_pgdata` on the
box) and boot again — this destroys staging data, which is acceptable on staging only.

### The admins were not seeded

`db:prepare` seeds **only the databases it created in that same run**. Active Record's
`DatabaseTasks#prepare_all` sets its seed flag from `database_initialized && seeds?` and
calls `load_seed` once at the end, so if seeding raised part-way — an unusable
`ADMIN_SEED_PASSWORD` is the usual cause — the databases already exist on the next
attempt and are not re-seeded.

**Fixing the secret and redeploying does not produce the admin accounts.** Recovery is
manual:

```bash
bin/kamal app exec -d staging --reuse "bin/rails db:seed"
```

with a valid `ADMIN_SEED_PASSWORD` exported in the deploying shell. The seed block runs
only on create, so re-seeding never resets a password an admin has since changed.

The CI pre-flight step exists precisely to keep CI deploys out of this state; on a
workstation there is no such early check and the seed guard is the only backstop.

### A deploy fails with a host-key fingerprint mismatch

The `Pin staging host key` step in `.github/workflows/ci.yml` writes the server's public
host key into the runner's `known_hosts` before the SSH agent is loaded. Kamal leaves
net-ssh's `verify_host_key` unset, which net-ssh maps to a verifier that accepts
whatever key an *unknown* host offers. Every GitHub runner is fresh, so without the pin
every deploy is a first contact and anything answering on `15.204.81.231:22` would
receive `RAILS_MASTER_KEY` and every other deploy secret. With the entry present the
host is not unknown, and a mismatched key raises `HostKeyMismatch` and stops the deploy.

The key is committed rather than stored in a secret because it is a **public** key: the
server presents it to every client. Keeping it visible means the expected value shows up
in review and in `git log` when it changes, and means the pin cannot be silently absent
— an unset secret would write an empty file and drop back to accept-new without failing
anything. It was verified 2026-07-28 two independent ways that agreed: `ssh-keyscan`
over the network, and `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` read on the box
over an already-authenticated session.

A mismatch means either the server was rebuilt — its host key is generated at first
boot — or the connection is being intercepted. **Do not delete or loosen the pin to make
a red build go away.** That restores the exact hole it closes. Rotate deliberately:

1. Get the new key from the server over a channel that is **not** this deploy path — the
   OVH console, or an SSH session whose fingerprint you confirmed there:

   ```bash
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. Confirm it matches what the network reports, from your workstation:

   ```bash
   ssh-keyscan -t ed25519 15.204.81.231 | ssh-keygen -lf -
   ```

   Both must print the same SHA256. **If they disagree, stop** — that is the
   interception case, not a rebuild.

3. Update **both** lines in the `Pin staging host key` step: the `known_hosts` line and
   the `SHA256:` in the guard below it. They are two encodings of one key and must
   agree. The guard is not redundant — a mistyped `known_hosts` entry does not error,
   because net-ssh skips the unparseable line, finds no keys for the host, and quietly
   reverts to accept-new.

4. Commit the rotation on its own, so it is reviewable.

5. If it **was** a rebuild, the client side is gone too. A fresh box has no
   `authorized_keys`, so once the pin is updated the deploy gets past it and then fails
   to authenticate instead. From the OVH console, append the public half of
   `DEPLOY_SSH_PRIVATE_KEY` to `~ubuntu/.ssh/authorized_keys` (mode 600, owned by
   `ubuntu`) before re-running. See
   [Establishing access on a rebuilt or replacement
   server](#establishing-access-on-a-rebuilt-or-replacement-server) for a reused IP with
   a stale host key.

   A rebuild also wipes Docker state, so the next deploy re-provisions the `db` accessory
   from scratch: **staging comes back with an empty database**, not the one it had. Run
   `bin/kamal setup -d staging` rather than `deploy`, or the accessory is never created
   at all.
