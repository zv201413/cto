# kpal-deploy.sh — 保活脚本，配入 supervisor
# 在沙盒执行以下命令启用：

# cat > /etc/supervisor/conf.d/kpal.conf <<'EOF'
# [program:kpal]
# command=/bin/bash /usr/local/bin/kpal.sh
# autostart=true
# autorestart=true
# EOF

# cat > /usr/local/bin/kpal.sh <<'SHEOF'
# #!/bin/bash
# RANGE=60
# OFFSET=60
# URL="__KPAL_URL__"
# while true; do
#   sleep $((RANDOM % RANGE + OFFSET))
#   curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" >> /tmp/kpal.log 2>&1
# done
# SHEOF
# chmod +x /usr/local/bin/kpal.sh
# supervisorctl update
