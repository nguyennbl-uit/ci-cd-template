# Self-Hosted GitHub Actions Runner

## Tổng quan

CI jobs (`code-quality`, `build-and-test`, `security-scan`) và PR validation chạy trên self-hosted runner để tiết kiệm ~1,122 phút GitHub Actions/tháng. CD jobs giữ nguyên GitHub-hosted vì VPS có public IP — SSH từ cloud vào được bình thường.

| Job | Workflow | Runner | Tiết kiệm |
|-----|----------|--------|-----------|
| `validate-pr-title` | pr-validation | self-hosted | ~66 phút/tháng |
| `validate-branch-name` | pr-validation | self-hosted | ~66 phút/tháng |
| `code-quality` | CI | self-hosted | ~132 phút/tháng |
| `build-and-test` | CI | self-hosted | ~660 phút/tháng |
| `security-scan` | CI | self-hosted | ~198 phút/tháng |
| `docker-build-push` | CD | ubuntu-latest | Tránh CPU spike production |
| `deploy-staging` | CD | ubuntu-latest | VPS public IP, SSH OK |
| `deploy-production` | CD | ubuntu-latest | VPS public IP, SSH OK |
| `e2e` | e2e-tests | ubuntu-latest | Chỉ curl, ~1 phút |
| **Tổng tiết kiệm** | | | **~1,122 phút/tháng (89% quota)** |

---

## Yêu cầu bảo mật

Trước khi cài runner, đọc kỹ các ràng buộc sau:

**1. Chỉ dùng cho private repository**

Runner thực thi code trực tiếp từ PR trên VPS. Với public repo, bất kỳ ai cũng có thể tạo PR chứa malicious code và chạy trên server của bạn. Nếu repo là public, xem phần [Bảo vệ cho public repo](#bảo-vệ-cho-public-repo) bên dưới.

**2. Runner KHÔNG được chạy bằng root**

Runner chạy bằng root có thể bị exploit để chiếm toàn bộ server. Luôn dùng user riêng biệt.

**3. Runner KHÔNG cần quyền sudo**

CI jobs chỉ cần build/test .NET — không cần quyền hệ thống. Không cấp sudo cho user runner.

**4. Runner KHÔNG cần quyền Docker**

CI jobs không build Docker image — chỉ `dotnet build`, `dotnet test`, `dotnet format`. Không thêm runner user vào group `docker`.

---

## 1. Tạo user `github-runner`

User riêng biệt, tách hoàn toàn với `deploy`:

```bash
# Tạo user không có password, không có home directory đặc biệt
sudo adduser --disabled-password --gecos "" github-runner
```

Kiểm tra user không có quyền nguy hiểm:

```bash
id github-runner
# Kết quả mong đợi: uid=1002(github-runner) gid=1002(github-runner) groups=1002(github-runner)
# KHÔNG được có: sudo, wheel, docker trong groups
```

---

## 2. Cài .NET SDK trên VPS

Runner cần .NET SDK để chạy `dotnet build`, `dotnet test`, `dotnet format`.

```bash
# Thêm Microsoft package repository
wget https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
     -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Cài .NET SDK 10
sudo apt update
sudo apt install -y dotnet-sdk-10.0
```

Kiểm tra:

```bash
dotnet --version
# Kết quả mong đợi: 10.0.xxx
```

---

## 3. Lấy Registration Token từ GitHub

Vào: `GitHub repo → Settings → Actions → Runners → New self-hosted runner`

Chọn:
- OS: **Linux**
- Architecture: **x64**

Sao chép token từ bước `Configure`. Token có dạng `AXXXXXXXXXXXXXXXXXXXXXXXXX` và **hết hạn sau 1 giờ** — cài ngay sau khi lấy.

---

## 4. Tải và verify Runner Binary

```bash
sudo su - github-runner
mkdir -p ~/actions-runner && cd ~/actions-runner

# Kiểm tra version mới nhất tại: https://github.com/actions/runner/releases
RUNNER_VERSION="2.317.0"

# Tải runner
curl -fsSL -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
```

**Verify SHA256 checksum trước khi giải nén** — bảo vệ khỏi MITM attack hoặc file bị corrupt:

```bash
# Tải file checksum chính thức từ GitHub release
curl -fsSL -o checksums.txt \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz.sha256"

# Verify
sha256sum -c checksums.txt
# Kết quả mong đợi: actions-runner-linux-x64-2.317.0.tar.gz: OK
# Nếu FAILED → dừng lại, không giải nén
```

Giải nén sau khi verify thành công:

```bash
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz checksums.txt
```

---

## 5. Đăng ký Runner

```bash
# Vẫn trong ~/actions-runner với user github-runner
./config.sh \
  --url https://github.com/<owner>/<repo> \
  --token <TOKEN_FROM_GITHUB> \
  --name vps-ci-runner \
  --labels self-hosted,linux,x64 \
  --runnergroup Default \
  --work _work \
  --unattended
```

Kiểm tra file cấu hình được tạo:

```bash
cat .runner
# Phải có: gitHubUrl, agentName, poolName
```

---

## 6. Cài như systemd service

Runner phải tự khởi động sau reboot VPS:

```bash
# Thoát về root để cài service
exit  # thoát khỏi github-runner user

sudo /home/github-runner/actions-runner/svc.sh install github-runner
sudo systemctl start actions.runner.*
sudo systemctl enable actions.runner.*
```

Kiểm tra:

```bash
sudo systemctl status "actions.runner.*"
```

Kết quả mong đợi:

```
● actions.runner.<owner>.<repo>.vps-ci-runner.service
     Active: active (running)
```

---

## 7. Xác nhận Runner Online

Vào `GitHub repo → Settings → Actions → Runners` — runner phải hiển thị **Idle** (màu xanh).

Nếu hiển thị **Offline**, kiểm tra:

```bash
sudo journalctl -u "actions.runner.*" -n 50
```

---

## Bảo vệ cho public repo

Nếu repo là public, **bắt buộc** thêm điều kiện sau vào tất cả jobs dùng `self-hosted` trong `ci.yml`:

```yaml
jobs:
  code-quality:
    runs-on: self-hosted
    # Chỉ chạy với PR từ chính repo (không phải fork)
    if: github.event.pull_request.head.repo.full_name == github.repository
```

Điều này ngăn PR từ fork (người ngoài) chạy code trên runner của bạn.

---

## Giới hạn tài nguyên runner (tuỳ chọn)

Nếu muốn ngăn CI jobs ảnh hưởng app đang chạy, giới hạn CPU/RAM cho runner process:

```bash
sudo nano /etc/systemd/system/actions.runner.*.service
```

Thêm vào section `[Service]`:

```ini
CPUQuota=50%
MemoryLimit=4G
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart "actions.runner.*"
```

---

## Cập nhật Runner

GitHub thông báo khi runner cần update. Cách update:

```bash
sudo systemctl stop "actions.runner.*"

sudo su - github-runner
cd ~/actions-runner

# Tải version mới (thay NEW_VERSION)
NEW_VERSION="2.320.0"
curl -fsSL -o actions-runner-linux-x64-${NEW_VERSION}.tar.gz \
  "https://github.com/actions/runner/releases/download/v${NEW_VERSION}/actions-runner-linux-x64-${NEW_VERSION}.tar.gz"

# Verify checksum
curl -fsSL -o checksums.txt \
  "https://github.com/actions/runner/releases/download/v${NEW_VERSION}/actions-runner-linux-x64-${NEW_VERSION}.tar.gz.sha256"
sha256sum -c checksums.txt

# Giải nén (ghi đè binary cũ)
tar xzf ./actions-runner-linux-x64-${NEW_VERSION}.tar.gz
rm actions-runner-linux-x64-${NEW_VERSION}.tar.gz checksums.txt

exit  # về root
sudo systemctl start "actions.runner.*"
```

---

## Gỡ Runner

```bash
sudo systemctl stop "actions.runner.*"

sudo su - github-runner
cd ~/actions-runner

# Lấy remove token tại: GitHub repo → Settings → Actions → Runners → chọn runner → Remove
./config.sh remove --token <REMOVE_TOKEN>

exit
sudo /home/github-runner/actions-runner/svc.sh uninstall github-runner
sudo userdel -r github-runner
```

---

## Tham khảo

| Tài liệu | Mô tả |
|----------|-------|
| [setup-vps.md](./setup-vps.md) | Setup VPS trước khi cài runner |
| [cicd.md](./cicd.md) | Chi tiết toàn bộ pipeline |
