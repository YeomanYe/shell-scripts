#!/bin/bash

# macOS 磁盘清理脚本
# 用法: ./cleanup-macos.sh [--dry-run]

set -e

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== Dry Run 模式 - 不会实际删除任何文件 ==="
    echo ""
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 清理项目列表
declare -A CLEANUP_ITEMS

echo_size() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "0B"
    else
        echo "0B"
    fi
}

echo_size_safe() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "0B"
    else
        echo "-"
    fi
}

scan_items() {
    echo ">>> 废纸篓"
    CLEANUP_ITEMS["废纸篓"]="$HOME/.Trash|rm -rf $HOME/.Trash/*"
    echo "    大小: $(echo_size_safe "$HOME/.Trash")"

    echo ""
    echo ">>> Xcode"
    CLEANUP_ITEMS["Xcode DerivedData"]="$HOMELibrary/Developer/Xcode/DerivedData|rm -rf $HOME/Library/Developer/Xcode/DerivedData/*"
    echo "    DerivedData: $(echo_size_safe "$HOMELibrary/Developer/Xcode/DerivedData")"

    CLEANUP_ITEMS["Xcode Archives"]="$HOMELibrary/Developer/Xcode/Archives|rm -rf $HOME/Library/Developer/Xcode/Archives/*"
    echo "    Archives: $(echo_size_safe "$HOMELibrary/Developer/Xcode/Archives")"

    CLEANUP_ITEMS["Xcode SPM Cache"]="$HOMELibrary/Caches/org.swift.swiftpm|rm -rf $HOME/Library/Caches/org.swift.swiftpm/*"
    echo "    SPM Cache: $(echo_size_safe "$HOMELibrary/Caches/org.swift.swiftpm")"

    CLEANUP_ITEMS["Xcode CoreSimulator"]="$HOMELibrary/Developer/CoreSimulator/Caches|rm -rf $HOME/Library/Developer/CoreSimulator/Caches/*"
    echo "    CoreSimulator: $(echo_size_safe "$HOMELibrary/Developer/CoreSimulator/Caches")"

    echo ""
    echo ">>> Node.js"
    CLEANUP_ITEMS["npm Cache"]="$HOME/.npm|rm -rf $HOME/.npm/_cacache"
    echo "    npm: $(echo_size_safe "$HOME/.npm")"

    CLEANUP_ITEMS["yarn Cache"]="$HOMELibrary/Caches/yarn|rm -rf $HOME/Library/Caches/yarn"
    echo "    yarn: $(echo_size_safe "$HOMELibrary/Caches/yarn")"

    echo ""
    echo ">>> CocoaPods"
    CLEANUP_ITEMS["CocoaPods Cache"]="$HOMELibrary/Caches/CocoaPods|rm -rf $HOME/Library/Caches/CocoaPods/Pods"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Caches/CocoaPods")"

    echo ""
    echo ">>> Carthage"
    CLEANUP_ITEMS["Carthage Cache"]="$HOMELibrary/Caches/carthage|rm -rf $HOME/Library/Caches/carthage"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Caches/carthage")"

    echo ""
    echo ">>> Homebrew"
    local brew_cache
    brew_cache=$(brew --cache 2>/dev/null || echo "")
    CLEANUP_ITEMS["Homebrew Cache"]="$brew_cache|rm -rf $brew_cache"
    echo "    大小: $(echo_size_safe "$brew_cache")"

    echo ""
    echo ">>> 系统日志"
    CLEANUP_ITEMS["系统日志"]="/var/log|sudo rm -rf /var/log/*.gz /var/log/asl/*.asl 2>/dev/null || true"
    echo "    大小: -"

    CLEANUP_ITEMS["崩溃报告"]="$HOMELibrary/Logs/DiagnosticReports|rm -rf $HOME/Library/Logs/DiagnosticReports/*"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Logs/DiagnosticReports")"

    echo ""
    echo ">>> 临时文件"
    CLEANUP_ITEMS["系统临时文件"]="/tmp|rm -rf /tmp/com.apple.* 2>/dev/null || true"
    echo "    大小: -"

    CLEANUP_ITEMS["用户临时文件"]="$TMPDIR|rm -rf $TMPDIR/* 2>/dev/null || true"
    echo "    大小: $(echo_size_safe "$TMPDIR")"

    echo ""
    echo ">>> 系统缓存"
    CLEANUP_ITEMS["用户缓存目录"]="$HOMELibrary/Caches|rm -rf $HOME/Library/Caches/*"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Library/Caches")"

    echo ""
    echo ">>> iOS 日志"
    CLEANUP_ITEMS["iOS Device Logs"]="$HOMELibrary/Logs/CoreSimulator|rm -rf $HOME/Library/Logs/CoreSimulator/*"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Logs/CoreSimulator")"

    echo ""
    echo ">>> 字体缓存"
    CLEANUP_ITEMS["字体缓存"]="$HOMELibrary/Caches/FontRegistry|rm -rf $HOME/Library/Caches/FontRegistry/*"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Caches/FontRegistry")"

    echo ""
    echo ">>> 终端历史"
    CLEANUP_ITEMS["Bash History"]="$HOME/.bash_history|> $HOME/.bash_history"
    echo "    Bash: $(echo_size_safe "$HOME/.bash_history")"

    CLEANUP_ITEMS["Zsh History"]="$HOME/.zsh_history|> $HOME/.zsh_history"
    echo "    Zsh: $(echo_size_safe "$HOME/.zsh_history")"
}

prompt_selection() {
    echo "========================================"
    echo "       macOS 磁盘清理脚本"
    echo "========================================"
    echo ""
    echo "请选择要清理的项目（输入数字，多个用空格分隔）："
    echo "  输入 'a' 清理所有项目"
    echo "  输入 'q' 退出"
    echo ""
    echo "可用项目:"

    local index=1
    for key in "${!CLEANUP_ITEMS[@]}"; do
        local path="${CLEANUP_ITEMS[$key]%|*}"
        local size=$(echo_size_safe "$path")
        printf "  [%2d] %-25s %s\n" "$index" "$key" "$size"
        ((index++))
    done

    echo ""
    echo -n "请输入选择: "
    read -r selection

    if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
        echo "已退出。"
        exit 0
    fi

    if [[ "$selection" == "a" || "$selection" == "A" ]]; then
        SELECTED_ITEMS=("${!CLEANUP_ITEMS[@]}")
    else
        # 解析用户输入
        SELECTED_ITEMS=()
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]]; then
                local idx=0
                for key in "${!CLEANUP_ITEMS[@]}"; do
                    if [[ $idx -eq $((num - 1)) ]]; then
                        SELECTED_ITEMS+=("$key")
                        break
                    fi
                    ((idx++))
                done
            fi
        done
    fi

    if [[ ${#SELECTED_ITEMS[@]} -eq 0 ]]; then
        echo -e "${RED}未选择任何项目${NC}"
        exit 1
    fi

    echo ""
    echo -e "已选择 ${GREEN}${#SELECTED_ITEMS[@]}${NC} 个项目:"
    for item in "${SELECTED_ITEMS[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo -n "确认清理? (y/n): "
    read -r confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消。"
        exit 0
    fi
}

run_cleanup() {
    local name="$1"
    local cmd="$2"

    echo -n "清理 $name... "
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}Dry Run${NC}"
    else
        eval "$cmd" >/dev/null 2>&1
        echo -e "${GREEN}完成${NC}"
    fi
}

execute_cleanup() {
    echo ""
    echo "========================================"
    echo "          开始清理"
    echo "========================================"
    echo ""

    for item in "${SELECTED_ITEMS[@]}"; do
        local cmd="${CLEANUP_ITEMS[$item]##*|}"
        run_cleanup "$item" "$cmd"
    done

    echo ""
    echo "========================================"
    echo "          清理完成！"
    echo "========================================"

    # 显示当前磁盘空间
    echo ""
    echo "当前磁盘使用情况:"
    df -h / | tail -1

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}提示: 这是 Dry Run 模式，未实际删除任何文件${NC}"
    else
        echo -e "${GREEN}清理完成！建议重启 Xcode 等应用以释放更多空间${NC}"
    fi
}

# 主流程
scan_items
prompt_selection
execute_cleanup
