#!/bin/bash
set -e

# vibe-control 模板同步脚本
# 扫描目标项目 → 填充模板文件 → 生成 .vibe/core/*.md

echo "📋 正在检测项目并填充模板..."
echo "================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 检测项目
bash "$SCRIPT_DIR/detect.sh"

# 2. 填充模板
bash "$SCRIPT_DIR/fill-templates.sh"

echo "================================"
echo "✅ 模板同步完成！运行 bash vibe-control/scripts/check.sh 验证"
