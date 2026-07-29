#!/bin/bash

# 0. 检查是否在纯净的 root 登录环境下运行
if [ "$EUID" -ne 0 ] || [ -n "$SUDO_USER" ]; then
  echo -e "\033[31m[错误] CyberPanel 禁止使用 sudo 直接运行！\033[0m"
  echo -e "请先执行命令 \033[32msudo su -\033[0m 切换到真正的 root 账户，然后再粘贴本脚本。"
  exit 1
fi

# 1. 禁用交互式提示（避免 apt upgrade 弹出粉红色的配置确认框）
export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 2. 生成一个16位的安全随机密码 (仅包含大小写字母和数字)
ADMIN_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

# 3. 获取服务器的公网 IP (用于在文本中显示后台登录地址)
SERVER_IP=$(curl -s -m 5 ifconfig.me || curl -s -m 5 icanhazip.com || echo "你的服务器IP")

# 4. 提前将账号、密码信息保存到 /root/info.txt 文件中
INFO_FILE="/root/info.txt"

cat <<EOF > $INFO_FILE
==================================================
        CyberPanel 自动化安装成功记录
==================================================
后台登录地址: https://${SERVER_IP}:8090
管理员用户名: admin
管理员密  码: ${ADMIN_PASS}
==================================================
提示: 登录后请妥善保管此密码，建议登录面板后自行修改并删除此文件。
EOF

echo -e "\n================================================================="
echo -e "\033[32m [成功] 管理员账号和密码已提前保存到 /root/info.txt \033[0m"
echo -e "=================================================================\n"

# 5. 下载真正的 CyberPanel 安装脚本
wget -O cyberpanel.sh "https://cyberpanel.sh/?dl"
chmod +x cyberpanel.sh

# 6. 启动无人值守安装 (已移除 sudo，直接运行)
./cyberpanel.sh --version ols --password "${ADMIN_PASS}"