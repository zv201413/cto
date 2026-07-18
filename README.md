# zvps — cto.new 沙盒部署工具

在 cto.new 的 AI business 沙盒中部署 ttyd（Web 终端）+ cloudflared（CF 隧道），用 supervisor 统一管理进程。

## 快速开始

打开 **[index.html](./index.html)**（浏览器直接运行），填入参数 → 点生成 → 把生成的文档贴给 cto.new 的 AI agent 执行。

## 文件说明

| 文件 | 用途 |
|:---|:---|
| `index.html` | **在线生成器**（浏览器打开，填参数 → 复制 → 贴给 agent） |
| `install.sh` | 部署脚本（被生成文档引用） |
| `app.env.example` | 环境变量模板（`__CF_TOKEN__` 等替换为实际值） |
| `kpal-deploy.sh` | 保活脚本模板（可选） |

## 环境变量

| 变量 | 示例 | 说明 |
|:---|:---|:---|
| `TTYD_PORT` | `7681` | ttyd 监听端口，可改为 `80`、`8080` 等 |
| `TTYD_AUTH` | `admin:密码` | ttyd 登录凭据，格式 `用户名:密码` |
| `CF_TOKEN` | `eyJhI...` | Cloudflare Tunnel token，Zero Trust 面板创建 |

## 进程管理

```
supervisorctl status              # 查看所有服务
supervisorctl restart ttyd        # 重启 ttyd
supervisorctl restart cloudflared # 重启 cloudflared
```

新增服务：写 `.conf` 丢进 `/etc/supervisor/conf.d/`，执行 `supervisorctl update`。
