#!/bin/bash
set -e

# vibe-control 模板同步脚本
# 扫描目标项目 → 填充模板文件 → 生成 .vibe/core/*.md

echo "📋 正在检测项目并填充模板..."
echo "================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 模板文件始终在 vibe-control/core/
TEMPLATE_DIR="vibe-control/core"

# 1. 检测项目
bash "$SCRIPT_DIR/detect.sh"

# 2. 填充模板
bash "$SCRIPT_DIR/fill-templates.sh" ".vibe/detect.json" "$TEMPLATE_DIR" ".vibe/core"

# 3. 重新生成依赖关系图
bash "$SCRIPT_DIR/generate-depmap.sh"

# 4. 扫描项目模块依赖
bash "$SCRIPT_DIR/scan-modules.sh"

echo "================================"
echo "✅ 模板同步完成！运行 bash vibe-control/scripts/check.sh 验证"
