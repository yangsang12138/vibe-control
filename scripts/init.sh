#!/bin/bash
set -e

# vibe-control 一键初始化脚本
# 可直接通过 curl 管道执行：
#   bash <(curl -fsSL https://raw.githubusercontent.com/yangsang12138/vibe-control/main/scripts/init.sh)
#
# 或在已添加子模块的项目中执行：
#   bash vibe-control/scripts/init.sh

REPO_URL="${REPO_URL:-https://github.com/yangsang12138/vibe-control.git}"
TARGET_DIR="${1:-.}"

echo "🔧 vibe-control 初始化开始..."
echo "================================"

cd "$TARGET_DIR"

# 判断是否已在 vibe-control 自身仓库内
if [ -f "core/AI_CONTROL.md" ] && [ ! -d "vibe-control" ]; then
    echo "⏭️  检测到 vibe-control 自身仓库，跳过子模块添加"
    VIBE_ROOT="$(pwd)"
else
    if [ -d "vibe-control/.git" ]; then
        echo "⏭️  vibe-control 子模块已存在"
    else
        echo "添加子模块..."
        git submodule add "$REPO_URL" vibe-control
    fi
    VIBE_ROOT="$(pwd)/vibe-control"
fi

# inject.sh 会处理全部：软链 .cursorrules 和核心文件、添加脚本、安装钩子、更新 .gitignore
bash "$VIBE_ROOT/scripts/inject.sh"

echo "================================"
echo "🎉 初始化完成！"
echo ""
echo "下一步：编辑 AI_CONTROL.md 替换 {{占位符}} 为项目实际值"
