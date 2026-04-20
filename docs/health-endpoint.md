# Health Endpoint

The CI/CD pipeline smoke tests and E2E health gate both call `GET /health` and expect HTTP `200`. This endpoint **does not exist** in the current `Program.cs` and must be added before deploying.

## Add the Health Endpoint

Add the following to `Program.cs` before `app.Run()`:

```csharp
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }))
   .WithName("HealthCheck")
   .ExcludeFromDescription(); // hide from OpenAPI
```

For production-grade health checks (database, external dependencies), use the built-in ASP.NET Core Health Checks middleware instead:

```csharp
// In builder section
builder.Services.AddHealthChecks();
// optionally add checks:
// .AddSqlServer(connectionString)
// .AddRedis(redisConnectionString)

// In app section
app.MapHealthChecks("/health");
```

## Where It Is Used

| Workflow          | Job                  | URL checked                  | Failure behaviour                        |
| ----------------- | -------------------- | ---------------------------- | ---------------------------------------- |
| `e2e-tests.yml`   | `e2e`                | `$STAGING_URL/health`        | Blocks PR merge to `staging`             |
| `cd.yml`          | `deploy-staging`     | `$STAGING_URL/health`        | Fails deploy (5 retries × 15s)           |
| `cd.yml`          | `deploy-production`  | `$PROD_URL/health`           | Fails deploy (60s timeout loop)          |

## Expected Response

The pipeline only checks for HTTP `200`. The response body is not validated, so any `200` response is sufficient.
