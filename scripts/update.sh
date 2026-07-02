#!/bin/bash
set -e

# vibe-control 升级脚本

echo "🔄 正在升级 vibe-control..."
echo "================================"

# 更新子模块
git submodule update --remote vibe-control
echo "✅ 子模块已更新到最新版本"

# 重新执行注入
bash vibe-control/scripts/inject.sh

echo "================================"
echo "🎉 vibe-control 已升级到最新版本"
