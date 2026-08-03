# OVH Staging Server — Access

How to reach the staging box, and how access was established. No secrets are recorded
here; passwords and tokens are deliberately excluded.

**Last verified:** 2026-07-28

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

---

## Current state

Docker is **not installed**, and `ubuntu` is **not** in the `docker` group.

**Do not install Docker by hand, and do not create the group manually.** Both are
handled by `kamal server bootstrap`, which `kamal deploy` invokes automatically: it
tests `docker -v`, and on failure installs Docker, runs `sudo -n usermod -aG docker
"$USER"`, then refreshes the session. Passwordless sudo is already in place, so it
needs nothing from an operator.

The order matters, and getting it wrong is quiet rather than loud. That entire block
runs **only when `docker -v` fails**. Pre-install Docker yourself and Kamal skips the
whole thing — including the group membership — and every subsequent command fails
against the Docker socket instead.

Running `usermod -aG docker ubuntu` before the group exists fails outright, so there is
nothing useful to do here ahead of the first deploy.

---

## Deploy prerequisites

These are enforced by application config, not conventions — the app refuses to start if
they are missing. Each traces to a specific review finding.

- **`ADMIN_SEED_PASSWORD`, 12+ characters, set before the first deploy.**
  `bin/docker-entrypoint` runs `db:prepare` under `bash -e`, and `db/seeds.rb` aborts
  without it. Because that runs before the server starts, a missing value produces a
  **container restart loop** — after the databases have already been created.
- **The `proxy:` block in `config/deploy.yml` must be enabled.** Production sets
  `assume_ssl`, which makes Rails trust proxy headers about HTTPS. With no terminating
  proxy, plaintext requests are read as secure, `force_ssl` stops redirecting, and the
  admin session cookie is marked `Secure` over HTTP — browsers then refuse to send it
  back and **admin login silently fails to persist**.
- **`RESEND_API_KEY` and the Rails master key.** Production and staging refuse to boot
  without them, deliberately: previously a missing key booted clean and failed only when
  a customer submitted the contact form.
- **`STAGING_DATABASE_PASSWORD`** — staging no longer falls back to production's.
- **Host authorization is active.** Any `Host` header not in `config.hosts` gets a 403.
  Production lists `www.syndicate-development.com` and the apex; staging lists
  `staging.syndicate-development.com`. DNS must match one of these.

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
