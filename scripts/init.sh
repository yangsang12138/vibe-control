#!/bin/bash
set -e

# vibe-control 一键初始化脚本
# 用法：bash vibe-control/scripts/init.sh [项目根目录]

REPO_URL="${REPO_URL:-https://github.com/yangsang12138/vibe-control.git}"
TARGET_DIR="${1:-.}"

echo "🔧 vibe-control 初始化开始..."
echo "================================"

cd "$TARGET_DIR"

# 判断是否已在 vibe-control 自身仓库
if [ -f "core/AI_CONTROL.md" ]; then
    echo "⏭️  检测到 vibe-control 自身仓库，跳过克隆"
    VIBE_ROOT="$(pwd)"
else
    if [ -d "vibe-control/.git" ]; then
        echo "⏭️  vibe-control 已存在"
    else
        echo "克隆 vibe-control..."
        git clone "$REPO_URL" vibe-control
    fi
    VIBE_ROOT="$(pwd)/vibe-control"
fi

# inject.sh 会处理全部：软链 .cursorrules 和核心文件、添加脚本、安装钩子、更新 .gitignore
bash "$VIBE_ROOT/scripts/inject.sh"

echo "================================"
echo "🎉 初始化完成！"
echo ""
echo "下一步：编辑 .vibe/core/AI_CONTROL.md 替换 {{占位符}} 为项目实际值"
