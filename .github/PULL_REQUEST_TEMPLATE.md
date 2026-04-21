## Summary

<!-- One or two sentences: What does this PR change? Why is it needed? What problem does it solve or what value does it add? -->

**Jira:** [LERP-XXX](https://3wlog.atlassian.net/browse/LERP-XXX)

## Description

<!-- Optional: Add more context if the Summary isn't enough. Link to related tickets, business requirements, or technical decisions. -->

## Type of Change

- [ ] `feat` — New feature
- [ ] `fix` — Bug fix
- [ ] `hotfix` — Urgent production fix
- [ ] `refactor` — Code refactor (no behavior change)
- [ ] `perf` — Performance improvement
- [ ] `docs` — Documentation only
- [ ] `test` — Adding or updating tests
- [ ] `ci` — CI/CD changes
- [ ] `chore` — Maintenance / build / dependency updates
- [ ] `security` — Security patch

**PR Title should follow Conventional Commits** (e.g. `feat: add user profile endpoint` or `fix(auth): resolve token expiration issue`).

## Architectural Impact

| Area                                      | Changed? | Details                                        |
| ----------------------------------------- | -------- | ---------------------------------------------- |
| Domain / Business logic                   | Yes/No   | <!-- Any rule or behavior changes? -->         |
| Database schema                           | Yes/No   | <!-- Migration required? Script name? -->      |
| External services (Redis, MQ, APIs, etc.) | Yes/No   | <!-- Impact or new integration? -->            |
| Public API contract                       | Yes/No   | <!-- Breaking change? Version bump needed? --> |
| New dependencies                          | Yes/No   | <!-- Package name + version + reason -->       |

## Quality Checklist

- [ ] Branch name follows convention (`feature/`, `bugfix/`, `hotfix/`, etc.)
- [ ] PR title follows Conventional Commits
- [ ] Self-reviewed the code
- [ ] No debug logs, dead code, or unresolved TODOs
- [ ] Follows SOLID, DRY, and coding standards (no magic strings/numbers)
- [ ] `dotnet build` and `dotnet test` pass locally
- [ ] `dotnet format` applied (no formatting drift)
- [ ] Unit tests added/updated and passing
- [ ] Integration/E2E tests verified (if applicable)
- [ ] Error handling and edge cases covered
- [ ] Logging added at critical points
- [ ] Swagger / OpenAPI docs updated (if API changes)
- [ ] No breaking changes, or they are clearly documented with migration steps

## Deployment Notes

- **New environment variables:** None / List them here
- **Database migration:** None / `Apply migration XYZ.sql` (run before/after deploy)
- **Manual steps:** None / Describe any required actions
- **Metrics to monitor:** None / CPU, memory, latency, error rate, specific logs, etc.
- **Rollback plan:** <!-- Brief note if needed -->

## How to Test

<!-- Clear steps so reviewer/QA can verify quickly. Include any prerequisites. -->

1.
2.
3. **Expected result:**

**Test data / sample requests (if applicable):**

```http
POST /api/endpoint
{ ... }
```
