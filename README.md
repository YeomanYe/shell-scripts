# 磁盘清理脚本

本项目包含两个磁盘清理脚本，分别适用于树莓派（Linux）和 macOS 系统。

## 目录

- [树莓派清理脚本 (cleanup-pi.sh)](#树莓派清理脚本-cleanup-pish)
- [macOS 清理脚本 (cleanup-macos.sh)](#macos-清理脚本-cleanup-macossh)

---

# 树莓派清理脚本 (cleanup-pi.sh)

一个适用于树莓派家庭服务器的通用磁盘空间清理工具。

### 功能特性

- **交互式菜单** - 方便选择多个清理模块
- **命令行支持** - 适合自动化任务（crontab）
- **预览模式** - 清理前显示将删除的内容和大小
- **安全确认** - 执行前显示汇总，确认后开始清理

### 清理模块

| 编号 | 模块 | 说明 |
|------|------|------|
| 1 | APT 缓存 | 清理 apt-get install 后的缓存 |
| 2 | 日志文件 | 清理系统日志（保留最近7天） |
| 3 | 临时文件 | 清理 /tmp、/var/tmp |
| 4 | 缩略图缓存 | 清理缩略图缓存 |
| 5 | Docker | 清理 dangling 镜像、停止的容器（可选模块） |
| 6 | npm/yarn/pnpm | 清理 node 包缓存（可选模块） |
| 7 | pip | 清理 python 包缓存（可选模块） |

### 使用方式

#### 交互式菜单

```bash
./cleanup-pi.sh
```

运行后显示菜单，输入数字切换选择，回车确认执行。

#### 命令行参数

```bash
# 清理 APT 缓存
./cleanup-pi.sh --apt

# 清理日志文件
./cleanup-pi.sh --logs

# 清理临时文件
./cleanup-pi.sh --temp

# 清理缩略图缓存
./cleanup-pi.sh --thumbnails

# 清理 Docker (可选)
./cleanup-pi.sh --docker

# 清理 npm/yarn/pnpm (可选)
./cleanup-pi.sh --npm

# 清理 pip (可选)
./cleanup-pi.sh --pip

# 全部清理
./cleanup-pi.sh --all

# 多个模块组合
./cleanup-pi.sh --apt --logs --temp

# 预览模式
./cleanup-pi.sh --dry-run --all

# 查看磁盘使用情况
./cleanup-pi.sh --disk

# 显示帮助
./cleanup-pi.sh --help
```

### 使用示例

#### 场景一：日常清理

```bash
# 预览要清理的内容
./cleanup-pi.sh --dry-run --apt --logs --temp

# 确认后执行清理
./cleanup-pi.sh --apt --logs --temp
```

#### 场景二：清理 Docker 环境

```bash
# 清理所有未使用的 Docker 资源
./cleanup-pi.sh --docker
```

#### 场景三：清理开发环境

```bash
# 清理 node 和 python 包缓存
./cleanup-pi.sh --npm --pip
```

#### 场景四：定时任务

编辑 crontab：

```bash
# 每周日凌晨 3 点自动清理
0 3 * * 0 /path/to/cleanup-pi.sh --all --dry-run >> /var/log/cleanup.log 2>&1
```

### 权限说明

部分清理操作需要 sudo 权限：

- APT 缓存清理
- 系统日志清理

首次运行时会提示输入密码。

### 注意事项

1. **预览模式** - 建议先使用 `--dry-run` 预览要清理的内容
2. **日志保留** - 日志文件默认保留最近7天
3. **临时文件** - 只清理7天未访问的临时文件
4. **Docker** - 清理前请确认没有正在运行的容器

### 系统要求

- Raspberry Pi OS / Ubuntu / Debian
- Bash 4.0+
- 可选：Docker（需要清理 Docker 时）
- 可选：npm/yarn/pnpm（需要清理 node 缓存时）
- 可选：pip（需要清理 python 缓存时）

---

# macOS 清理脚本 (cleanup-macos.sh)

一个适用于 macOS 系统的磁盘空间清理工具。

### 清理模块

| 编号 | 模块 | 说明 |
|------|------|------|
| 1 | 废纸篓 | 清空废纸篓 |
| 2 | Xcode | 清理 DerivedData、Archives、SPM 缓存、CoreSimulator 缓存 |
| 3 | Node.js | 清理 npm、yarn 缓存 |
| 4 | CocoaPods | 清理 CocoaPods 缓存 |
| 5 | Carthage | 清理 Carthage 缓存 |
| 6 | Homebrew | 清理 Homebrew 缓存 |
| 7 | 系统日志 | 清理系统日志、崩溃报告 |
| 8 | 临时文件 | 清理系统临时文件、用户临时文件 |
| 9 | 系统缓存 | 清理用户缓存目录 |
| 10 | iOS 日志 | 清理 iOS 设备日志 |
| 11 | 字体缓存 | 清理字体缓存 |
| 12 | 终端历史 | 清理 Bash 和 Zsh 历史记录 |

### 使用方式

```bash
# 执行清理
./cleanup-macos.sh

# 预览模式（仅显示要清理的内容，不实际删除）
./cleanup-macos.sh --dry-run
```

### 多选格式

脚本支持多种选择方式：

| 格式 | 示例 | 说明 |
|------|------|------|
| 空格分隔 | `1 3 5` | 选择第1、3、5项 |
| 逗号分隔 | `1,3,5` | 选择第1、3、5项 |
| 范围选择 | `1-5` | 选择第1到第5项 |
| 混合模式 | `1-3,5,7-9` | 选择第1-3项、第5项、第7-9项 |
| 全部选择 | `a` | 选择所有项目 |

### 使用示例

#### 预览要清理的内容

```bash
./cleanup-macos.sh --dry-run
```

输出示例：

```
=== Dry Run 模式 - 不会实际删除任何文件 ===
清理 废纸篓... 待删除: 1.2GB
清理 DerivedData... 待删除: 3.5GB
...
```

#### 执行清理

```bash
./cleanup-macos.sh
```

脚本会依次清理各个模块，清理完成后显示磁盘使用情况。

### 注意事项

1. **Xcode** - 清理后可能需要重新编译项目
2. **Homebrew** - 需要安装 Homebrew
3. **废纸篓** - 删除后无法恢复，请确认后再运行

### 系统要求

- macOS
- Bash 4.0+
- 可选：Xcode（需要清理 Xcode 缓存时）
- 可选：Homebrew（需要清理 Homebrew 缓存时）
- 可选：npm/yarn（需要清理 node 缓存时）
