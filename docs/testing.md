# Testing

## Coverage Requirement

The CI pipeline enforces a minimum **70% line coverage**. Builds fail if coverage drops below this threshold.

## Running Tests

```bash
dotnet test
```

With coverage collection:

```bash
dotnet test --collect:"XPlat Code Coverage" --results-directory ./coverage
```

## Test Project Setup

No test project exists yet. The solution file (`ci-cd-template.slnx`) has a `tests/` folder reserved for it.

To add a test project:

```bash
dotnet new xunit -n JaianX.Api.Tests -o tests/JaianX.Api.Tests
dotnet sln ci-cd-template.slnx add tests/JaianX.Api.Tests/JaianX.Api.Tests.csproj
```

Reference the API project:

```bash
dotnet add tests/JaianX.Api.Tests reference JaianX.Api/JaianX.Api.csproj
```

## Coverage Report

The CI pipeline generates an HTML coverage report using [ReportGenerator](https://github.com/danielpalme/ReportGenerator):

- Report is uploaded as a GitHub Actions artifact (`coverage-report`), retained for **7 days**
- A markdown summary is posted to the GitHub Actions job summary
- Report types generated: `Html`, `MarkdownSummaryGithub`

To generate the report locally:

```bash
dotnet tool install --global dotnet-reportgenerator-globaltool

dotnet test --collect:"XPlat Code Coverage" --results-directory ./coverage

reportgenerator \
  -reports:"./coverage/**/coverage.cobertura.xml" \
  -targetdir:"coveragereport" \
  -reporttypes:"Html"

# Open coveragereport/index.html in a browser
```

## AOT Compatibility

The project uses Native AOT (`PublishAot=true`). Test projects should target the standard runtime (not AOT) and reference the API project directly. Avoid testing AOT-specific behavior in unit tests — integration tests against the running container are better suited for that.

## E2E Tests

The `e2e-tests.yml` workflow currently performs a **staging health gate** only (HTTP 200 on `/health`).

A Playwright scaffold is included (commented out). To enable full E2E tests:

1. Create `e2e/` with a `package.json` and `playwright.config.ts`
2. Uncomment the Playwright steps in `.github/workflows/e2e-tests.yml`
3. Set `BASE_URL` via the `STAGING_URL` GitHub variable
