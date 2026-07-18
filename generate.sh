#!/usr/bin/env bash
# generate.sh — 交互式生成部署文档，直接给 cto agent
# 用法: bash generate.sh
set -e

OUTPUT="deploy-$(date +%Y%m%d-%H%M).md"

echo "================================"
echo "  zvps 部署文档生成器"
echo "  填入参数，生成 deploy.md"
echo "================================"
echo ""

read -p "CF_TOKEN（Cloudflare Tunnel token，必填）: " CF_TOKEN
[ -z "$CF_TOKEN" ] && { echo "CF_TOKEN 不能为空"; exit 1; }

read -p "TTYD_PORT（ttyd 端口，默认 7681）: " TTYD_PORT
TTYD_PORT=${TTYD_PORT:-7681}

read -p "TTYD_AUTH（ttyd 登录 用户名:密码，必填，如 admin:abc123）: " TTYD_AUTH
[ -z "$TTYD_AUTH" ] && { echo "TTYD_AUTH 不能为空"; exit 1; }

read -p "KPAL（保活，格式 范围:偏移:URL，可选，直接回车跳过）: " KPAL

read -p "KOMARI（一次性安装命令，可选，直接回车跳过）: " KOMARI_CMD

echo ""
echo "正在生成部署文档..."

cat > "$OUTPUT" <<MDEOF
# zvps 部署到 cto.new（执行指令，按顺序做）

## 步骤 1：创建 /home/team/shared/app.env

用 Write file 创建，内容如下：

\`\`\`
TTYD_PORT=${TTYD_PORT}
TTYD_AUTH=${TTYD_AUTH}
CF_TOKEN=${CF_TOKEN}
\`\`\`

## 步骤 2：创建 /home/team/shared/install.sh

用 Write file 创建，内容如下：

\`\`\`
#!/usr/bin/env bash
set -e
cd /home/team/shared
source /home/team/shared/app.env 2>/dev/null || true
TTYD_VERSION="1.7.7"
ARGO_VERSION="2026.3.0"
[ -x /usr/local/bin/td ] || { curl -sSL -o /usr/local/bin/td https://github.com/tsl0922/ttyd/releases/download/\$TTYD_VERSION/ttyd.x86_64 && chmod +x /usr/local/bin/td; }
[ -x /usr/local/bin/cf ] || { curl -sSL -o /usr/local/bin/cf https://github.com/cloudflare/cloudflared/releases/download/\$ARGO_VERSION/cloudflared-linux-amd64 && chmod +x /usr/local/bin/cf; }
pip install --break-system-packages supervisor 2>/dev/null || true
mkdir -p /etc/supervisor/conf.d /var/log/supervisor
cat > /etc/supervisor/conf.d/ttyd.conf <<'EOF'
[program:ttyd]
command=/usr/local/bin/td -p ${TTYD_PORT} -W -c ${TTYD_AUTH} bash
autostart=true
autorestart=true
EOF
cat > /usr/local/bin/start-cloudflared.sh <<'SEOF'
#!/bin/bash
source /home/team/shared/app.env 2>/dev/null || true
exec /usr/local/bin/cf tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "\${CF_TOKEN}"
SEOF
chmod +x /usr/local/bin/start-cloudflared.sh
cat > /etc/supervisor/conf.d/cloudflared.conf <<'EOF'
[program:cloudflared]
command=/usr/local/bin/start-cloudflared.sh
autostart=true
autorestart=true
EOF
MDEOF

if [ -n "$KPAL" ]; then
  KPAL_RANGE=$(echo "$KPAL" | cut -d: -f1)
  KPAL_OFFSET=$(echo "$KPAL" | cut -d: -f2)
  KPAL_URL=$(echo "$KPAL" | cut -d: -f3-)
  KPAL_RANGE=${KPAL_RANGE:-300}
  KPAL_OFFSET=${KPAL_OFFSET:-60}
cat >> "$OUTPUT" <<MDEOF
cat > /etc/supervisor/conf.d/kpal.conf <<'EOF'
[program:kpal]
command=/bin/bash /usr/local/bin/kpal.sh
autostart=true
autorestart=true
EOF
cat > /usr/local/bin/kpal.sh <<'SHEOF'
#!/bin/bash
RANGE=${KPAL_RANGE}
OFFSET=${KPAL_OFFSET}
URL="${KPAL_URL}"
while true; do
  sleep \$((RANDOM % RANGE + OFFSET))
  curl -s -o /dev/null -w "%{http_code}" --max-time 10 "\$URL" >> /tmp/kpal.log 2>&1
done
SHEOF
chmod +x /usr/local/bin/kpal.sh
MDEOF
fi

cat >> "$OUTPUT" <<MDEOF
pkill -f "/usr/local/bin/td" 2>/dev/null || true
pkill -f "/usr/local/bin/cf tunnel" 2>/dev/null || true
if pgrep -f "supervisord" >/dev/null 2>&1; then
  supervisorctl update
else
  cat > /etc/supervisor/supervisord.conf <<'SEOF'
[unix_http_server]
file=/var/run/supervisor.sock
[supervisord]
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
[supervisorctl]
serverurl=unix:///var/run/supervisor.sock
[include]
files = /etc/supervisor/conf.d/*.conf
SEOF
  supervisord -c /etc/supervisor/supervisord.conf &
  sleep 2
fi
sleep 2
curl -s -u ${TTYD_AUTH} -o /dev/null -w "ttyd: %{http_code}\\n" http://127.0.0.1:${TTYD_PORT}/
\`\`\`

MDEOF

if [ -n "$KOMARI_CMD" ]; then
cat >> "$OUTPUT" <<MDEOF
## （可选）安装 komari agent

对 agent 说：

\`\`\`
bash -c '${KOMARI_CMD}'
\`\`\`

MDEOF
fi

cat >> "$OUTPUT" <<MDEOF
## 步骤 3：执行安装

对 agent 说：

\`\`\`
bash /home/team/shared/install.sh
\`\`\`

## 步骤 4：验证

对 agent 说：

\`\`\`
supervisorctl status
curl -s -u ${TTYD_AUTH} -o /dev/null -w "ttyd: %{http_code}\\n" http://127.0.0.1:${TTYD_PORT}/
\`\`\`
MDEOF

echo "================================"
echo "  生成完成: $OUTPUT"
echo "  直接打开并复制全部内容给 cto agent"
echo "================================"
