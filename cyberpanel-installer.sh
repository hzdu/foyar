#!/bin/bash

# 0. 自动清除 sudo 环境变量 (防止误加 sudo 执行时触发 CyberPanel 的 SUDO 报错)
unset SUDO_USER SUDO_COMMAND SUDO_UID SUDO_GID

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[31m[错误] 请先执行 sudo su - 切换到 root 用户再运行！\033[0m"
  exit 1
fi

# 1. 禁用交互式提示（避免 apt upgrade 弹出粉红色的配置确认框）
export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# 2. 生成一个16位的安全随机面板管理员密码 (仅包含大小写字母和数字)
ADMIN_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)

# 3. 获取服务器的公网 IP (用于在文本中显示后台登录地址)
SERVER_IP=$(curl -s -m 5 ifconfig.me || curl -s -m 5 icanhazip.com || echo "你的服务器IP")

# 4. 提前将后台账号、密码信息保存到 /root/info.txt 文件中
INFO_FILE="/root/info.txt"

cat <<EOF > $INFO_FILE
==================================================
        CyberPanel 自动化安装成功记录
==================================================
后台登录地址: https://${SERVER_IP}:8090
管理员用户名: admin
管理员密  码: ${ADMIN_PASS}
==================================================
EOF

echo -e "\n================================================================="
echo -e "\033[32m [成功] 管理员账号和密码已提前保存到 /root/info.txt \033[0m"
echo -e "=================================================================\n"

# 5. 下载真正的 CyberPanel 安装脚本
wget -O cyberpanel.sh "https://cyberpanel.sh/?dl"
chmod +x cyberpanel.sh

# 6. 启动无人值守安装
./cyberpanel.sh --version ols --password "${ADMIN_PASS}"

# 7.【新增】安装完成后，自动读取 MySQL 根密码并追加保存到 info.txt 末尾
if [ -f /etc/cyberpanel/mysqlPassword ]; then
    MYSQL_PASS=$(cat /etc/cyberpanel/mysqlPassword)
    cat <<EOF >> $INFO_FILE

数据库 (MySQL) Root 密码: ${MYSQL_PASS}
==================================================
EOF
    echo -e "\n\033[32m [成功] 已自动读取 MySQL 密码并追加写到 /root/info.txt！ \033[0m\n"
else
    echo -e "\n\033[31m [警告] 未能找到 /etc/cyberpanel/mysqlPassword 文件 \033[0m\n"
fi

# 8. 最后在控制台打出完整凭据
echo -e "\033[36m>>> 以下是你的完整登录信息 (/root/info.txt)： <<<\033[0m"
cat $INFO_FILE