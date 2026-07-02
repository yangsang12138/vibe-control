#!/bin/bash
set -e

# vibe-control 核心文件同步脚本
# 更新子模块 → 刷新软链 → 重新注入

echo "🔄 正在同步 vibe-control 核心文件..."
echo "================================"

# 定位 vibe-control 根目录
if [ -f "vibe-control/scripts/check.sh" ]; then
    VIBE_ROOT="$(pwd)/vibe-control"
elif [ -f "scripts/check.sh" ]; then
    VIBE_ROOT="$(pwd)"
else
    echo "❌ 未找到 vibe-control，请在项目根目录执行"
    exit 1
fi

# 更新子模块
if [ -d ".git/modules/vibe-control" ] || [ -f ".gitmodules" ]; then
    echo "更新子模块..."
    git submodule update --remote vibe-control 2>/dev/null || echo "⏭️  子模块更新跳过"
fi

# 重新注入
bash "$VIBE_ROOT/scripts/inject.sh"

echo "================================"
echo "🎉 同步完成！"
