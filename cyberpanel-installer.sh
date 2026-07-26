#!/bin/bash

# 1. 禁用交互式提示（避免 apt upgrade 弹出粉红色的 Grub/SSHD 确认框）
export DEBIAN_FRONTEND=noninteractive
sudo -E apt update
sudo -E apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 2. 生成一个16位的安全随机密码 (仅包含大小写字母和数字，避免特殊符号导致面板Bug)
ADMIN_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

# 3. 获取服务器的公网 IP (用于在文本中显示后台登录地址)
SERVER_IP=$(curl -s -m 5 ifconfig.me || curl -s -m 5 icanhazip.com || echo "你的服务器IP")

# 4. 将账号、密码信息保存到当前目录的 info.txt 文件中
cat <<EOF > ./info.txt
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
echo -e "\033[32m [成功] 管理员账号和密码已保存到当前目录的 info.txt \033[0m"
echo -e "=================================================================\n"

# 5. 下载真正的 CyberPanel 安装脚本
wget -O cyberpanel.sh "https://cyberpanel.sh/?dl"
chmod +x cyberpanel.sh

# 6. 启动无人值守安装
# 传入 --version ols 选项和我们刚刚自己生成的 --password 密码，即可跳过所有互动按键
sudo ./cyberpanel.sh --version ols --password "${ADMIN_PASS}"