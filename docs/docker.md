# Docker

## Image

Images are built and pushed to **GitHub Container Registry (GHCR)**:

```
ghcr.io/<owner>/<repo>:<tag>
```

| Branch    | Tags applied         |
| --------- | -------------------- |
| `staging` | `<sha-7>`, `staging` |
| `main`    | `<sha-7>`, `latest`  |

Registry layer caching (`buildcache`) is enabled to speed up subsequent builds.

## Dockerfile Setup

The `Dockerfile` uses a **multi-stage build**:

1. **`build` stage** — restores, compiles, and publishes the app using `mcr.microsoft.com/dotnet/sdk:10.0`
2. **`final` stage** — copies the published output into `mcr.microsoft.com/dotnet/aspnet:10.0`, exposes port `8080`

### ⚠️ Required: Replace Placeholder

The `Dockerfile` currently uses `YourApp` as a placeholder. Replace it with the actual project name before building:

```dockerfile
# Before
RUN dotnet restore "src/YourApp/YourApp.csproj"
RUN dotnet publish "src/YourApp/YourApp.csproj" ...
ENTRYPOINT ["dotnet", "YourApp.dll"]

# After (example for this project)
RUN dotnet restore "JaianX.Api/JaianX.Api.csproj"
RUN dotnet publish "JaianX.Api/JaianX.Api.csproj" ...
ENTRYPOINT ["dotnet", "JaianX.Api.dll"]
```

> Also note: the `Dockerfile` currently copies from `src/` but the project lives at `JaianX.Api/`. Update the `COPY` path accordingly.

## Build & Run Locally

```bash
# Build
docker build -t jaianx-api .

# Run
docker run -p 8080:8080 jaianx-api
```

API is available at `http://localhost:8080`.

## nginx Reverse Proxy

`nginx.conf` is provided for deployments that sit nginx in front of the app container:

- Listens on port `80`
- Proxies all traffic to `http://app:8080`
- Forwards `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto` headers

In a `docker-compose` setup, name the app service `app` to match the upstream config, or update `proxy_pass` accordingly.

## .dockerignore

The following are excluded from the Docker build context to keep images lean:

```
**/bin
**/obj
**/.git
**/tests
README.md
```

## AOT Compilation Note

The project has `<PublishAot>true</PublishAot>` enabled. AOT requires the final Docker image to match the target OS/architecture. The `mcr.microsoft.com/dotnet/aspnet:10.0` base image targets Linux x64, which is compatible with `ubuntu-latest` GitHub Actions runners used in the CD pipeline.
