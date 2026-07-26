#!/bin/bash

echo "=================================="
echo "开始自动清理系统与所有网站垃圾..."
echo "=================================="

echo "----------------------------------"
echo "1. 删除全局备份目录"
echo "----------------------------------"
rm -rf /home/backup/*

echo "----------------------------------"
echo "2. 自动遍历清理 (包含主站与所有子域名)"
echo "----------------------------------"
for site_dir in /home/*; do
    # 这一次，真的是修正了的正确语法（有空格）！
    if [ -d "$site_dir" ] &&[ -d "$site_dir/public_html" ]; then
        domain=$(basename "$site_dir")
        echo "正在清理域及其子域: $domain"

        rm -rf "$site_dir/logs/"*
        rm -rf "$site_dir/backup/"*

        find "$site_dir" -maxdepth 5 -type d -path "*/wp-content/upgrade" -exec rm -rf {} + 2>/dev/null
        find "$site_dir" -maxdepth 5 -type d -name "upgrade-temp-backup" -exec rm -rf {} + 2>/dev/null
        find "$site_dir" -maxdepth 5 -type d -path "*/shopwowa.com/upgrade" -exec rm -rf {} + 2>/dev/null

        find "$site_dir" -maxdepth 5 -type d -name "webtoffee_iew_log" -exec rm -rf {} + 2>/dev/null
        find "$site_dir" -maxdepth 5 -type d -name "webtoffee_import" -exec rm -rf {} + 2>/dev/null

        # 定位 WordPress 根目录，并清理说明文件、默认主页及示例配置文件
        find "$site_dir" -maxdepth 5 -type f -name "wp-config.php" | while read -r wp_config; do
            wp_root=$(dirname "$wp_config")
            rm -f "$wp_root/index.html" "$wp_root/readme.html" "$wp_root/license.txt" "$wp_root/wp-config-sample.php" "$wp_root/.htaccess.bk"
        done
    fi
done

echo "----------------------------------"
echo "3. 删除系统更新缓存 (自动确认)"
echo "----------------------------------"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get autoclean -y
sudo apt-get clean -y
sudo apt-get autoremove -y --purge

echo "----------------------------------"
echo "4. 删除 CyberPanel & Litespeed 缓存"
echo "----------------------------------"
rm -rf /usr/local/lsws/cachedata/*
rm -rf /usr/local/lsws/logs/*
rm -rf /usr/local/*.tar.gz

find /var/lib/lsphp/session/lsphp* -type f -mtime +7 -delete

echo "----------------------------------"
echo "5. 删除时钟同步的日志文件"
echo "----------------------------------"
journalctl --vacuum-time=3d

echo "----------------------------------"
echo "6. 显示系统环境"
echo "----------------------------------"
# 使用 sed 删除不需要的头部欢迎信息，并对齐翻译剩下的系统参数
source /etc/profile | sed \
    -e '/This server has installed CyberPanel/d' \
    -e '/Visit.*https/d' \
    -e '/Forum.*https/d' \
    -e '/Log in.*https/d' \
    -e 's/Current Server time/当前服务器时间     /g' \
    -e 's/Current Load average/当前系统负载        /g' \
    -e 's/Current CPU usage/当前CPU使用率    /g' \
    -e 's/Current RAM usage/当前内存使用率   /g' \
    -e 's/Current Disk usage/当前磁盘使用率    /g' \
    -e 's/System uptime/系统连续运行 /g' \
    -e 's/ days/ 天/g' \
    -e 's/ day/ 天/g' \
    -e 's/ hours/ 小时/g' \
    -e 's/ hour/ 小时/g' \
    -e 's/ minutes/ 分钟/g' \
    -e 's/ minute/ 分钟/g' \
    -e '/Enjoy your accelerated Internet by CyberPanel./d'

echo "=================================="
echo "系统清理完成！"
echo "=================================="