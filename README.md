# CI/CD Pipeline Template (.NET 10)

> A standardized CI/CD template for .NET 10 projects using GitHub Actions. This repository provides a reusable baseline for build, test, code quality checks, Docker packaging, and staged deployment across development, UAT, and production.

---

## Pipeline Architecture

### Flow

| Trigger              | Workflows                                          |
| -------------------- | -------------------------------------------------- |
| PR → `develop`       | `pr-validation` + `CI`                             |
| PR → `staging`       | `pr-validation` + `CI` + `E2E health gate`         |
| PR → `main`          | `pr-validation` + `CI`                             |
| merge → `staging`    | `CD` → `docker build+push` (tag: `staging` + SHA) → `deploy-staging` → smoke test (5 retries, 15s interval) |
| merge → `main`       | `CD` → `docker build+push` (tag: `latest` + SHA) → `[manual approval]` → `deploy-production` → health check (60s timeout) |

---

## Branches Strategy

| Branch    | Purpose                                      |
| --------- | -------------------------------------------- |
| `main`    | Production-ready code, protected             |
| `staging` | Pre-production / UAT environment             |
| `develop` | Active development integration branch        |

---

## Workflow Files

| File                  | Trigger                              | Description                              |
| --------------------- | ------------------------------------ | ---------------------------------------- |
| `ci.yml`              | PR → `main`, `staging`, `develop`    | Code quality, build, test, security scan |
| `cd.yml`              | Push → `staging`, `main`             | Docker build/push + deployment           |
| `pr-validation.yml`   | PR → `main`, `staging`, `develop`    | PR title + branch name validation        |
| `e2e-tests.yml`       | PR → `staging`                       | Staging health gate before merge         |

---

## Job Summary

| Job                  | Workflow          | Depends On                          | Description                                                                    |
| -------------------- | ----------------- | ----------------------------------- | ------------------------------------------------------------------------------ |
| `validate-pr-title`  | PR Validation     | —                                   | Enforce Conventional Commits format on PR title                                |
| `validate-branch-name` | PR Validation   | —                                   | Enforce branch naming: `<type>/<description>` (e.g. `feature/add-auth`)       |
| `e2e`                | E2E Tests         | —                                   | Verify staging `/health` returns 200 before merge (PR → `staging` only)        |
| `code-quality`       | CI                | —                                   | `dotnet format --verify-no-changes` (format check)                             |
| `build-and-test`     | CI                | `code-quality`                      | Build (Release), run tests, enforce ≥70% line coverage, upload HTML report     |
| `security-scan`      | CI                | `build-and-test`                    | `dotnet list package --vulnerable --include-transitive`                        |
| `docker-build-push`  | CD                | —                                   | Build & push to GHCR; tags: SHA-7 + `staging` (on staging) or `latest` (on main) |
| `deploy-staging`     | CD                | `docker-build-push`                 | SSH deploy to staging, smoke test `/health` (5 retries × 15s)                 |
| `deploy-production`  | CD                | `docker-build-push` + manual approval | SSH deploy to production, health check loop (60s timeout)                   |

> **Note:** The `notify` (Slack) job is currently disabled. Uncomment it in `cd.yml` when `SLACK_WEBHOOK_URL` is configured.

---

## PR Validation Rules

### PR Title — Conventional Commits

Enforced by [`amannn/action-semantic-pull-request`](https://github.com/amannn/action-semantic-pull-request).

Allowed types: `feat`, `fix`, `hotfix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`, `build`

Examples: `feat: add user authentication`, `fix: handle null reference in order service`

### Branch Naming Convention

Pattern: `<type>/<description>`

Valid types: `feature`, `fix`, `hotfix`, `chore`, `refactor`, `release`, `test`, `ci`

Examples: `feature/add-auth`, `fix/null-order`, `hotfix/prod-crash`

---

## Coverage Threshold

The `build-and-test` job enforces a minimum **70% line coverage**. The pipeline fails if coverage drops below this threshold. An HTML report is uploaded as a build artifact (retained 7 days) and a summary is posted to the GitHub Actions job summary.

---

## Docker Image Tags

Images are pushed to **GitHub Container Registry (GHCR)** at `ghcr.io/<owner>/<repo>`.

| Branch    | Tags applied                  |
| --------- | ----------------------------- |
| `staging` | `<sha-7>`, `staging`          |
| `main`    | `<sha-7>`, `latest`           |

Registry layer caching (`buildcache`) is enabled to speed up subsequent builds.

---

## Manual Setup on GitHub

### Environments

Go to `Settings → Environments` and create:
- `staging`
- `production` — enable **Required reviewers** to gate production deploys

### Secrets

| Secret             | Used by            | Description                        |
| ------------------ | ------------------ | ---------------------------------- |
| `STAGING_HOST`     | `cd.yml`           | Staging server hostname/IP         |
| `STAGING_USER`     | `cd.yml`           | SSH username for staging           |
| `STAGING_SSH_KEY`  | `cd.yml`           | Private SSH key for staging        |
| `PROD_HOST`        | `cd.yml`           | Production server hostname/IP      |
| `PROD_USER`        | `cd.yml`           | SSH username for production        |
| `PROD_SSH_KEY`     | `cd.yml`           | Private SSH key for production     |
| `SLACK_WEBHOOK_URL`| `cd.yml` (disabled)| Slack webhook for deploy notifications |

> `GITHUB_TOKEN` is provided automatically by GitHub Actions — no manual setup needed.

### Variables

| Variable       | Used by       | Description                          |
| -------------- | ------------- | ------------------------------------ |
| `STAGING_URL`  | `cd.yml`, `e2e-tests.yml` | Base URL of the staging environment |
| `PROD_URL`     | `cd.yml`      | Base URL of the production environment |

### Dockerfile

Replace `YourApp` with the actual project name in `Dockerfile`.

---

## E2E Tests

The `e2e-tests.yml` workflow runs on every PR targeting `staging`. It currently performs a **health gate** — verifying that the staging environment returns HTTP 200 on `/health` before allowing the merge.

A Playwright integration is scaffolded in the file (commented out). To enable full E2E tests:

1. Create an `e2e/` folder with a `package.json` and Playwright config.
2. Uncomment the Playwright steps in `e2e-tests.yml`.
3. Set `BASE_URL` via the `STAGING_URL` variable.

---

## Documentation

| Doc | Description |
| --- | ----------- |
| [docs/getting-started.md](docs/getting-started.md) | Local setup, project structure, running the API |
| [docs/architecture.md](docs/architecture.md) | Tech stack, data model, AOT notes, deployment topology |
| [docs/cicd.md](docs/cicd.md) | Full CI/CD pipeline reference |
| [docs/docker.md](docs/docker.md) | Docker build, image tags, nginx, AOT notes |
| [docs/health-endpoint.md](docs/health-endpoint.md) | How to add the `/health` endpoint required by the pipeline |
| [docs/testing.md](docs/testing.md) | Coverage setup, test project scaffold, E2E |
| [docs/setup-vps.md](docs/setup-vps.md) | VPS setup guide — từng bước từ đầu |
| [docs/setup-self-hosted-runner.md](docs/setup-self-hosted-runner.md) | Self-hosted runner — tiết kiệm ~990 phút GitHub Actions/tháng |
