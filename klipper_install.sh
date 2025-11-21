#!/bin/bash

cat << "EOF"
                   ________  ___       __   ________  ___       __
                  |\_____  \|\  \     |\  \|\_____  \|\  \     |\  \
                   \|___/  /\ \  \    \ \  \\|___/  /\ \  \    \ \  \
                       /  / /\ \  \  __\ \  \   /  / /\ \  \  __\ \  \
                      /  /_/__\ \  \|\__\_\  \ /  /_/__\ \  \|\__\_\  \
                     |\________\ \____________\\________\ \____________\
                      \|_______|\|____________|\|_______|\|____________|
___________________                                   ________            ______
___  ____/__  /__(_)____________________________      ___  __ \______________  /______________
__  /_   __  /__  /___  __ \__  __ \  _ \_  ___/________  / / /  __ \  ___/_  //_/  _ \_  ___/
_  __/   _  / _  / __  /_/ /_  /_/ /  __/  /   _/_____/  /_/ // /_/ / /__ _  ,<  /  __/  /
/_/      /_/  /_/  _  .___/_  .___/\___//_/           /_____/ \____/\___/ /_/|_| \___//_/
                   /_/     /_/
EOF


USER="zwzw"
TARGET_HOME="/home/$USER"
SCRIPTS_DIR="$TARGET_HOME/scripts"
KIAUH_DIR="$TARGET_HOME/kiauh"
SCRIPT_PIDFILE="/tmp/klipper_manager.pid"
readonly COMPONENT_ORDER=("Klipper" "Moonraker" "Mainsail" "Fluidd" "Crowsnest")

declare -A COMPONENT_PATHS=(
    ["Klipper"]="$TARGET_HOME/klipper"
    ["Moonraker"]="$TARGET_HOME/moonraker"
    ["Mainsail"]="$TARGET_HOME/mainsail"
    ["Fluidd"]="$TARGET_HOME/fluidd"
    ["Crowsnest"]="$TARGET_HOME/crowsnest"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'



log_info() { echo -e "${BLUE}ℹ️  [INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}✅ [SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠️  [WARNING]${NC} $1"; }
log_error() { echo -e "${RED}❌ [ERROR]${NC} $1"; }

is_dir_present() {
    [ -d "$1" ]
}


ensure_kiauh() {
    log_info "检查 KIAUH 项目..."
    if is_dir_present "$KIAUH_DIR/.git"; then
        log_success "KIAUH 已存在于 $KIAUH_DIR"
    else
        log_warning "KIAUH 未找到，开始从 GitHub 克隆..."
        if su "$USER" -c "git clone https://github.com/dw-0/kiauh.git '$KIAUH_DIR'"; then
            log_success "KIAUH 克隆成功。"
        else
            log_error "KIAUH 克隆失败！请检查网络连接和权限。"
            exit 1
        fi
    fi
}

parse_components_env() {
    local components="$COMPONENTS_ENV"
    for component in "${COMPONENT_ORDER[@]}"; do
        declare -g "INSTALL_${component^^}=false"
    done

    if [ -z "$components" ]; then
        log_info "环境变量 COMPONENTS_ENV 为空，将不执行任何组件操作。"
        return 0
    fi

    log_info "解析环境变量 COMPONENTS_ENV: '$components'"

    case "$components" in
        "a")
            log_info "模式: 安装所有组件"
                        for component in "${COMPONENT_ORDER[@]}"; do
                declare -g "INSTALL_${component^^}=true"
            done
            ;;
        *)
            while read -n 1 char; do
                case "$char" in
                    k) declare -g "INSTALL_KLIPPER=true" && log_info "  -> 添加 Klipper" ;;
                    m) declare -g "INSTALL_MOONRAKER=true" && log_info "  -> 添加 Moonraker" ;;
                    s) declare -g "INSTALL_MAINSAIL=true" && log_info "  -> 添加 Mainsail" ;;
                    f) declare -g "INSTALL_FLUIDD=true" && log_info "  -> 添加 Fluidd" ;;
                    w) declare -g "INSTALL_CROWSNEST=true" && log_info "  -> 添加 Crowsnest" ;;
                    *) log_warning "未知组件标识: '$char'，将忽略" ;;
                esac
            done <<< "$components"
            ;;
    esac
}

manage_components() {
    echo -e "\n${CYAN}============================================================${NC}"
    log_info "开始管理组件..."
    echo -e "${CYAN}============================================================${NC}"

        for component_name in "${COMPONENT_ORDER[@]}"; do
        local component_path="${COMPONENT_PATHS[$component_name]}"
        local component_key="${component_name,,}"
        local install_flag_var="INSTALL_${component_name^^}"
        local should_install="${!install_flag_var}"

        echo -e "\n--- 处理组件: ${BOLD}$component_name${NC} ---"

        if [ "$should_install" = true ]; then
            if is_dir_present "$component_path"; then
                log_info "$component_name 已安装，跳过。"
            else
                log_info "$component_name 未安装，开始安装..."
                if su "$USER" -c "$SCRIPTS_DIR/install_${component_key}.exp"; then
                    log_success "$component_name 安装脚本执行完毕。"
                else
                    log_error "$component_name 安装脚本执行失败！"
                fi
            fi
        else
            if is_dir_present "$component_path"; then
                log_info "$component_name 已安装但不再需要，开始卸载..."
                if su "$USER" -c "$SCRIPTS_DIR/uninstall_${component_key}.exp"; then
                    log_success "$component_name 卸载脚本执行完毕。"
                else
                    log_error "$component_name 卸载脚本执行失败！"
                fi
            else
                log_info "$component_name 未安装，无需操作。"
            fi
        fi
    done

    echo -e "\n${CYAN}============================================================${NC}"
    log_success "所有组件管理任务已完成。"
    echo -e "${CYAN}============================================================${NC}\n"
}

show_status() {
    echo -e "\n${CYAN}============================================================${NC}"
    log_info "当前组件状态总览"
    echo -e "${CYAN}============================================================${NC}"
        for component_name in "${COMPONENT_ORDER[@]}"; do
        local component_path="${COMPONENT_PATHS[$component_name]}"
        if is_dir_present "$component_path"; then
            log_success "✅ $component_name"
        else
            log_info "⭕ $component_name"
        fi
    done
    echo -e "${CYAN}============================================================${NC}\n"
}

run_manager_tasks() {
    log_info "=== Klipper Docker 组件管理器开始运行 (PID: $$) ==="
    log_info "环境变量 COMPONENTS_ENV: '${COMPONENTS_ENV:-<未设置>}'"

    ensure_kiauh

    parse_components_env

    manage_components

    show_status

    log_success "=== Klipper Docker 组件管理任务完成 ==="
}

main() {
    local pid1_comm=$(tr -d '\0' < /proc/1/comm)

    if [ "$pid1_comm" = "systemd" ]; then
        
        if [ -f "$SCRIPT_PIDFILE" ] && kill -0 "$(cat "$SCRIPT_PIDFILE")" 2>/dev/null; then
            log_warning "组件管理器已在运行 (PID: $(cat "$SCRIPT_PIDFILE"))，本次将退出。"
            exit 0
        fi

        echo $$ > "$SCRIPT_PIDFILE"
        trap 'rm -f "$SCRIPT_PIDFILE"; log_info "清理 PID 文件并退出。"' EXIT

        run_manager_tasks

    else
        
        log_info "检测到 systemd 未运行。当前脚本作为 PID 1 启动。"
        log_info "准备启动 systemd，并在后台启动管理器实例..."
        (
            log_info "后台管理器进程 (PID: $$) 已启动，等待 systemd 准备就绪..."
            
            while ! systemctl is-active --quiet systemd-journald; do
                log_info "等待 systemd-journald 服务启动..."
                sleep 1
            done
            
            log_success "systemd-journald 已就绪，开始执行管理任务。"
            
            run_manager_tasks
            
        ) & 
        local bg_pid=$!
        log_info "已在后台启动管理器实例 (PID: $bg_pid)，其输出将重定向到日志。"

        log_info "前台控制权交还给 systemd..."
        exec /lib/systemd/systemd log-level=info unit=sysinit.target
    fi
}

main