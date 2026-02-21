#!/bin/bash

# macOS 磁盘清理脚本
# 用法: ./cleanup-macos.sh [--dry-run]

set -e

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "=== Dry Run 模式 - 不会实际删除任何文件 ==="
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "0B"
    else
        echo "N/A"
    fi
}

run_cleanup() {
    local name="$1"
    local path="$2"
    local cmd="$3"

    echo -n "清理 $name... "
    if [[ ! -e "$path" ]]; then
        echo -e "${YELLOW}不存在${NC}"
        return
    fi

    local size=$(echo_size "$path")

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}待删除: $size${NC}"
    else
        eval "$cmd" >/dev/null 2>&1
        echo -e "${GREEN}已清理: $size${NC}"
    fi
}

echo "========================================"
echo "       macOS 磁盘清理脚本"
echo "========================================"
echo ""

# 1. 清空废纸篓
echo ">>> 废纸篓"
run_cleanup "废纸篓" "$HOME/.Trash" "rm -rf $HOME/.Trash/*"

# 2. Xcode 派生数据
echo ""
echo ">>> Xcode"
run_cleanup "DerivedData" "$HOMELibrary/Developer/Xcode/DerivedData" "rm -rf $HOME/Library/Developer/Xcode/DerivedData/*"
run_cleanup "Xcode Archives" "$HOMELibrary/Developer/Xcode/Archives" "rm -rf $HOME/Library/Developer/Xcode/Archives/*"
run_cleanup "Xcode SPM Cache" "$HOMELibrary/Caches/org.swift.swiftpm" "rm -rf $HOME/Library/Caches/org.swift.swiftpm/*"
run_cleanup "Xcode CoreSimulator Cache" "$HOMELibrary/Developer/CoreSimulator/Caches" "rm -rf $HOMELibrary/Developer/CoreSimulator/Caches/*"

# 3. npm 缓存
echo ""
echo ">>> Node.js"
run_cleanup "npm Cache" "$HOME/.npm" "rm -rf $HOME/.npm/_cacache"
run_cleanup "yarn Cache" "$HOMELibrary/Caches/yarn" "rm -rf $HOME/Library/Caches/yarn"

# 4. CocoaPods 缓存
echo ""
echo ">>> CocoaPods"
run_cleanup "CocoaPods Cache" "$HOMELibrary/Caches/CocoaPods" "rm -rf $HOME/Library/Caches/CocoaPods/Pods"

# 5. Carthage 缓存
echo ""
echo ">>> Carthage"
run_cleanup "Carthage Cache" "$HOMELibrary/Caches/carthage" "rm -rf $HOME/Library/Caches/carthage"

# 6. Homebrew 缓存
echo ""
echo ">>> Homebrew"
run_cleanup "Homebrew Cache" "$(brew --cache)" "rm -rf $(brew --cache)"

# 7. 系统日志
echo ""
echo ">>> 系统日志"
run_cleanup "系统日志" "/var/log" "sudo rm -rf /var/log/*.gz /var/log/asl/*.asl 2>/dev/null || true"
run_cleanup "崩溃报告" "$HOMELibrary/Logs/DiagnosticReports" "rm -rf $HOME/Library/Logs/DiagnosticReports/*"

# 8. 临时文件
echo ""
echo ">>> 临时文件"
run_cleanup "系统临时文件" "/tmp" "rm -rf /tmp/com.apple.* 2>/dev/null || true"
run_cleanup "用户临时文件" "$TMPDIR" "rm -rf $TMPDIR/* 2>/dev/null || true"

# 9. 旧下载文件（可选 - 询问用户）
echo ""
echo ">>> 下载目录中的旧文件（超过30天）"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}待删除文件:${NC}"
    find "$HOME/Downloads" -type f -mtime +30 -ls 2>/dev/null | head -20 || true
else
    find "$HOME/Downloads" -type f -mtime +30 -delete 2>/dev/null || true
    echo -e "${GREEN}已清理${NC}"
fi

# 10. iOS 设备日志
echo ""
echo ">>> iOS 日志"
run_cleanup "iOS Device Logs" "$HOMELibrary/Logs/CoreSimulator" "rm -rf $HOME/Library/Logs/CoreSimulator/*"

# 11. 字体缓存
echo ""
echo ">>> 字体缓存"
run_cleanup "字体缓存" "$HOMELibrary/Caches/FontRegistry" "rm -rf $HOME/Library/Caches/FontRegistry/*"

# 12. 清理 macOS 终端历史
echo ""
echo ">>> 终端历史"
run_cleanup "Bash History" "$HOME/.bash_history" "> $HOME/.bash_history"
run_cleanup "Zsh History" "$HOME/.zsh_history" "> $HOME/.zsh_history"

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
    echo "要实际执行清理，请运行: $0"
else
    echo -e "${GREEN}清理完成！建议重启 Xcode 等应用以释放更多空间${NC}"
fi
