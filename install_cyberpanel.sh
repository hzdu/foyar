#!/bin/bash
#====================================================
# CyberPanel 全自动安装脚本
# 支持系统：Ubuntu 20.04 / 22.04 / 24.04
# 使用方式：sudo bash cyberpanel_ubuntu.sh
#====================================================

# ========== 配置区域（根据需要修改） ==========
WEB_SERVER="OLS"          # OLS = OpenLiteSpeed(免费), ENT = LiteSpeed Enterprise
FULL_SERVICE="Y"          # Y = 安装全套服务(DNS/Mail/FTP), N = 最小安装
REMOTE_MYSQL="N"          # Y = 使用远程MySQL, N = 本地安装MySQL
ADMIN_PASSWORD="auto"     # "auto"=随机密码, "default"=默认密码1234567, 或填自定义密码
MEMCACHED="Y"             # Y = 安装 Memcached
REDIS="Y"                 # Y = 安装 Redis
WATCHDOG="Y"              # Y = 安装 WatchDog 进程守护
# ==============================================

set -e

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}[STEP]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1 ✓"; }

# ========== 第一步：检查 Root 权限 ==========
check_root() {
    log_step "检查运行权限..."
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限！"
        echo "请使用: sudo bash $0"
        exit 1
    fi
    log_success "Root 权限验证通过"
}

# ========== 第二步：检测 Ubuntu 版本 ==========
detect_ubuntu_version() {
    log_step "检测 Ubuntu 版本..."

    if [ ! -f /etc/os-release ]; then
        log_error "无法检测操作系统，/etc/os-release 不存在！"
        exit 1
    fi

    . /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        log_error "当前系统不是 Ubuntu！检测到: $ID"
        log_error "此脚本仅支持 Ubuntu 20.04 / 22.04 / 24.04"
        exit 1
    fi

    UBUNTU_VERSION="$VERSION_ID"

    case "$UBUNTU_VERSION" in
        "20.04")
            log_success "Ubuntu 20.04 LTS (Focal Fossa) - 完全支持"
            ;;
        "22.04")
            log_success "Ubuntu 22.04 LTS (Jammy Jellyfish) - 完全支持"
            ;;
        "24.04")
            log_success "Ubuntu 24.04 LTS (Noble Numbat) - 完全支持"
            log_info "提示: 请确保 CyberPanel 版本 >= v2.4.5"
            ;;
        *)
            log_error "不支持的 Ubuntu 版本: $UBUNTU_VERSION"
            log_error "本脚本仅支持: 20.04 / 22.04 / 24.04"
            exit 1
            ;;
    esac

    export UBUNTU_VERSION
}

# ========== 第三步：检查系统资源 ==========
check_resources() {
    log_step "检查系统资源..."

    # 检查 RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 1024 ]; then
        log_error "内存不足！当前: ${TOTAL_RAM}MB，最少需要 1024MB"
        exit 1
    elif [ "$TOTAL_RAM" -lt 2048 ]; then
        log_warn "内存 ${TOTAL_RAM}MB，建议至少 2048MB"
    else
        log_success "内存检查通过 (${TOTAL_RAM}MB)"
    fi

    # 检查磁盘
    FREE_DISK=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$FREE_DISK" -lt 10 ]; then
        log_error "磁盘空间不足！当前可用: ${FREE_DISK}GB，最少需要 10GB"
        exit 1
    else
        log_success "磁盘检查通过 (${FREE_DISK}GB 可用)"
    fi

    # 检查 CPU 核心数
    CPU_CORES=$(nproc)
    log_info "CPU 核心数: ${CPU_CORES} 核"
}

# ========== 第四步：检查已安装情况 ==========
check_existing_install() {
    if [ -d "/usr/local/CyberCP" ]; then
        log_warn "检测到已安装的 CyberPanel！"
        echo ""
        read -p "  是否强制重新安装？(y/N): " REINSTALL
        if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
            log_info "已取消安装。"
            exit 0
        fi
        log_warn "将继续重新安装..."
    fi
}

# ========== 第五步：配置防火墙 ==========
configure_firewall() {
    log_step "配置防火墙规则..."

    if command -v ufw &>/dev/null; then
        UFW_STATUS=$(ufw status | head -1)
        if echo "$UFW_STATUS" | grep -q "active"; then
            log_info "UFW 已启用，开放必要端口..."
            ufw allow 8090/tcp comment 'CyberPanel'   # CyberPanel 管理面板
            ufw allow 80/tcp   comment 'HTTP'
            ufw allow 443/tcp  comment 'HTTPS'
            ufw allow 21/tcp   comment 'FTP'
            ufw allow 25/tcp   comment 'SMTP'
            ufw allow 110/tcp  comment 'POP3'
            ufw allow 143/tcp  comment 'IMAP'
            ufw allow 465/tcp  comment 'SMTPS'
            ufw allow 587/tcp  comment 'SMTP Submission'
            ufw allow 993/tcp  comment 'IMAPS'
            ufw allow 995/tcp  comment 'POP3S'
            ufw allow 7080/tcp comment 'WebAdmin'
            ufw allow 40110:40210/tcp comment 'FTP Passive'
            log_success "防火墙端口已开放"
        else
            log_info "UFW 未启用，跳过防火墙配置"
        fi
    else
        log_info "未检测到 UFW，跳过防火墙配置"
    fi
}

# ========== 第六步：更新系统（按版本区分） ==========
update_system() {
    log_step "更新 Ubuntu ${UBUNTU_VERSION} 系统包..."

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y

    # Ubuntu 24.04 使用更严格的升级方式
    if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
        apt-get upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold"
    else
        apt-get upgrade -y
    fi

    # 安装通用依赖
    apt-get install -y \
        curl \
        wget \
        git \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release

    log_success "系统更新完成"
}

# ========== 第七步：Ubuntu 24.04 额外处理 ==========
prepare_ubuntu_24() {
    if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
        return 0
    fi

    log_step "Ubuntu 24.04 专项准备..."

    # 安装 Python 3.10 兼容库（CyberPanel 依赖）
    log_info "安装 Python 依赖..."
    apt-get install -y python3 python3-pip python3-venv python3-dev || true

    # 安装 libmysqlclient-dev（Ubuntu 24.04 替换了 libmariadbclient-dev）
    log_info "安装数据库开发库..."
    apt-get install -y \
        libmysqlclient-dev \
        default-libmysqlclient-dev \
        libssl-dev \
        libffi-dev || true

    log_success "Ubuntu 24.04 专项准备完成"
}

# ========== 第八步：构建自动应答 ==========
build_answers() {
    log_step "构建自动安装应答参数..."

    ANSWER_LIST=""

    # Q: 选择操作 -> 1: 安装 CyberPanel
    ANSWER_LIST+="1\n"

    # Q: 选择 Web 服务器
    if [[ "$WEB_SERVER" == "ENT" ]]; then
        ANSWER_LIST+="2\n"       # LiteSpeed Enterprise
        ANSWER_LIST+="TRIAL\n"   # 试用 License
    else
        ANSWER_LIST+="1\n"       # OpenLiteSpeed（免费）
    fi

    # Q: 是否安装完整服务（PowerDNS + Postfix + Pure-FTPd）
    ANSWER_LIST+="${FULL_SERVICE}\n"

    # Q: 是否使用远程 MySQL
    ANSWER_LIST+="${REMOTE_MYSQL}\n"

    # Q: 安装版本（回车 = 最新版）
    ANSWER_LIST+="\n"

    # Q: 管理员密码
    case "$ADMIN_PASSWORD" in
        "auto"|"random")
            ANSWER_LIST+="r\n"   # 随机生成密码
            ;;
        "default"|"1234567")
            ANSWER_LIST+="d\n"   # 使用默认密码 1234567
            ;;
        *)
            ANSWER_LIST+="s\n"               # 设置自定义密码
            ANSWER_LIST+="${ADMIN_PASSWORD}\n"
            ;;
    esac

    # Q: 是否安装 Memcached
    ANSWER_LIST+="${MEMCACHED}\n"

    # Q: 是否安装 Redis
    ANSWER_LIST+="${REDIS}\n"

    # Q: 是否安装 WatchDog
    ANSWER_LIST+="${WATCHDOG}\n"

    log_success "应答参数构建完成"
}

# ========== 第九步：下载并执行安装 ==========
run_installer() {
    log_step "下载 CyberPanel 安装脚本..."

    INSTALL_SCRIPT="/tmp/cyberpanel_installer.sh"

    # 优先用 curl，失败则用 wget
    if command -v curl &>/dev/null; then
        curl -sSL https://cyberpanel.net/install.sh -o "$INSTALL_SCRIPT"
    else
        wget -qO "$INSTALL_SCRIPT" https://cyberpanel.net/install.sh
    fi

    chmod +x "$INSTALL_SCRIPT"
    log_success "安装脚本下载完成"

    log_step "开始执行 CyberPanel 安装..."
    log_info "安装预计需要 10~20 分钟，请勿中断..."
    echo ""

    # 注入自动应答并执行安装
    echo -e "$ANSWER_LIST" | bash "$INSTALL_SCRIPT"
}

# ========== 第十步：安装后配置 ==========
post_install_config() {
    log_step "安装后处理..."

    # 设置服务开机自启
    SERVICES=(
        "lscpd"        # CyberPanel 主服务
        "lshttpd"      # OpenLiteSpeed / LiteSpeed
        "mariadb"      # 数据库
        "named"        # PowerDNS (如已安装)
        "postfix"      # 邮件服务 (如已安装)
        "pure-ftpd"    # FTP 服务 (如已安装)
    )

    for SVC in "${SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^${SVC}.service"; then
            systemctl enable "$SVC" 2>/dev/null || true
            log_info "已设置开机自启: $SVC"
        fi
    done

    log_success "开机自启配置完成"
}

# ========== 最终：读取并打印所有密码 ==========
show_result() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    # ------------------------------------------------
    # 读取 MySQL root 密码
    # 优先从 /etc/cyberpanel/mysqlPassword 读取
    # 备选从 /home/cyberpanel/.my.cnf 读取
    # ------------------------------------------------
    MYSQL_ROOT_PASSWORD=""

    # 方法1: 从官方密码文件读取
    if [ -f "/etc/cyberpanel/mysqlPassword" ]; then
        MYSQL_ROOT_PASSWORD=$(cat /etc/cyberpanel/mysqlPassword 2>/dev/null | tr -d '[:space:]')
    fi

    # 方法2: 从 .my.cnf 读取（备选 / 旧版兼容）
    if [ -z "$MYSQL_ROOT_PASSWORD" ] && [ -f "/home/cyberpanel/.my.cnf" ]; then
        MYSQL_ROOT_PASSWORD=$(grep -i "^password" /home/cyberpanel/.my.cnf \
            | head -1 \
            | awk -F'=' '{print $2}' \
            | tr -d '[:space:]"'"'" 2>/dev/null)
    fi

    # 方法3: 从 settings.py 读取 rootdb 密码（最后备选）
    if [ -z "$MYSQL_ROOT_PASSWORD" ] && [ -f "/usr/local/CyberCP/CyberCP/settings.py" ]; then
        MYSQL_ROOT_PASSWORD=$(python3 -c "
import sys
sys.path.insert(0, '/usr/local/CyberCP')
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'CyberCP.settings')
try:
    import django
    django.setup()
    from django.conf import settings
    print(settings.DATABASES['rootdb']['PASSWORD'])
except Exception as e:
    print('')
" 2>/dev/null)
    fi

    # 密码未找到时给出提示
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        MYSQL_ROOT_PASSWORD="[未能自动读取，请手动执行: cat /etc/cyberpanel/mysqlPassword]"
    fi

    # ------------------------------------------------
    # 读取 CyberPanel admin 密码
    # ------------------------------------------------
    CYBERPANEL_ADMIN_PASSWORD=""

    case "$ADMIN_PASSWORD" in
        "auto"|"random")
            # 随机密码：从安装日志中提取
            # CyberPanel 安装完成后会输出 "CyberPanel Password: XXXXXX"
            if [ -f "/root/install.log" ]; then
                CYBERPANEL_ADMIN_PASSWORD=$(grep -i "password" /root/install.log \
                    | grep -iv "mysql\|database\|db\|mariadb" \
                    | tail -1 \
                    | awk '{print $NF}' \
                    | tr -d '[:space:]' 2>/dev/null)
            fi

            # 备选：通过 cyberpanel CLI 验证管理员密码是否存在
            if [ -z "$CYBERPANEL_ADMIN_PASSWORD" ]; then
                CYBERPANEL_ADMIN_PASSWORD="[随机生成，请查看安装日志: /root/install.log]"
            fi
            ;;
        "default"|"1234567")
            CYBERPANEL_ADMIN_PASSWORD="1234567"
            ;;
        *)
            CYBERPANEL_ADMIN_PASSWORD="$ADMIN_PASSWORD"
            ;;
    esac

    # ------------------------------------------------
    # 读取 WebAdmin (OpenLiteSpeed) 密码
    # ------------------------------------------------
    OLS_ADMIN_PASSWORD=""
    OLS_CONF="/usr/local/lsws/admin/conf/htpasswd"

    if [ -f "$OLS_CONF" ]; then
        OLS_ADMIN_PASSWORD="[已设置，请通过 WebAdmin 界面修改]"
    fi

    # ------------------------------------------------
    # 打印安装结果
    # ------------------------------------------------
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          CyberPanel 安装完成！                       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}🖥  系统版本  :${NC}  Ubuntu ${UBUNTU_VERSION}"
    echo -e "  ${CYAN}⚙️  Web 服务器:${NC}  ${WEB_SERVER}"
    echo -e "  ${CYAN}📅 安装时间  :${NC}  ${INSTALL_DATE}"
    echo ""

    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━ 访问地址 ━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}📌 CyberPanel 管理面板 :${NC}"
    echo -e "     👉 https://${SERVER_IP}:8090"
    echo ""
    echo -e "  ${BLUE}📌 WebAdmin 控制台     :${NC}"
    echo -e "     👉 https://${SERVER_IP}:7080"
    echo ""

    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━ CyberPanel 账号 ━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}👤 管理员账号    :${NC} ${GREEN}admin${NC}"
    if [[ "$CYBERPANEL_ADMIN_PASSWORD" == "1234567" ]]; then
        echo -e "  ${BLUE}🔑 管理员密码    :${NC} ${RED}${CYBERPANEL_ADMIN_PASSWORD}  ⚠️ 默认密码，请立即修改！${NC}"
    else
        echo -e "  ${BLUE}🔑 管理员密码    :${NC} ${GREEN}${CYBERPANEL_ADMIN_PASSWORD}${NC}"
    fi
    echo ""

    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━ 数据库账号 ━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}🗄  数据库类型    :${NC} MariaDB"
    echo -e "  ${BLUE}👤 数据库账号    :${NC} ${GREEN}root${NC}"
    echo -e "  ${BLUE}🔑 数据库密码    :${NC} ${GREEN}${MYSQL_ROOT_PASSWORD}${NC}"
    echo -e "  ${BLUE}🌐 连接地址      :${NC} 127.0.0.1:3306 (仅本地)"
    echo ""

    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━ 常用命令 ━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  升级 CyberPanel  : ${CYAN}cyberpanel upgrade${NC}"
    echo -e "  重启 面板服务    : ${CYAN}systemctl restart lscpd${NC}"
    echo -e "  重启 Web 服务器  : ${CYAN}systemctl restart lshttpd${NC}"
    echo -e "  重启 数据库      : ${CYAN}systemctl restart mariadb${NC}"
    echo -e "  查看 MySQL 密码  : ${CYAN}cat /etc/cyberpanel/mysqlPassword${NC}"
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo ""

    # ------------------------------------------------
    # 保存所有信息到文件
    # ------------------------------------------------
    INFO_FILE="/root/cyberpanel_info.txt"
    {
        echo "========================================================"
        echo "  CyberPanel 安装信息 - 请妥善保管此文件！"
        echo "========================================================"
        echo ""
        echo "  安装时间    : ${INSTALL_DATE}"
        echo "  系统版本    : Ubuntu ${UBUNTU_VERSION}"
        echo "  Web 服务器  : ${WEB_SERVER}"
        echo ""
        echo "  ---- 访问地址 ----"
        echo "  CyberPanel  : https://${SERVER_IP}:8090"
        echo "  WebAdmin    : https://${SERVER_IP}:7080"
        echo ""
        echo "  ---- CyberPanel 账号 ----"
        echo "  账号        : admin"
        echo "  密码        : ${CYBERPANEL_ADMIN_PASSWORD}"
        echo ""
        echo "  ---- 数据库账号 ----"
        echo "  数据库类型  : MariaDB"
        echo "  账号        : root"
        echo "  密码        : ${MYSQL_ROOT_PASSWORD}"
        echo "  端口        : 3306"
        echo ""
        echo "========================================================"
    } > "$INFO_FILE"
    chmod 600 "$INFO_FILE"   # 仅 root 可读，保护密码安全

    log_info "📄 所有账号信息已保存至: ${YELLOW}${INFO_FILE}${NC}"
    log_warn "⚠️  该文件权限已设为 600，仅 root 可读。请妥善保管！"

    # ------------------------------------------------
    # 询问是否重启
    # ------------------------------------------------
    echo ""
    read -p "  建议重启服务器，是否现在重启？(y/N): " DO_REBOOT
    if [[ "$DO_REBOOT" =~ ^[Yy]$ ]]; then
        log_info "5 秒后重启服务器..."
        sleep 5
        reboot
    else
        log_warn "请记得稍后手动执行: reboot"
    fi
}

# ========== 主程序入口 ==========
main() {
    clear
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║    CyberPanel 全自动安装脚本   ║${NC}"
    echo -e "${BLUE}║      支持: Ubuntu 20.04 / 22.04 / 24.04      ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    check_root
    detect_ubuntu_version
    check_resources
    check_existing_install
    configure_firewall
    update_system
    prepare_ubuntu_24       # 仅 Ubuntu 24.04 执行额外处理
    build_answers
    run_installer
    post_install_config
    show_result
}

main "$@"