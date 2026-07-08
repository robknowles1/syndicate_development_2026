# Deployment Strategy

> Environment tiers, promotion flow, secrets, migrations, and rollback.
> Read when: deploying applications, configuring environments, or planning rollback strategies.

### 1.1 Environment Tiers

Every project operates across environment tiers. Each tier has a distinct purpose and lifecycle.

| Tier | Purpose | Count | Lifecycle |
|------|---------|-------|-----------|
| **Production** | Live application | 1 per project | Permanent |
| **Staging** | Replica of production for final validation | 1 per project | Permanent |
| **Review** | Ephemeral per-PR environment for QA | 0-N per project | Ephemeral (hours to days) |

Rules:
- Staging is an **exact infrastructure replica** of production. The only differences are the domain name, the database, and environment variable values.
- Staging **never** connects to a production database.
- Review environments get their own isolated database (snapshot of staging).

### 1.2 Environment Promotion Flow

```
Developer Branch
  │
  ├─ Pull Request opened → lint + test (CI only, no deploy)
  │
  ├─ Merge to main → lint + test → auto-deploy to STAGING
  │
  └─ Manual trigger → deploy to PRODUCTION (requires explicit approval)
```

Rules:
- Staging deploys are automatic on merge to main.
- Production deploys are manual and require explicit approval.
- The same Docker image (same SHA tag) is promoted from staging to production. Images are never rebuilt for production.

### 1.3 Secrets Strategy

| Level | What Lives Here | Used By |
|-------|----------------|---------|
| Infrastructure secrets | Database URLs, API keys that rarely change | Production, Staging |
| Deployment configuration | Non-secret config, feature flags | All tiers |

Rules:
- Secrets are injected via environment variables, never hardcoded.
- Secrets are never committed to the repository in any form.
- `.env.example` files document all required environment variables without real values.
- Use OIDC or a secrets manager for CI authentication where possible.

### 1.4 Database Migration Strategy

Rules:
- Migrations run before the application starts accepting traffic.
- Destructive migrations (dropping columns, tables) must be deployed in two phases: first deploy removes the code reference, second deploy runs the destructive migration.
- **Never** run `db:rollback` in production. Write a new reverse migration and deploy forward.

### 1.5 Rollback Strategy

- **Immediate rollback**: Re-deploy the previous known image tag or commit SHA.
- **Database rollback**: Write a new reverse migration. Never destructively roll back in production.

### 1.6 CI/CD Hard Rules

- The same artifact (image/bundle) deployed to staging is promoted to production — no rebuilds.
- Production deploys require manual approval.
- Staging deploys are automatic on merge to main.
- All CI must pass before any deploy proceeds.
