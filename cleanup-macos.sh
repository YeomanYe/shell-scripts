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

# 清理项目列表（使用数组而非关联数组，兼容旧版 bash）
ITEM_NAMES=()
ITEM_PATHS=()
ITEM_CMDS=()

echo_size_safe() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "0B"
    else
        echo "-"
    fi
}

add_item() {
    ITEM_NAMES+=("$1")
    ITEM_PATHS+=("$2")
    ITEM_CMDS+=("$3")
}

scan_items() {
    echo ">>> 废纸篓"
    add_item "废纸篓" "$HOME/.Trash" "rm -rf $HOME/.Trash/*"
    echo "    大小: $(echo_size_safe "$HOME/.Trash")"

    echo ""
    echo ">>> Xcode"
    add_item "Xcode DerivedData" "$HOMELibrary/Developer/Xcode/DerivedData" "rm -rf $HOME/Library/Developer/Xcode/DerivedData/*"
    echo "    DerivedData: $(echo_size_safe "$HOMELibrary/Developer/Xcode/DerivedData")"

    add_item "Xcode Archives" "$HOMELibrary/Developer/Xcode/Archives" "rm -rf $HOME/Library/Developer/Xcode/Archives/*"
    echo "    Archives: $(echo_size_safe "$HOMELibrary/Developer/Xcode/Archives")"

    add_item "Xcode SPM Cache" "$HOMELibrary/Caches/org.swift.swiftpm" "rm -rf $HOME/Library/Caches/org.swift.swiftpm/*"
    echo "    SPM Cache: $(echo_size_safe "$HOMELibrary/Caches/org.swift.swiftpm")"

    add_item "Xcode CoreSimulator" "$HOMELibrary/Developer/CoreSimulator/Caches" "rm -rf $HOME/Library/Developer/CoreSimulator/Caches/*"
    echo "    CoreSimulator: $(echo_size_safe "$HOMELibrary/Developer/CoreSimulator/Caches")"

    echo ""
    echo ">>> Node.js"
    add_item "npm Cache" "$HOME/.npm" "rm -rf $HOME/.npm/_cacache"
    echo "    npm: $(echo_size_safe "$HOME/.npm")"

    add_item "yarn Cache" "$HOMELibrary/Caches/yarn" "rm -rf $HOME/Library/Caches/yarn"
    echo "    yarn: $(echo_size_safe "$HOMELibrary/Caches/yarn")"

    echo ""
    echo ">>> CocoaPods"
    add_item "CocoaPods Cache" "$HOMELibrary/Caches/CocoaPods" "rm -rf $HOME/Library/Caches/CocoaPods/Pods"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Caches/CocoaPods")"

    echo ""
    echo ">>> Carthage"
    add_item "Carthage Cache" "$HOMELibrary/Caches/carthage" "rm -rf $HOME/Library/Caches/carthage"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Caches/carthage")"

    echo ""
    echo ">>> Homebrew"
    local brew_cache
    brew_cache=$(brew --cache 2>/dev/null || echo "")
    add_item "Homebrew Cache" "$brew_cache" "rm -rf $brew_cache"
    echo "    大小: $(echo_size_safe "$brew_cache")"

    echo ""
    echo ">>> 系统日志"
    add_item "系统日志" "/var/log" "sudo rm -rf /var/log/*.gz /var/log/asl/*.asl 2>/dev/null || true"
    echo "    大小: -"

    add_item "崩溃报告" "$HOMELibrary/Logs/DiagnosticReports" "rm -rf $HOME/Library/Logs/DiagnosticReports/*"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Logs/DiagnosticReports")"

    echo ""
    echo ">>> 临时文件"
    add_item "系统临时文件" "/tmp" "rm -rf /tmp/com.apple.* 2>/dev/null || true"
    echo "    大小: -"

    add_item "用户临时文件" "$TMPDIR" "rm -rf $TMPDIR/* 2>/dev/null || true"
    echo "    大小: $(echo_size_safe "$TMPDIR")"

    echo ""
    echo ">>> 系统缓存"
    add_item "用户缓存目录" "$HOME/Library/Caches" "rm -rf $HOME/Library/Caches/*"
    echo "    大小: $(echo_size_safe "$HOME/Library/Caches")"

    echo ""
    echo ">>> iOS 日志"
    add_item "iOS Device Logs" "$HOMELibrary/Logs/CoreSimulator" "rm -rf $HOME/Library/Logs/CoreSimulator/*"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Logs/CoreSimulator")"

    echo ""
    echo ">>> 字体缓存"
    add_item "字体缓存" "$HOMELibrary/Caches/FontRegistry" "rm -rf $HOME/Library/Caches/FontRegistry/*"
    echo "    大小: $(echo_size_safe "$HOMELibrary/Caches/FontRegistry")"

    echo ""
    echo ">>> 终端历史"
    add_item "Bash History" "$HOME/.bash_history" "> $HOME/.bash_history"
    echo "    Bash: $(echo_size_safe "$HOME/.bash_history")"

    add_item "Zsh History" "$HOME/.zsh_history" "> $HOME/.zsh_history"
    echo "    Zsh: $(echo_size_safe "$HOME/.zsh_history")"
}

prompt_selection() {
    local total=${#ITEM_NAMES[@]}

    echo "========================================"
    echo "       macOS 磁盘清理脚本"
    echo "========================================"
    echo ""
    echo "请选择要清理的项目："
    echo "  - 多个数字用空格或逗号分隔: 1 3 5 或 1,3,5"
    echo "  - 支持范围选择: 1-5 (选择1到5)"
    echo "  - 可混合使用: 1-3,5,7-9"
    echo "  - 输入 'a' 清理所有项目"
    echo "  - 输入 'q' 退出"
    echo ""
    echo "可用项目:"

    local index
    for ((index=0; index<total; index++)); do
        printf "  [%2d] %-25s %s\n" $((index+1)) "${ITEM_NAMES[$index]}" "$(echo_size_safe "${ITEM_PATHS[$index]}")"
    done

    echo ""
    echo -n "请输入选择: "
    read -r selection

    if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
        echo "已退出。"
        exit 0
    fi

    SELECTED_INDICES=()
    if [[ "$selection" == "a" || "$selection" == "A" ]]; then
        for ((index=0; index<total; index++)); do
            SELECTED_INDICES+=($index)
        done
    else
        local normalized_selection
        normalized_selection=$(echo "$selection" | tr ',' ' ')
        for part in $normalized_selection; do
            if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                local start=${BASH_REMATCH[1]}
                local end=${BASH_REMATCH[2]}
                if [[ $start -le $end && $start -ge 1 && $end -le $total ]]; then
                    for ((num=start; num<=end; num++)); do
                        SELECTED_INDICES+=($((num - 1)))
                    done
                fi
            elif [[ "$part" =~ ^[0-9]+$ && "$part" -ge 1 && "$part" -le $total ]]; then
                SELECTED_INDICES+=($((part - 1)))
            fi
        done
        local unique_indices=()
        for idx in "${SELECTED_INDICES[@]}"; do
            local found=false
            for uidx in "${unique_indices[@]}"; do
                if [[ $idx -eq $uidx ]]; then
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                unique_indices+=($idx)
            fi
        done
        SELECTED_INDICES=("${unique_indices[@]}")
    fi

    if [[ ${#SELECTED_INDICES[@]} -eq 0 ]]; then
        echo -e "${RED}未选择任何有效项目${NC}"
        exit 1
    fi

    echo ""
    echo -e "已选择 ${GREEN}${#SELECTED_INDICES[@]}${NC} 个项目:"
    for idx in "${SELECTED_INDICES[@]}"; do
        echo "  - ${ITEM_NAMES[$idx]}"
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

    for idx in "${SELECTED_INDICES[@]}"; do
        run_cleanup "${ITEM_NAMES[$idx]}" "${ITEM_CMDS[$idx]}"
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
