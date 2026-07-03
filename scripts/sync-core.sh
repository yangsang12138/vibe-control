#!/bin/bash
set -e

# vibe-control 核心文件同步脚本
# 拉取最新代码 → 重新注入

echo "🔄 正在同步 vibe-control 核心文件..."
echo "================================"

VIBE_ROOT="$(pwd)/vibe-control"

if [ ! -f "$VIBE_ROOT/scripts/check.sh" ]; then
    echo "❌ 未找到 vibe-control，请在项目根目录执行"
    exit 1
fi

# 自托管模式：vibe-control 是 symlink → 直接 git pull 真实仓库
if [ -L "$VIBE_ROOT" ]; then
    echo "自托管模式，更新主仓库..."
    git pull || { echo "❌ 拉取失败，请检查网络"; exit 1; }
    echo "✅ 主仓库已更新"
else
    # 普通项目：全量重新克隆（不保留嵌套 .git）
    REPO_URL="https://github.com/yangsang12138/vibe-control.git"
    echo "重新克隆 vibe-control..."
    rm -rf "$VIBE_ROOT"
    git clone "$REPO_URL" "$VIBE_ROOT" || { echo "❌ 克隆失败，请检查网络"; exit 1; }
    rm -rf "$VIBE_ROOT/.git"
    echo "✅ 已更新并清除内部 .git"
fi

# 重新注入
bash "$VIBE_ROOT/scripts/inject.sh"

echo "================================"
echo "🎉 同步完成！"
