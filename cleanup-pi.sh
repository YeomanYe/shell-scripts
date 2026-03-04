#!/bin/bash

# 树莓派磁盘清理脚本
# 使用方式:
#   ./cleanup.sh              # 交互式菜单
#   ./cleanup.sh --all       # 全部清理
#   ./cleanup.sh --apt --logs # 清理指定模块
#   ./cleanup.sh --dry-run   # 预览模式
#   ./cleanup.sh --help      # 显示帮助

set -e

# ============================================================
# 全局变量
# ============================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 模式标志
DRY_RUN=false
INTERACTIVE=true

# 选择的模块
SELECTED_MODULES=()

# 模块定义: (id 名称 是否可选)
declare -a MODULES=(
    "1:APT 缓存:no"
    "2:日志文件:no"
    "3:临时文件:no"
    "4:缩略图缓存:no"
    "5:Docker:yes"
    "6:npm/yarn/pnpm:yes"
    "7:pip:yes"
    "8:磁盘使用情况:no"
)

# ============================================================
# 辅助函数
# ============================================================

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       树莓派磁盘清理工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "0B"
    elif [[ -f "$path" ]]; then
        ls -lh "$path" 2>/dev/null | awk '{print $5}' || echo "0B"
    else
        echo "0B"
    fi
}

get_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sb "$path" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

format_size() {
    local size=$1
    if [[ $size -lt 1024 ]]; then
        echo "${size}B"
    elif [[ $size -lt 1048576 ]]; then
        echo "$((size / 1024))KB"
    elif [[ $size -lt 1073741824 ]]; then
        echo "$((size / 1048576))MB"
    else
        echo "$((size / 1073741824))GB"
    fi
}

check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        return 1
    fi
    return 0
}

# ============================================================
# 预览函数
# ============================================================

preview_apt() {
    local size=$(get_size "/var/cache/apt/archives")
    echo "  APT 缓存: $(format_size $size)"
}

preview_logs() {
    local size=0
    # 系统日志 (需要 sudo)
    if check_sudo; then
        size=$((size + $(get_size "/var/log")))
    fi
    # 用户日志
    size=$((size + $(get_size "$HOME/.local/share/xorg")))
    size=$((size + $(get_size "$HOME/.cache")))
    echo "  日志文件: $(format_size $size)"
}

preview_temp() {
    local size=0
    size=$((size + $(get_size "/tmp")))
    size=$((size + $(get_size "/var/tmp")))
    echo "  临时文件: $(format_size $size)"
}

preview_thumbnails() {
    local size=$(get_size "$HOME/.cache/thumbnails")
    echo "  缩略图缓存: $(format_size $size)"
}

preview_docker() {
    if ! command -v docker &> /dev/null; then
        echo "  Docker: 未安装"
        return
    fi

    local size=0
    # dangling 镜像
    local dangling=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
    if [[ $dangling -gt 0 ]]; then
        local dangling_size=$(docker images -f "dangling=true" --format "{{.Size}}" 2>/dev/null | awk '{sum+=$1} END {print sum}')
        size=$((size + ${dangling_size:-0}))
    fi
    # 停止的容器
    local stopped=$(docker ps -a -f status=exited -q 2>/dev/null | wc -l)
    # 未使用的卷
    local volumes=$(docker volume ls -f dangling=true -q 2>/dev/null | wc -l)

    echo "  Docker (dangling 镜像: ${dangling}, 停止容器: ${stopped}, 未使用卷: ${volumes})"
}

preview_npm() {
    local size=0
    size=$((size + $(get_size "$HOME/.npm")))
    size=$((size + $(get_size "$HOME/.cache/yarn")))
    size=$((size + $(get_size "$HOME/.local/share/pnpm")))
    echo "  npm/yarn/pnpm: $(format_size $size)"
}

preview_pip() {
    local size=$(get_size "$HOME/.cache/pip")
    echo "  pip: $(format_size $size)"
}

# ============================================================
# 清理函数
# ============================================================

cleanup_apt() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  清理 APT 缓存 (dry-run)"
        return
    fi

    echo -n "  清理 APT 缓存... "

    if check_sudo; then
        apt-get clean >/dev/null 2>&1
        rm -rf /var/cache/apt/archives/* >/dev/null 2>&1
        echo -e "${GREEN}完成${NC}"
    else
        echo -e "${YELLOW}需要 sudo 权限${NC}"
    fi
}

cleanup_logs() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  清理日志文件 (dry-run)"
        return
    fi

    echo -n "  清理日志文件... "

    if check_sudo; then
        # 清理旧日志文件 (保留最近7天)
        find /var/log -type f -name "*.gz" -mtime +7 -delete 2>/dev/null || true
        find /var/log -type f -name "*.old" -mtime +7 -delete 2>/dev/null || true
        # 清理 journald
        journalctl --vacuum-time=7d >/dev/null 2>&1 || true
    fi

    # 清理用户缓存
    rm -rf "$HOME/.cache"/* 2>/dev/null || true
    rm -rf "$HOME/.local/share/xorg"/* 2>/dev/null || true

    echo -e "${GREEN}完成${NC}"
}

cleanup_temp() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  清理临时文件 (dry-run)"
        return
    fi

    echo -n "  清理临时文件... "

    # 清理 /tmp (保留当前用户相关)
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true

    echo -e "${GREEN}完成${NC}"
}

cleanup_thumbnails() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  清理缩略图缓存 (dry-run)"
        return
    fi

    echo -n "  清理缩略图缓存... "

    rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true

    echo -e "${GREEN}完成${NC}"
}

cleanup_docker() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  清理 Docker (dry-run)"
        return
    fi

    echo -n "  清理 Docker... "

    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker 未安装${NC}"
        return
    fi

    # 清理 dangling 镜像
    docker image prune -f >/dev/null 2>&1 || true
    # 清理停止的容器
    docker container prune -f >/dev/null 2>&1 || true
    # 清理未使用的网络
    docker network prune -f >/dev/null 2>&1 || true
    # 清理未使用的卷
    docker volume prune -f >/dev/null 2>&1 || true
    # 清理构建缓存
    docker builder prune -f >/dev/null 2>&1 || true

    echo -e "${GREEN}完成${NC}"
}

cleanup_npm() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  清理 npm/yarn/pnpm (dry-run)"
        return
    fi

    echo -n "  清理 npm/yarn/pnpm 缓存... "

    # npm
    if command -v npm &> /dev/null; then
        npm cache clean --force >/dev/null 2>&1 || true
    fi
    # yarn
    rm -rf "$HOME/.cache/yarn" 2>/dev/null || true
    # pnpm
    if command -v pnpm &> /dev/null; then
        pnpm store prune >/dev/null 2>&1 || true
    fi

    echo -e "${GREEN}完成${NC}"
}

cleanup_pip() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  清理 pip (dry-run)"
        return
    fi

    echo -n "  清理 pip 缓存... "

    rm -rf "$HOME/.cache/pip" 2>/dev/null || true

    echo -e "${GREEN}完成${NC}"
}

show_disk_usage() {
    echo ""
    echo -e "${BOLD}磁盘使用情况:${NC}"
    echo ""
    df -h / | tail -1 | awk '{print "  根分区: " $3 " / " $2 " (" $5 " 使用)"}'
    df -h "$HOME" | tail -1 | awk '{print "  用户分区: " $3 " / " $2 " (" $5 " 使用)"}'
    echo ""
}

# ============================================================
# 交互式菜单
# ============================================================

show_menu() {
    local selected=("$@")

    clear
    print_header

    echo -e "${BOLD}请选择要清理的项目 (空格键切换, 回车确认, 0 退出):${NC}"
    echo ""

    for module in "${MODULES[@]}"; do
        local id="${module%%:*}"
        local rest="${module#*:}"
        local name="${rest%%:*}"
        local optional="${rest##*:}"

        local is_selected=false
        for sel in "${selected[@]}"; do
            if [[ "$sel" == "$id" ]]; then
                is_selected=true
                break
            fi
        done

        if [[ "$is_selected" == "true" ]]; then
            echo -e "  [*] ${id}. ${name}"
        else
            echo -e "  [ ] ${id}. ${name}"
        fi
    done

    echo ""

    if [[ ${#selected[@]} -gt 0 ]]; then
        echo -e "已选择: ${CYAN}${selected[*]}${NC}"
    else
        echo -e "已选择: ${YELLOW}无${NC}"
    fi

    echo ""
    echo -e "${BOLD}操作说明:${NC}"
    echo "  空格键 - 切换选择"
    echo "  回车键 - 确认执行"
    echo "  0 - 退出"
    echo ""
}

get_input() {
    local selected=("$@")
    local key

    # 读取单个字符
    IFS= read -n1 -r key

    case "$key" in
        " ")  # 空格键 - 切换选择
            # 获取当前行输入的数字
            local num
            read -t1 num || true
            num=$(echo "$num" | tr -d '[:space:]')

            if [[ -n "$num" ]]; then
                # 切换选择状态
                local found=false
                local new_selected=()
                for sel in "${selected[@]}"; do
                    if [[ "$sel" == "$num" ]]; then
                        found=true
                    else
                        new_selected+=("$sel")
                    fi
                done

                if [[ "$found" == "false" ]]; then
                    new_selected+=("$num")
                fi

                selected=("${new_selected[@]}")
            fi
            ;;
        "")
            # 回车键 - 确认
            SELECTED_MODULES=("${selected[@]}")
            return 0
            ;;
        "0")
            echo ""
            echo "退出"
            exit 0
            ;;
    esac

    show_menu "${selected[@]}"
    get_input "${selected[@]}"
}

run_interactive() {
    local selected=()

    while true; do
        show_menu "${selected[@]}"

        echo -n "请选择: "
        read -r choice

        case "$choice" in
            "")
                # 回车确认
                if [[ ${#selected[@]} -eq 0 ]]; then
                    echo -e "${YELLOW}请至少选择一个项目${NC}"
                    sleep 1
                    continue
                fi
                break
                ;;
            0)
                echo "退出"
                exit 0
                ;;
            *)
                # 切换选择状态
                local found=false
                local new_selected=()
                for sel in "${selected[@]}"; do
                    if [[ "$sel" == "$choice" ]]; then
                        found=true
                    else
                        new_selected+=("$sel")
                    fi
                done

                if [[ "$found" == "false" ]]; then
                    new_selected+=("$choice")
                fi

                selected=("${new_selected[@]}")
                ;;
        esac
    done

    SELECTED_MODULES=("${selected[@]}")
}

# ============================================================
# 命令行参数解析
# ============================================================

show_help() {
    print_header
    echo -e "${BOLD}使用方式:${NC}"
    echo "  $0              交互式菜单"
    echo "  $0 --all        全部清理"
    echo "  $0 --apt        清理 APT 缓存"
    echo "  $0 --logs       清理日志文件"
    echo "  $0 --temp       清理临时文件"
    echo "  $0 --thumbnails 清理缩略图缓存"
    echo "  $0 --docker     清理 Docker (可选模块)"
    echo "  $0 --npm        清理 npm/yarn/pnpm (可选模块)"
    echo "  $0 --pip        清理 pip (可选模块)"
    echo "  $0 --disk       显示磁盘使用情况"
    echo "  $0 --dry-run    预览模式"
    echo "  $0 --help       显示此帮助"
    echo ""
    echo -e "${BOLD}示例:${NC}"
    echo "  $0 --apt --logs          清理 APT 和日志"
    echo "  $0 --docker --npm --pip  清理可选模块"
    echo "  $0 --dry-run --all       预览全部清理"
    echo ""
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        INTERACTIVE=true
        return
    fi

    INTERACTIVE=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --all)
                SELECTED_MODULES=(1 2 3 4 5 6 7)
                ;;
            --apt)
                SELECTED_MODULES+=(1)
                ;;
            --logs)
                SELECTED_MODULES+=(2)
                ;;
            --temp)
                SELECTED_MODULES+=(3)
                ;;
            --thumbnails)
                SELECTED_MODULES+=(4)
                ;;
            --docker)
                SELECTED_MODULES+=(5)
                ;;
            --npm)
                SELECTED_MODULES+=(6)
                ;;
            --pip)
                SELECTED_MODULES+=(7)
                ;;
            --disk)
                SELECTED_MODULES+=(8)
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                echo "使用 --help 查看帮助"
                exit 1
                ;;
        esac
        shift
    done

    # 去重
    SELECTED_MODULES=($(echo "${SELECTED_MODULES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

# ============================================================
# 预览和确认
# ============================================================

show_preview() {
    echo ""
    echo -e "${BOLD}=== 预览 - 将清理的内容 ===${NC}"
    echo ""

    for mod in "${SELECTED_MODULES[@]}"; do
        case "$mod" in
            1) preview_apt ;;
            2) preview_logs ;;
            3) preview_temp ;;
            4) preview_thumbnails ;;
            5) preview_docker ;;
            6) preview_npm ;;
            7) preview_pip ;;
            8) show_disk_usage ;;
        esac
    done

    echo ""
}

confirm() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}=== Dry Run 模式 - 不会实际删除任何文件 ===${NC}"
        return 0
    fi

    # 检查是否只选择了磁盘查看
    if [[ ${#SELECTED_MODULES[@]} -eq 1 ]] && [[ "${SELECTED_MODULES[0]}" == "8" ]]; then
        return 0
    fi

    echo -e "${BOLD}确认执行清理? [y/N]:${NC} "
    read -r confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        echo "取消"
        exit 0
    fi
}

# ============================================================
# 执行清理
# ============================================================

execute_cleanup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}Dry Run 模式 - 预览完成，实际未执行清理${NC}"
        echo ""
        return
    fi

    echo ""
    echo -e "${BOLD}=== 开始清理 ===${NC}"
    echo ""

    for mod in "${SELECTED_MODULES[@]}"; do
        case "$mod" in
            1) cleanup_apt ;;
            2) cleanup_logs ;;
            3) cleanup_temp ;;
            4) cleanup_thumbnails ;;
            5) cleanup_docker ;;
            6) cleanup_npm ;;
            7) cleanup_pip ;;
            8) show_disk_usage ;;
        esac
    done
}

show_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}          清理完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}提示: 这是 Dry Run 模式，未实际删除任何文件${NC}"
        echo "要实际执行清理，请运行: $0 ${SELECTED_MODULES[*]/#/--}"
    else
        show_disk_usage
    fi

    echo ""
}

# ============================================================
# 主函数
# ============================================================

main() {
    parse_args "$@"

    if [[ "$INTERACTIVE" == "true" ]]; then
        run_interactive
    fi

    # 如果没有选择任何模块，显示帮助
    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        show_help
        exit 0
    fi

    # 预览
    show_preview

    # 确认
    confirm

    # 执行清理
    execute_cleanup

    # 总结
    show_summary
}

main "$@"
