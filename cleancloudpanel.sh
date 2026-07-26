CloudPanel 系统清理脚本
已从 CyberPanel 适配至 CloudPanel 目录结构 · 请以 root 身份运行

已同步 awk 修复 + Varnish 缓存
cloudpanel-cleanup.sh
复制代码
#!/bin/bash

echo "=================================="
echo "开始自动清理系统与所有网站垃圾..."
echo "=================================="

echo "----------------------------------"
echo "1. 删除全局临时与备份文件"
echo "----------------------------------"
# CloudPanel 使用远程备份，无本地 /home/backup 目录；清理常见临时位置
rm -rf /tmp/clp-backup* 2>/dev/null
rm -rf /tmp/cloudpanel* 2>/dev/null
rm -rf /root/*.tar.gz 2>/dev/null
rm -rf /usr/local/*.tar.gz 2>/dev/null

echo "----------------------------------"
echo "2. 自动遍历清理 (包含主站与所有子域名)"
echo "----------------------------------"
# CloudPanel 站点结构: /home/$siteUser/htdocs/$domainName/$rootDirectory/
# rootDirectory 默认为域名本身，WordPress 核心文件位于该子目录内
for site_user_dir in /home/*; do
    user=$(basename "$site_user_dir")

    # 跳过 CloudPanel 系统用户 clp（其 home 含面板程序本体，严禁清理）
    [ "$user" = "clp" ] && continue

    # 检查是否为站点用户（存在 htdocs 目录）
    if [ -d "$site_user_dir/htdocs" ]; then
        for domain_dir in "$site_user_dir"/htdocs/*/; do
            [ -d "$domain_dir" ] || continue
            domain=$(basename "$domain_dir")
            echo "正在清理域及其子域: $domain"

            # 清理站点日志和临时文件 (CloudPanel 每域名独立 logs/ 与 tmp/)
            rm -rf "$domain_dir/logs/"* 2>/dev/null
            rm -rf "$domain_dir/tmp/"* 2>/dev/null
            rm -rf "$domain_dir/backup/"* 2>/dev/null

            # 清理 WordPress 升级临时目录
            find "$domain_dir" -maxdepth 5 -type d -path "*/wp-content/upgrade" -exec rm -rf {} + 2>/dev/null
            find "$domain_dir" -maxdepth 5 -type d -name "upgrade-temp-backup" -exec rm -rf {} + 2>/dev/null
            find "$domain_dir" -maxdepth 5 -type d -path "*/shopwowa.com/upgrade" -exec rm -rf {} + 2>/dev/null

            # 清理 Webtoffee 插件临时目录
            find "$domain_dir" -maxdepth 5 -type d -name "webtoffee_iew_log" -exec rm -rf {} + 2>/dev/null
            find "$domain_dir" -maxdepth 5 -type d -name "webtoffee_import" -exec rm -rf {} + 2>/dev/null

            # 定位 WordPress 根目录，清理说明文件、默认主页及示例配置文件
            find "$domain_dir" -maxdepth 5 -type f -name "wp-config.php" | while read -r wp_config; do
                wp_root=$(dirname "$wp_config")
                rm -f "$wp_root/index.html" "$wp_root/readme.html" "$wp_root/license.txt" "$wp_root/wp-config-sample.php" "$wp_root/.htaccess.bk"
            done
        done
    fi
done

echo "----------------------------------"
echo "3. 删除系统更新缓存 (自动确认)"
echo "----------------------------------"
export DEBIAN_FRONTEND=noninteractive
apt-get autoclean -y
apt-get clean -y
apt-get autoremove -y --purge

echo "----------------------------------"
echo "4. 删除 NGINX & PageSpeed & Varnish 缓存"
echo "----------------------------------"
# NGINX FastCGI / Proxy 缓存
rm -rf /var/cache/nginx/* 2>/dev/null
# Google PageSpeed 缓存 (CloudPanel 自带该模块)
rm -rf /var/cache/ngx_pagespeed/* 2>/dev/null
rm -rf /var/cache/pagespeed/* 2>/dev/null
# NGINX 全局日志 (用 truncate 避免文件句柄问题)
find /var/log/nginx/ -type f -exec truncate -s 0 {} \; 2>/dev/null
# CloudPanel 面板自身日志
rm -rf /var/log/cloudpanel/* 2>/dev/null
find /home/clp/logs/ -type f -mtime +3 -delete 2>/dev/null

# 清理 Varnish 缓存 (如已启用 — 需先停服务再清存储，避免文件锁定)
systemctl stop varnish 2>/dev/null
rm -rf /var/lib/varnish/* 2>/dev/null
systemctl start varnish 2>/dev/null

# 清理 PHP-FPM 旧会话文件 (7天以上)
find /var/lib/php/sessions/ -type f -mtime +7 -delete 2>/dev/null
find /var/run/php/ -type f -name "sess_*" -mtime +7 -delete 2>/dev/null
find /tmp/ -type f -name "sess_*" -mtime +7 -delete 2>/dev/null

# 重载 NGINX 以释放已删除日志的文件句柄
systemctl reload nginx 2>/dev/null

echo "----------------------------------"
echo "5. 删除时钟同步的日志文件"
echo "----------------------------------"
journalctl --vacuum-time=3d

echo "----------------------------------"
echo "6. 显示系统环境"
echo "----------------------------------"
# CloudPanel 无 CyberPanel 的 MOTD，改用标准 Linux 命令直接输出
echo "当前服务器时间     $(date '+%Y-%m-%d %H:%M:%S')"
echo "当前系统负载        $(uptime | awk -F'load average:' '{print $2}')"

# 先将 awk 结果存入变量，避免 echo 双引号内的嵌套转义问题
cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{printf "%.1f", $2 + $4}')
echo "当前CPU使用率       ${cpu_usage}%"

mem_usage=$(free | awk '/Mem/{printf "%.1f", $3/$2*100}')
echo "当前内存使用率      ${mem_usage}%"

echo "当前磁盘使用率      $(df -h / | awk 'NR==2{print $5}')"
echo "系统连续运行        $(uptime -p | sed 's/up //')"

echo "=================================="
echo "系统清理完成！"
echo "=================================="