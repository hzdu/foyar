#!/bin/bash

# =========================================================
# CyberPanel Expect 全自动安装脚本
# (含 16位面板随机密码 + 自动读取数据库 root 密码)
# =========================================================

# 1. 检测并安装必要依赖工具 (expect, curl, wget, coreutils)
echo ">>> 正在检测并安装必要的依赖工具..."
if [ -f /etc/debian_version ]; then
    apt-get update -y && apt-get install -y expect curl wget coreutils
elif [ -f /etc/redhat-release ]; then
    yum install -y expect curl wget coreutils
fi

# 2. 生成 16 位安全随机面板密码 (仅包含大小写字母和数字)
ADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)

echo "========================================================="
echo " [提示] 本次自动生成的面板 admin 密码为: $ADMIN_PASS"
echo " (开始进行全自动安装，请稍等...)"
echo "========================================================="
sleep 2

# 3. 使用 expect 自动应答 CyberPanel 官方安装程序
expect <<EOF
set timeout -1
spawn sh -c "curl https://cyberpanel.net/install.sh | sh"

# 1. 选择安装 CyberPanel
expect "*enter the number*"
send "1\r"

# 2. 选择 OpenLiteSpeed 免费版
expect "*enter the number*"
send "1\r"

# 3. 是否安装全套服务 (PowerDNS, Postfix, Pure-FTPd) [Y/n]
expect "*Full installation*"
send "Y\r"

# 4. 是否使用远程 MySQL [y/N]
expect "*Remote MySQL*"
send "N\r"

# 5. 安装 CyberPanel 版本 (按 Enter 键选择最新版本)
expect "*Press Enter key*"
send "\r"

# 6. 选择密码设置模式 [d/r/s] (选择 s 自定义密码)
expect "*Choose*"
send "s\r"

# 7. 输入刚生成的 16 位随机密码
expect "*Please enter custom password*"
send "${ADMIN_PASS}\r"

# 8. 是否安装 Memcached [Y/n]
expect "*Memcached*"
send "Y\r"

# 9. 是否安装 Redis [Y/n]
expect "*Redis*"
send "Y\r"

# 10. 是否安装 WatchDog 监控 [Y/n]
expect "*WatchDog*"
send "Y\r"

expect eof
EOF

# 4. 获取服务器 IP 和数据库 root 密码
SERVER_IP=$(curl -s https://api.ipify.org || echo "你的服务器IP")

# CyberPanel 默认将 MySQL root 密码存在 /etc/cyberpanel/mysqlPassword
if [ -f /etc/cyberpanel/mysqlPassword ]; then
    MYSQL_ROOT_PASS=$(cat /etc/cyberpanel/mysqlPassword)
elif [ -f /root/.my.cnf ]; then
    MYSQL_ROOT_PASS=$(grep -i 'password' /root/.my.cnf | cut -d'=' -f2 | tr -d ' "'"'")
else
    MYSQL_ROOT_PASS="读取失败（请手动执行 cat /etc/cyberpanel/mysqlPassword 查看）"
fi

# 5. 格式化输出安装结果汇总
echo ""
echo "========================================================="
echo "  🎉 CyberPanel 自动安装完成！"
echo "========================================================="
echo "  【面板登录信息】"
echo "  面板地址      : https://${SERVER_IP}:8090"
echo "  管理员账号    : admin"
echo "  管理员密码    : ${ADMIN_PASS}"
echo ""
echo "  【数据库 root 信息】"
echo "  MySQL Root账号: root"
echo "  MySQL Root密码: ${MYSQL_ROOT_PASS}"
echo "========================================================="