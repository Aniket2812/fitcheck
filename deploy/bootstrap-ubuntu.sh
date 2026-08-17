#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: sudo bash bootstrap-ubuntu.sh <api-domain>" >&2
  exit 64
fi

API_DOMAIN="$1"
APP_ROOT=/opt/youcam2
APP_RELEASE="$APP_ROOT/releases/$(date +%Y%m%d%H%M%S)"
APP_DATA=/var/lib/youcam2
APP_ENV=/etc/youcam2/server.env
APP_NPM_CACHE=/var/cache/youcam2-npm

test -f /tmp/youcam2-server.tgz
test -f /tmp/youcam2-server.env

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg caddy

if ! command -v node >/dev/null || [[ "$(node --version)" != v22.* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

if ! id youcam2 >/dev/null 2>&1; then
  useradd --system --home-dir "$APP_ROOT" --shell /usr/sbin/nologin youcam2
fi

install -d -o youcam2 -g youcam2 \
  "$APP_ROOT" "$APP_RELEASE" "$APP_DATA/media" "$APP_NPM_CACHE"
tar -xzf /tmp/youcam2-server.tgz -C "$APP_RELEASE"
chown -R youcam2:youcam2 "$APP_RELEASE" "$APP_DATA"

cd "$APP_RELEASE"
sudo -u youcam2 env npm_config_cache="$APP_NPM_CACHE" \
  npm ci --omit=dev --no-audit --no-fund
ln -sfn "$APP_RELEASE" "$APP_ROOT/current"

install -d -m 700 /etc/youcam2
install -m 600 /tmp/youcam2-server.env "$APP_ENV"
cat >>"$APP_ENV" <<EOF
NODE_ENV=production
PORT=8787
DATA_FILE=$APP_DATA/users.json
COLLECTIONS_DATA_FILE=$APP_DATA/collections.json
MEDIA_DIR=$APP_DATA/media
SEED_DEMO_DATA=true
EOF

cat >/etc/systemd/system/youcam2.service <<'EOF'
[Unit]
Description=YouCam2 demo API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=youcam2
Group=youcam2
WorkingDirectory=/opt/youcam2/current
EnvironmentFile=/etc/youcam2/server.env
Environment=NODE_OPTIONS=--max-old-space-size=704
ExecStart=/usr/bin/node src/index.js
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/youcam2

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/caddy/Caddyfile <<EOF
$API_DOMAIN {
  encode zstd gzip
  request_body {
    max_size 25MB
  }
  reverse_proxy 127.0.0.1:8787
}
EOF

if ! swapon --show=NAME --noheadings | grep -q '^/swapfile$'; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

systemctl daemon-reload
systemctl enable --now youcam2
systemctl enable --now caddy
systemctl restart youcam2 caddy

for _ in {1..30}; do
  if curl -fsS http://127.0.0.1:8787/health >/dev/null; then
    break
  fi
  sleep 1
done
curl -fsS http://127.0.0.1:8787/health >/dev/null

rm -f /tmp/youcam2-server.tgz /tmp/youcam2-server.env
apt-get clean
