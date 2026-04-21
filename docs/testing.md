# Testing

## Chiến lược phân tầng

Pipeline CI tách test thành 3 tầng chạy song song để tối ưu thời gian khi project lớn:

```
code-quality
    ├── unit-tests          (mọi PR — nhanh, không cần infra)
    └── integration-tests   (chỉ PR → staging/main — chậm hơn, cần infra)
            └── security-scan (sau khi cả 2 pass)
```

| Tầng | Filter | Trigger | Thời gian ước tính |
|------|--------|---------|-------------------|
| Unit Tests | `Category=Unit` | Mọi PR | ~2–5 phút |
| Integration Tests | `Category=Integration` | PR → `staging`, `main` | ~5–15 phút |
| E2E | Health gate + Playwright | PR → `staging` | ~2–10 phút |

---

## Đánh tag test

Mọi test **bắt buộc** phải có `[Trait("Category", ...)]` để pipeline filter đúng:

```csharp
// Unit test — không cần DB, không cần network, mock tất cả dependencies
[Trait("Category", "Unit")]
public class TodoServiceTests
{
    [Fact]
    public void GetById_ReturnsNotFound_WhenIdDoesNotExist() { }
}

// Integration test — cần DB thật, HTTP client thật, hoặc external service
[Trait("Category", "Integration")]
public class TodoApiIntegrationTests : IClassFixture<WebApplicationFactory<Program>>
{
    [Fact]
    public async Task GetTodos_Returns200_WithSampleData() { }
}
```

> Test không có `[Trait("Category", ...)]` sẽ không được chạy bởi pipeline. Luôn đánh tag.

---

## Setup test project

Chưa có test project. Tạo theo cấu trúc sau:

```bash
# Unit test project
dotnet new xunit -n JaianX.Api.UnitTests -o tests/JaianX.Api.UnitTests
dotnet sln ci-cd-template.slnx add tests/JaianX.Api.UnitTests/JaianX.Api.UnitTests.csproj
dotnet add tests/JaianX.Api.UnitTests reference JaianX.Api/JaianX.Api.csproj

# Integration test project
dotnet new xunit -n JaianX.Api.IntegrationTests -o tests/JaianX.Api.IntegrationTests
dotnet sln ci-cd-template.slnx add tests/JaianX.Api.IntegrationTests/JaianX.Api.IntegrationTests.csproj
dotnet add tests/JaianX.Api.IntegrationTests reference JaianX.Api/JaianX.Api.csproj
```

Thêm package cho integration tests:

```bash
dotnet add tests/JaianX.Api.IntegrationTests package Microsoft.AspNetCore.Mvc.Testing
```

### Bật parallel execution

Tạo `tests/JaianX.Api.UnitTests/xunit.runner.json`:

```json
{
  "$schema": "https://xunit.net/schema/current/xunit.runner.schema.json",
  "parallelizeAssembly": true,
  "parallelizeTestCollections": true,
  "maxParallelThreads": 0
}
```

> `maxParallelThreads: 0` = dùng tất cả CPU cores. Trên VPS 10GB RAM với nhiều cores, tiết kiệm 30–50% thời gian.

---

## Chạy test locally

```bash
# Tất cả tests
dotnet test

# Chỉ unit tests
dotnet test --filter "Category=Unit"

# Chỉ integration tests
dotnet test --filter "Category=Integration"

# Với coverage
dotnet test --filter "Category=Unit" \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage/unit \
  --maxcpucount
```

---

## Coverage

Pipeline enforces **≥70% line coverage** trên unit tests.

### Xem report locally

```bash
dotnet tool install --global dotnet-reportgenerator-globaltool

dotnet test --filter "Category=Unit" \
  --collect:"XPlat Code Coverage" \
  --results-directory ./coverage/unit

reportgenerator \
  -reports:"./coverage/unit/**/coverage.cobertura.xml" \
  -targetdir:"coveragereport" \
  -reporttypes:"Html"

# Mở coveragereport/index.html
```

### Xem trên GitHub

Sau mỗi PR, pipeline tự động:
- Post comment coverage breakdown trực tiếp lên PR (cập nhật mỗi push)
- Upload HTML report dưới dạng artifact (7 ngày)
- Post summary vào GitHub Actions job summary

---

## Test Results trên GitHub

Pipeline dùng `dorny/test-reporter` để hiển thị từng test case:

- **PR Checks tab** → xem pass/fail từng test
- **PR Files tab** → annotation trực tiếp trên dòng code bị fail
- **Job Summary** → coverage breakdown

---

## Roadmap khi project lớn hơn

### Hiện tại (< 200 tests)
Setup như trên là đủ.

### Khi có 500–1000 tests
Tách integration tests thành job riêng với database service:

```yaml
integration-tests:
  services:
    postgres:
      image: postgres:16
      env:
        POSTGRES_PASSWORD: test
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
```

### Khi có 1000+ tests — Test Sharding
Chia test thành nhiều nhóm chạy song song trên nhiều runner:

```yaml
strategy:
  matrix:
    shard: [1, 2, 3, 4]

steps:
  - name: Run Tests (Shard ${{ matrix.shard }}/4)
    run: |
      dotnet test --filter "Category=Unit" \
        -- RunConfiguration.TestSessionTimeout=300000 \
        xUnit.AppDomain=denied \
        -- NUnit.NumberOfTestWorkers=${{ matrix.shard }}
```

Kết quả: **75% thời gian** với 4 shards song song.

---

## AOT Compatibility

Project dùng `PublishAot=true`. Test projects phải target standard runtime (không phải AOT):

```xml
<!-- tests/JaianX.Api.UnitTests/JaianX.Api.UnitTests.csproj -->
<PropertyGroup>
  <TargetFramework>net10.0</TargetFramework>
  <!-- Không có PublishAot=true ở đây -->
</PropertyGroup>
```

Tránh test AOT-specific behavior trong unit tests — dùng integration tests với container thật cho việc đó.

---

## E2E Tests

`e2e-tests.yml` chạy khi PR → `staging`, hiện tại chỉ có health gate.

Để bật Playwright:

1. Tạo `e2e/` với `package.json` và `playwright.config.ts`
2. Uncomment Playwright steps trong `.github/workflows/e2e-tests.yml`
3. Set `BASE_URL` via `STAGING_URL` GitHub variable

Playwright reporter đã được cấu hình với `--reporter=github` để tạo annotations trên PR.
