# zvps-cto-new

在 cto.new 沙盒中部署 ttyd（Web 终端）+ cloudflared（CF 隧道）的脚本，使用 supervisor 统一管理进程。

## 使用方法

将 `install.sh` 上传到沙盒，执行：

```
bash /home/team/shared/install.sh
```

执行前先在沙盒创建 `/home/team/shared/app.env`，内容参考 `app.env.example`。

## 文件说明

| 文件 | 用途 |
|:---|:---|
| `install.sh` | 一键部署脚本（安装 supervisor、下载 ttyd/cloudflared、启动服务） |
| `app.env.example` | 环境变量模板（复制为 app.env 并填入实际值） |
| `kpal-deploy.sh` | 保活脚本（可选，配入 supervisor 后定时请求防休眠） |

## 环境变量

```
TTYD_PORT=7681
TTYD_AUTH=ttyd:ttyd123
CF_TOKEN=__CF_TOKEN__
```

## 进程管理

```
supervisorctl status       # 查看所有服务状态
supervisorctl restart xxx  # 重启某个服务
```

新增服务：写 `.conf` 丢进 `/etc/supervisor/conf.d/`，执行 `supervisorctl update`。
