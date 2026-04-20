# Getting Started

## Prerequisites

| Tool       | Version   | Notes                          |
| ---------- | --------- | ------------------------------ |
| .NET SDK   | 10.0.100  | Pinned via `global.json`       |
| Docker     | 24+       | Required for container builds  |
| Git        | any       | —                              |

## Clone & Run Locally

```bash
git clone <repo-url>
cd ci-cd-template

dotnet restore
dotnet run --project JaianX.Api
```

The API starts at `http://localhost:5011`. The browser opens automatically at `/todos`.

## Available Endpoints

| Method | Path         | Description              |
| ------ | ------------ | ------------------------ |
| GET    | `/todos`     | List all todos           |
| GET    | `/todos/{id}`| Get a single todo by ID  |
| GET    | `/openapi/v1.json` | OpenAPI spec (Development only) |

> The `/health` endpoint is required by the CI/CD pipeline smoke tests. See [health-endpoint.md](./health-endpoint.md) for setup instructions.

## Project Structure

```
ci-cd-template/
├── JaianX.Api/             # ASP.NET Core Minimal API project
│   ├── Program.cs          # App entry point, routes
│   ├── appsettings.json
│   └── appsettings.Development.json
├── docs/                   # Project documentation
├── .github/workflows/      # CI/CD pipeline definitions
├── Dockerfile              # Multi-stage Docker build
├── nginx.conf              # Reverse proxy config (port 80 → app:8080)
├── global.json             # .NET SDK version pin
└── ci-cd-template.slnx     # Solution file
```

## Running Tests

```bash
dotnet test
```

> No test project exists yet. Add one under `tests/` — the CI pipeline enforces ≥70% line coverage.

## OpenAPI / Swagger

OpenAPI is available only in the `Development` environment:

```
GET http://localhost:5011/openapi/v1.json
```
