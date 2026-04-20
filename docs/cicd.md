# CI/CD Pipeline

## Pipeline Flow

| Trigger           | Workflows triggered                                                                 |
| ----------------- | ----------------------------------------------------------------------------------- |
| PR → `develop`    | `pr-validation` + `CI`                                                              |
| PR → `staging`    | `pr-validation` + `CI` + `E2E health gate`                                          |
| PR → `main`       | `pr-validation` + `CI`                                                              |
| merge → `staging` | `CD` → docker build+push (tags: `staging` + SHA) → deploy staging → smoke test     |
| merge → `main`    | `CD` → docker build+push (tags: `latest` + SHA) → manual approval → deploy prod → health check |

## Workflow Files

| File                | Trigger                           | Description                              |
| ------------------- | --------------------------------- | ---------------------------------------- |
| `ci.yml`            | PR → `main`, `staging`, `develop` | Code quality, build, test, security scan |
| `cd.yml`            | Push → `staging`, `main`          | Docker build/push + deployment           |
| `pr-validation.yml` | PR → `main`, `staging`, `develop` | PR title + branch name validation        |
| `e2e-tests.yml`     | PR → `staging`                    | Staging health gate before merge         |

## Jobs Detail

### PR Validation (`pr-validation.yml`)

**`validate-pr-title`** — enforces [Conventional Commits](https://www.conventionalcommits.org/) on PR titles using [`amannn/action-semantic-pull-request@v5`](https://github.com/amannn/action-semantic-pull-request).

Allowed types: `feat`, `fix`, `hotfix`, `chore`, `docs`, `refactor`, `test`, `ci`, `perf`, `build`

**`validate-branch-name`** — enforces branch naming pattern `<type>/<description>`.

Valid types: `feature`, `fix`, `hotfix`, `chore`, `refactor`, `release`, `test`, `ci`

Examples: `feature/add-auth`, `fix/null-order`, `hotfix/prod-crash`

---

### CI (`ci.yml`)

**`code-quality`**
- Runs `dotnet format --verify-no-changes`
- Fails if any file is not correctly formatted

**`build-and-test`** (needs: `code-quality`)
- Builds in `Release` configuration
- Runs all tests with `XPlat Code Coverage`
- Enforces **≥70% line coverage** — fails the build if below threshold
- Uploads HTML coverage report as artifact (7-day retention)
- Posts coverage summary to GitHub Actions job summary

**`security-scan`** (needs: `build-and-test`)
- Runs `dotnet list package --vulnerable --include-transitive`
- Fails if any vulnerable NuGet package is detected

---

### E2E Tests (`e2e-tests.yml`)

Runs on PRs targeting `staging` only.

**`e2e`** — calls `GET $STAGING_URL/health` and expects HTTP `200`. Blocks the merge if staging is unhealthy.

A Playwright scaffold is included (commented out). See [testing.md](./testing.md) for setup.

---

### CD (`cd.yml`)

**`docker-build-push`**
- Builds Docker image using registry layer caching (`buildcache`)
- Pushes to GHCR (`ghcr.io/<owner>/<repo>`)
- Tags: `<sha-7>` always; `staging` on staging branch; `latest` on main branch

**`deploy-staging`** (needs: `docker-build-push`, only on `staging` branch)
- SSH into staging server via `appleboy/ssh-action`
- Pulls the new image, stops/removes the old container, starts the new one
- Container name: `app-staging`, port: `8080`, env file: `/opt/app/.env.staging`
- Smoke test: polls `GET $STAGING_URL/health` — 5 retries × 15s interval

**`deploy-production`** (needs: `docker-build-push`, only on `main` branch)
- Requires manual approval via `environment: production` (configure in GitHub → Settings → Environments)
- SSH deploy to production server
- Container name: `app-prod`, port: `8080`, env file: `/opt/app/.env.prod`
- Health check: polls `GET $PROD_URL/health` for up to 60 seconds

**`notify`** (disabled)
- Slack notification job — uncomment in `cd.yml` when `SLACK_WEBHOOK_URL` secret is configured

## Required GitHub Setup

### Environments

Go to `Settings → Environments` and create:
- `staging`
- `production` — enable **Required reviewers** to gate production deploys

### Secrets

| Secret              | Workflow  | Description                             |
| ------------------- | --------- | --------------------------------------- |
| `STAGING_HOST`      | `cd.yml`  | Staging server hostname or IP           |
| `STAGING_USER`      | `cd.yml`  | SSH username for staging                |
| `STAGING_SSH_KEY`   | `cd.yml`  | Private SSH key for staging             |
| `PROD_HOST`         | `cd.yml`  | Production server hostname or IP        |
| `PROD_USER`         | `cd.yml`  | SSH username for production             |
| `PROD_SSH_KEY`      | `cd.yml`  | Private SSH key for production          |
| `SLACK_WEBHOOK_URL` | `cd.yml`  | Slack webhook (only needed if notify job is enabled) |

> `GITHUB_TOKEN` is provided automatically — no setup needed.

### Variables

| Variable      | Workflow                        | Description                           |
| ------------- | ------------------------------- | ------------------------------------- |
| `STAGING_URL` | `cd.yml`, `e2e-tests.yml`       | Base URL of the staging environment   |
| `PROD_URL`    | `cd.yml`                        | Base URL of the production environment |
