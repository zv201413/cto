# zvps — 在 cto.new 沙盒部署 ttyd + cloudflared（supervisor 管理）

把以下步骤逐条粘贴给 cto.new 的 AI agent 执行。

## 步骤 1：创建 app.env

对 agent 说：

```
用 Write file 创建 /home/team/shared/app.env，内容如下（原样写）：
TTYD_PORT=7681
TTYD_AUTH=ttyd:ttyd123
CF_TOKEN=__CF_TOKEN__
```

## 步骤 2：创建 install.sh

对 agent 说：

```
用 Write file 创建 /home/team/shared/install.sh，内容如下（整段原样写）：

#!/usr/bin/env bash
set -e
cd /home/team/shared
source /home/team/shared/app.env 2>/dev/null || true
TTYD_VERSION="1.7.7"
ARGO_VERSION="2026.3.0"
[ -x /usr/local/bin/td ] || { curl -sSL -o /usr/local/bin/td https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/ttyd.x86_64 && chmod +x /usr/local/bin/td; }
[ -x /usr/local/bin/cf ] || { curl -sSL -o /usr/local/bin/cf https://github.com/cloudflare/cloudflared/releases/download/$ARGO_VERSION/cloudflared-linux-amd64 && chmod +x /usr/local/bin/cf; }
pip install --break-system-packages supervisor 2>/dev/null || true
mkdir -p /etc/supervisor/conf.d /var/log/supervisor
cat > /etc/supervisor/conf.d/ttyd.conf <<'EOF'
[program:ttyd]
command=/usr/local/bin/td -p 7681 -W -c ttyd:ttyd123 bash
autostart=true
autorestart=true
EOF
cat > /usr/local/bin/start-cloudflared.sh <<'SEOF'
#!/bin/bash
source /home/team/shared/app.env 2>/dev/null || true
exec /usr/local/bin/cf tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${CF_TOKEN}"
SEOF
chmod +x /usr/local/bin/start-cloudflared.sh
cat > /etc/supervisor/conf.d/cloudflared.conf <<'EOF'
[program:cloudflared]
command=/usr/local/bin/start-cloudflared.sh
autostart=true
autorestart=true
EOF
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
curl -s -u ttyd:ttyd123 -o /dev/null -w "ttyd: %{http_code}\n" http://127.0.0.1:7681/
```

## 步骤 3：执行

对 agent 说：

```
bash /home/team/shared/install.sh
```

## 步骤 4：验证

对 agent 说：

```
supervisorctl status
curl -s -u ttyd:ttyd123 -o /dev/null -w "ttyd: %{http_code}\n" http://127.0.0.1:7681/
```

## 文件说明

| 文件 | 用途 |
|:---|:---|
| `install.sh` | 部署脚本 |
| `app.env.example` | 环境变量模板（复制为 `app.env`，填 `CF_TOKEN`） |
| `kpal-deploy.sh` | 保活脚本（可选，配入 supervisor） |

## 进程管理

```
supervisorctl status         # 查看所有服务状态
supervisorctl restart ttyd   # 重启 ttyd
```

新增服务：写 `.conf` 丢进 `/etc/supervisor/conf.d/`，执行 `supervisorctl update`。
