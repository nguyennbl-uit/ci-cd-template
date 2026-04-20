# Architecture

## Overview

This is an **ASP.NET Core Minimal API** built on **.NET 10** with **Native AOT** compilation enabled. It is designed as a lightweight, high-performance HTTP API packaged as a Docker container and deployed via GitHub Actions.

## Technology Stack

| Layer          | Technology                          |
| -------------- | ----------------------------------- |
| Runtime        | .NET 10 (ASP.NET Core)              |
| API style      | Minimal API (`WebApplication.CreateSlimBuilder`) |
| Serialization  | `System.Text.Json` with source generation (`JsonSerializerContext`) |
| OpenAPI        | `Microsoft.AspNetCore.OpenApi` 10.0.0 |
| Compilation    | Native AOT (`PublishAot=true`)      |
| Container      | Docker (multi-stage, `aspnet:10.0`) |
| Reverse proxy  | nginx (port 80 → app:8080)          |
| CI/CD          | GitHub Actions                      |
| Registry       | GitHub Container Registry (GHCR)   |

## Application Entry Point

`Program.cs` uses `WebApplication.CreateSlimBuilder` — a trimmed-down host builder optimized for AOT and minimal overhead. It:

1. Configures JSON serialization with a source-generated `AppJsonSerializerContext`
2. Registers OpenAPI (available in Development only)
3. Maps route groups under `/todos`

## Data Model

```csharp
public record Todo(int Id, string? Title, DateOnly? DueBy = null, bool IsComplete = false);
```

Currently backed by an in-memory array (`sampleTodos`). No database or persistence layer exists yet.

## API Routes

```
GET /todos          → Todo[]
GET /todos/{id}     → Todo | 404
GET /openapi/v1.json → OpenAPI spec (Development only)
```

## AOT Considerations

Native AOT requires all serialized types to be registered at compile time via `[JsonSerializable]`. Any new types added to API responses must be added to `AppJsonSerializerContext`:

```csharp
[JsonSerializable(typeof(Todo[]))]
[JsonSerializable(typeof(MyNewType))]  // add new types here
internal partial class AppJsonSerializerContext : JsonSerializerContext { }
```

Reflection-based libraries are incompatible with AOT. Prefer source generators and compile-time analysis.

## Configuration

| File                            | Environment | Purpose                        |
| ------------------------------- | ----------- | ------------------------------ |
| `appsettings.json`              | All         | Base configuration             |
| `appsettings.Development.json`  | Development | Dev overrides (log levels)     |
| `/opt/app/.env.staging`         | Staging     | Injected via `--env-file` in Docker run |
| `/opt/app/.env.prod`            | Production  | Injected via `--env-file` in Docker run |

> `.env` files on the server are never committed to the repository (enforced by `.gitignore`).

## Deployment Topology

```
Internet
   │
  [nginx :80]
   │  proxy_pass
  [app :8080]   ← Docker container (aspnet:10.0)
```

Both containers are expected to run on the same host, with nginx referencing the app by the Docker service name `app`.
