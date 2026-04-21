# VPS Setup Guide

Hướng dẫn thiết lập VPS mới từ đầu để sẵn sàng nhận deploy từ CI/CD pipeline. Thực hiện **đúng thứ tự** — mỗi bước phụ thuộc vào bước trước. Sai thứ tự có thể khóa bạn khỏi server.

> Áp dụng cho: **Ubuntu 22.04 / 24.04 LTS**.

---

## Checklist nhanh

- [ ] 1. Cập nhật hệ thống
- [ ] 2. Thiết lập SWAP _(bỏ qua nếu RAM ≥ 8GB)_
- [ ] 3. Tạo user `deploy` với quyền tối thiểu
- [ ] 4. Cấu hình SSH key
- [ ] 5. Hardening SSH
- [ ] 6. Cấu hình Firewall (UFW)
- [ ] 7. Cấu hình Fail2Ban cho SSH port mới
- [ ] 8. Cấu hình múi giờ
- [ ] 9. Cài công cụ cơ bản
- [ ] 10. Bật tự động cập nhật bảo mật
- [ ] 11. Cài Docker
- [ ] 12. Cấu hình GHCR credentials an toàn
- [ ] 13. Cài nginx + reverse proxy
- [ ] 14. Cấu hình SSL (Certbot)
- [ ] 15. Tạo env files với permission đúng
- [ ] 16. Kiểm tra kết nối từ GitHub Actions

---

## 1. Cập nhật hệ thống

Đăng nhập lần đầu bằng `root`:

```bash
ssh root@your-server-ip
```

Cập nhật toàn bộ packages:

```bash
apt update && apt upgrade -y
apt autoremove -y
```

---

## 2. Thiết lập SWAP

Kiểm tra RAM và SWAP hiện tại:

```bash
free -h
swapon --show
```

| RAM VPS | Khuyến nghị |
| ------- | ----------- |
| ≤ 1GB   | Bắt buộc — tạo 2GB swap |
| 2–4GB   | Nên tạo 1–2GB swap |
| ≥ 8GB   | Không cần — bỏ qua bước này |

```bash
# Chỉ thực hiện nếu RAM < 8GB
sudo fallocate -l 2G /swapfile
# Nếu fallocate không hoạt động:
# sudo dd if=/dev/zero of=/swapfile bs=1M count=2048

sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 3. Tạo user `deploy` với quyền tối thiểu

> **Nguyên tắc Least Privilege:** User `deploy` chỉ cần chạy Docker — không cần `sudo`. Cấp `sudo` cho user mà GitHub Actions SSH vào là rủi ro nghiêm trọng: nếu SSH key bị lộ, attacker có full root.

```bash
# Tạo user không có password (chỉ SSH key)
adduser --disabled-password --gecos "" deploy
```

**Không cấp sudo cho `deploy`.** Thay vào đó, chỉ cấp quyền Docker sau khi cài (bước 11).

Kiểm tra user được tạo đúng:

```bash
id deploy
# Kết quả mong đợi: uid=1001(deploy) gid=1001(deploy) groups=1001(deploy)
# KHÔNG được có sudo hoặc wheel trong groups
```

---

## 4. Cấu hình SSH Key

> ⚠️ Hoàn thành bước này **trước** bước 5. Nếu tắt password auth trước khi có SSH key, bạn sẽ bị khóa khỏi server vĩnh viễn.

### Tạo key trên máy local

```bash
# Dùng ed25519 — an toàn hơn RSA, key ngắn hơn
ssh-keygen -t ed25519 -C "deploy-key-$(date +%Y%m%d)" -f ~/.ssh/id_ed25519_deploy
```

> Đặt passphrase cho key nếu dùng trên máy cá nhân. Với GitHub Actions secrets, không cần passphrase.

### Copy public key lên VPS

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_deploy.pub deploy@your-server-ip
```

Hoặc thủ công trên VPS:

```bash
su - deploy
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "your-public-key-content" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
# Đảm bảo owner đúng
chown -R deploy:deploy ~/.ssh
```

### Kiểm tra đăng nhập trước khi tiếp tục

```bash
# Từ máy local — phải thành công trước khi sang bước 5
ssh -i ~/.ssh/id_ed25519_deploy deploy@your-server-ip "echo 'SSH key OK'"
```

### Thêm vào GitHub Secrets

| Secret | Giá trị |
| ------ | ------- |
| `STAGING_SSH_KEY` | Nội dung file `~/.ssh/id_ed25519_deploy` (private key) |
| `PROD_SSH_KEY` | Nội dung file `~/.ssh/id_ed25519_deploy` (production server) |
| `STAGING_USER` | `deploy` |
| `PROD_USER` | `deploy` |
| `STAGING_HOST` | IP hoặc hostname staging server |
| `PROD_HOST` | IP hoặc hostname production server |

> Xem đầy đủ tại [cicd.md](./cicd.md#secrets).

---

## 5. Hardening SSH

> ⚠️ Mở terminal thứ hai giữ session hiện tại trong khi chỉnh sửa. Nếu cấu hình sai và restart SSH, bạn vẫn có session backup để sửa.

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak  # backup trước
sudo nano /etc/ssh/sshd_config
```

Thiết lập các giá trị sau (tìm và sửa từng dòng, không thêm trùng):

```
Port 2288
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
LoginGraceTime 20
AllowUsers deploy
X11Forwarding no
AllowTcpForwarding no
```

> **`AllowUsers deploy`** — chỉ user `deploy` được SSH. Các user khác (kể cả `github-runner`) không thể SSH vào server.

Kiểm tra cú pháp trước khi restart:

```bash
sudo sshd -t
# Không có output = cú pháp đúng
```

Restart SSH:

```bash
sudo systemctl restart ssh
```

**Kiểm tra ngay từ terminal mới** (không đóng terminal cũ):

```bash
ssh -p 2288 -i ~/.ssh/id_ed25519_deploy deploy@your-server-ip "echo 'Hardening OK'"
```

> **Lưu ý cho CI/CD:** Thêm `port: 2288` vào `appleboy/ssh-action` trong `cd.yml`.

---

## 6. Cấu hình Firewall (UFW)

```bash
# Reset về trạng thái mặc định trước
sudo ufw --force reset

# Mặc định: từ chối tất cả inbound, cho phép tất cả outbound
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Cho phép SSH port mới — PHẢI làm trước khi enable
sudo ufw allow 2288/tcp comment 'SSH'

# Web traffic
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Bật firewall
sudo ufw --force enable

# Kiểm tra
sudo ufw status verbose
```

Kết quả mong đợi:

```
Status: active
To                         Action      From
--                         ------      ----
2288/tcp                   ALLOW IN    Anywhere    # SSH
80/tcp                     ALLOW IN    Anywhere    # HTTP
443/tcp                    ALLOW IN    Anywhere    # HTTPS
```

> Port `8080` (app container) **không** mở ra ngoài — nginx proxy nội bộ đến `localhost:8080`.

---

## 7. Cấu hình Fail2Ban cho SSH port mới

Fail2Ban mặc định chỉ monitor port 22. Sau khi đổi sang port 2288, **phải cấu hình lại** — nếu không, brute force vẫn hoạt động trên port mới.

```bash
sudo nano /etc/fail2ban/jail.d/sshd.conf
```

Nội dung:

```ini
[sshd]
enabled  = true
port     = 2288
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
findtime = 600
```

Restart Fail2Ban:

```bash
sudo systemctl restart fail2ban

# Kiểm tra jail đang active đúng port
sudo fail2ban-client status sshd
```

Kết quả mong đợi:

```
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
`- Actions
   |- Currently banned: 0
```

---

## 8. Cấu hình múi giờ

```bash
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
timedatectl
```

---

## 9. Cài công cụ cơ bản

```bash
sudo apt install -y fail2ban htop curl git unzip

# Terminal monitor (tuỳ chọn)
sudo apt install -y btop
```

---

## 10. Tự động cập nhật bảo mật

```bash
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure unattended-upgrades
```

Kiểm tra cấu hình:

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Tùy chọn bật auto reboot lúc 3 giờ sáng (chỉ khi cần patch kernel):

```
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

> Docker container với `--restart unless-stopped` tự khởi động lại sau reboot — an toàn để bật.

---

## 11. Cài Docker

```bash
curl -fsSL https://get.docker.com | sh
```

Cho user `deploy` chạy Docker **không cần sudo**:

```bash
sudo usermod -aG docker deploy
```

> Đây là lý do `deploy` không cần `sudo` — quyền Docker là đủ để pull và run container.

Cài Docker Compose plugin:

```bash
sudo apt install docker-compose-plugin -y
```

Kiểm tra (đăng nhập lại bằng `deploy` để group có hiệu lực):

```bash
su - deploy
docker --version
docker compose version
```

---

## 12. Cấu hình GHCR Credentials an toàn

> ⚠️ **Không dùng PAT cá nhân** lưu plaintext. Nếu server bị compromise, PAT bị lộ → attacker push được image độc hại lên registry.

### Tạo GitHub Fine-grained PAT chỉ đọc

1. GitHub → Settings → Developer settings → Personal access tokens → **Fine-grained tokens**
2. Cấu hình:
   - **Repository access**: chỉ repo này
   - **Permissions**: `Packages` → `Read-only`
   - **Expiration**: 90 ngày (đặt reminder để gia hạn)
3. Copy token

### Lưu credentials an toàn

```bash
# Đăng nhập bằng deploy user
su - deploy

# Login GHCR
echo "YOUR_READONLY_PAT" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Kiểm tra file credentials được tạo
cat ~/.docker/config.json
# Kết quả: {"auths":{"ghcr.io":{"auth":"..."}}}

# Giới hạn quyền đọc file credentials
chmod 600 ~/.docker/config.json
```

### Gia hạn PAT định kỳ

Đặt lịch nhắc 2 tuần trước khi PAT hết hạn để chạy lại lệnh login với token mới. Nếu PAT hết hạn, `docker pull` trong CD pipeline sẽ fail.

---

## 13. Cài nginx + Reverse Proxy

```bash
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

### Cấu hình cho project này

```bash
# Tạo config từ nginx.conf của project
sudo nano /etc/nginx/sites-available/app
```

Nội dung (proxy port 80 → app:8080):

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Ẩn nginx version
    server_tokens off;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }
}
```

> Dùng `127.0.0.1:8080` thay vì `localhost:8080` để tránh IPv6 resolution issues.

```bash
# Kích hoạt config
sudo ln -s /etc/nginx/sites-available/app /etc/nginx/sites-enabled/

# Xoá default site
sudo rm -f /etc/nginx/sites-enabled/default

# Kiểm tra cú pháp
sudo nginx -t

# Reload
sudo systemctl reload nginx
```

---

## 14. Cấu hình SSL (Certbot)

```bash
sudo apt install certbot python3-certbot-nginx -y

# Tạo SSL — thay your-domain.com bằng domain thực
sudo certbot --nginx -d your-domain.com
```

Certbot tự động:
- Lấy certificate từ Let's Encrypt
- Cập nhật nginx config để redirect HTTP → HTTPS
- Cài systemd timer tự gia hạn certificate

Kiểm tra tự gia hạn:

```bash
sudo certbot renew --dry-run
```

Kiểm tra systemd timer:

```bash
sudo systemctl status certbot.timer
```

---

## 15. Tạo env files với permission đúng

Pipeline deploy dùng `--env-file` để inject config vào container. Tạo **trước khi deploy lần đầu**.

```bash
sudo mkdir -p /opt/app
sudo chown deploy:deploy /opt/app
sudo chmod 750 /opt/app
```

### Staging

```bash
su - deploy
nano /opt/app/.env.staging
```

Nội dung mẫu:

```env
ASPNETCORE_ENVIRONMENT=Staging
ASPNETCORE_URLS=http://+:8080
```

**Bắt buộc** — set permission sau khi tạo:

```bash
chmod 600 /opt/app/.env.staging
```

### Production

```bash
nano /opt/app/.env.prod
```

Nội dung mẫu:

```env
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://+:8080
```

```bash
chmod 600 /opt/app/.env.prod
```

Kiểm tra permission:

```bash
ls -la /opt/app/
# Kết quả mong đợi:
# -rw------- 1 deploy deploy ... .env.staging
# -rw------- 1 deploy deploy ... .env.prod
```

> `600` = chỉ owner (`deploy`) đọc/ghi được. Không user nào khác trên server đọc được secrets.

---

## 16. Kiểm tra kết nối từ GitHub Actions

Giả lập chính xác lệnh `appleboy/ssh-action` sẽ chạy:

```bash
ssh -p 2288 \
    -i ~/.ssh/id_ed25519_deploy \
    -o StrictHostKeyChecking=no \
    deploy@your-server-ip \
    "docker --version && docker info > /dev/null && echo 'Pipeline connection OK'"
```

Kết quả mong đợi:

```
Docker version 27.x.x, build ...
Pipeline connection OK
```

Nếu fail, kiểm tra:
1. UFW có allow port 2288 chưa: `sudo ufw status`
2. SSH config có `AllowUsers deploy` chưa: `sudo sshd -T | grep allowusers`
3. User `deploy` có trong group `docker` chưa: `id deploy`

---

## Kiểm tra bảo mật tổng thể

Chạy sau khi hoàn thành tất cả bước:

```bash
# 1. Xác nhận root login bị tắt
ssh -p 2288 root@your-server-ip
# Kết quả mong đợi: Permission denied (publickey)

# 2. Xác nhận password auth bị tắt
ssh -p 2288 -o PreferredAuthentications=password deploy@your-server-ip
# Kết quả mong đợi: Permission denied (publickey)

# 3. Xác nhận port 8080 không public
curl -m 5 http://your-server-ip:8080
# Kết quả mong đợi: Connection refused hoặc timeout

# 4. Xác nhận Fail2Ban đang monitor đúng port
sudo fail2ban-client status sshd | grep "port"
# Kết quả mong đợi: port = 2288

# 5. Xác nhận env files không world-readable
stat -c "%a %n" /opt/app/.env.*
# Kết quả mong đợi: 600 /opt/app/.env.staging, 600 /opt/app/.env.prod
```

---

## Backup cơ bản

| Thành phần | Lệnh |
| ---------- | ---- |
| PostgreSQL | `pg_dump mydb > backup_$(date +%F).sql` |
| MySQL | `mysqldump -u root -p mydb > backup_$(date +%F).sql` |
| File upload | `tar -czf uploads_$(date +%F).tar.gz /opt/app/uploads` |
| `.env` files | Copy thủ công ra ngoài server, lưu encrypted |
| Docker volumes | `docker run --rm -v vol:/data alpine tar -czf - /data > vol_backup.tar.gz` |

> Source code đã có trên GitHub — không cần backup riêng.

---

## Tham khảo

| Tài liệu | Mô tả |
| -------- | ----- |
| [cicd.md](./cicd.md) | Chi tiết pipeline CI/CD, secrets, variables |
| [docker.md](./docker.md) | Docker image, tags, nginx config |
| [health-endpoint.md](./health-endpoint.md) | Thêm `/health` endpoint cho smoke test |
| [setup-self-hosted-runner.md](./setup-self-hosted-runner.md) | Cài GitHub Actions runner trên VPS |
