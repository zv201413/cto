# zvps — 在 cto.new 沙盒部署 ttyd（Web 终端）+ cloudflared（CF 隧道）

把以下步骤逐条粘贴给 cto.new 的 AI agent 执行。

## 步骤 1：创建 app.env

对 agent 说：

```
用 Write file 创建 /home/team/shared/app.env，内容如下（原样写）：
TTYD_PORT=__TTYD_PORT__
TTYD_AUTH=__TTYD_AUTH__
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
command=/usr/local/bin/td -p ${TTYD_PORT} -W -c ${TTYD_AUTH} bash
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
curl -s -u ${TTYD_AUTH} -o /dev/null -w "ttyd: %{http_code}\n" http://127.0.0.1:${TTYD_PORT}/
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
curl -s -u ${TTYD_AUTH} -o /dev/null -w "ttyd: %{http_code}\n" http://127.0.0.1:${TTYD_PORT}/
```

## 环境变量说明

所有变量在 `app.env` 中定义，`install.sh` 自动读取。

| 变量 | 示例 | 说明 |
|:---|:---|:---|
| `TTYD_PORT` | `7681` | ttyd Web 终端监听端口。可改为 `80`、`8080` 等任意可用端口 |
| `TTYD_AUTH` | `admin:mysecret` | ttyd 登录用户名和密码，格式 `用户名:密码`。设为空则不设密码 |
| `CF_TOKEN` | `eyJhI...` | Cloudflare Tunnel token。在 Cloudflare Zero Trust 面板创建隧道后获取 |

端口和密码没有固定值——以上占位符（`__TTYD_PORT__` 等）在部署前替换为实际值即可。

## 文件说明

| 文件 | 用途 |
|:---|:---|
| `install.sh` | 部署脚本（下载 ttyd + cloudflared，安装 supervisor，启动服务） |
| `app.env.example` | 环境变量模板（部署前复制为 `app.env` 并填入实际值） |
| `kpal-deploy.sh` | 保活脚本模板（可选，配入 supervisor 后定时请求防 cto 沙盒休眠） |
| `generate.sh` | 交互式生成器（问答式输入参数，自动生成 deploy.md 直接给 cto agent） |

## 进程管理

```
supervisorctl status              # 查看所有服务状态
supervisorctl restart ttyd        # 重启 ttyd
supervisorctl restart cloudflared # 重启 cloudflared
```

新增服务：写 `.conf` 丢进 `/etc/supervisor/conf.d/`，执行 `supervisorctl update`。
