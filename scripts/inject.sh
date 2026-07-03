#!/bin/bash
set -e

# vibe-control 注入脚本
# 将控制体系软链接到当前项目

echo "🔧 vibe-control 注入开始..."
echo "================================"

VIBE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIBE_OUT=".vibe"

# 自托管模式（vibe-control 自身仓库）：创建软链接 vibe-control → .
if [ -f "core/AI_CONTROL.md" ] && [ ! -e "vibe-control" ]; then
    ln -sf . vibe-control
    echo "✅ vibe-control 软链接已创建"
fi

# 验证 vibe-control 可访问
if [ ! -f "vibe-control/core/AI_CONTROL.md" ]; then
    echo "❌ 未找到 vibe-control 核心文件，请确认在项目根目录执行"
    exit 1
fi

# 1. 创建 .vibe/ 目录
mkdir -p "$VIBE_OUT"

# 2. 注入规则文件 → 根目录
if [ -f "$VIBE_ROOT/rules/.cursorrules" ]; then
    ln -sf "$VIBE_ROOT/rules/.cursorrules" ".cursorrules"
    echo "✅ .cursorrules 已链接（根目录）"
fi

# 3. 生成 .vibe/README.md 清单
cat > "$VIBE_OUT/README.md" << 'VIBEMD'
# vibe-control 注入清单

本目录由 `vibe-control/scripts/inject.sh` 自动生成，**请勿手动编辑**。

## 注入文件

| 文件 | 来源 | 用途 |
|---|---|---|
| `../.cursorrules` | `vibe-control/rules/.cursorrules` | AI 行为规则（根目录） |
| `core/AI_CONTROL.md` | `vibe-control/core/AI_CONTROL.md` | 项目总控文件 |
| `core/DEPENDENCY_MAP.md` | `vibe-control/core/DEPENDENCY_MAP.md` | 模块依赖地图 |
| `core/TASK_TEMPLATE.md` | `vibe-control/core/TASK_TEMPLATE.md` | 标准任务模板 |

## IDE 配置

各 IDE 读取规则文件的方式不同，请根据使用的 IDE 配置：

| IDE | 操作 |
|---|---|
| **Cursor** | ✅ 自动生效（`.cursorrules` 在根目录） |
| **opencode CLI** | ✅ 自动生效（`.opencode/` 在根目录） |
| **GitHub Copilot** | 在项目根创建 `.github/copilot-instructions.md`，内容 `include .cursorrules` |
VIBEMD
echo "✅ $VIBE_OUT/README.md 已生成"

# 4. 加入 .gitignore
if [ -f ".gitignore" ]; then
    for entry in .vibe .cursorrules .opencode vibe-control; do
        if ! grep -q "^${entry}$" .gitignore 2>/dev/null; then
            echo "$entry" >> .gitignore
            echo "✅ .gitignore 已添加 $entry"
        fi
    done
fi

# 5. 安装 git hooks
if [ -d ".git" ]; then
    cp "$VIBE_ROOT/scripts/pre-commit" .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    cp "$VIBE_ROOT/scripts/pre-push" .git/hooks/pre-push
    chmod +x .git/hooks/pre-push
    echo "✅ pre-commit 和 pre-push 钩子已安装"
fi

# 6. 生成 opencode 配置
if [ ! -f ".opencode/opencode.json" ]; then
    mkdir -p .opencode
    cat > .opencode/opencode.json << 'OPEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    ".vibe/core/AI_CONTROL.md",
    ".vibe/core/DEPENDENCY_MAP.md",
    ".vibe/core/TASK_TEMPLATE.md"
  ],
  "skills": {
    "paths": ["vibe-control/.opencode/skills"]
  }
}
OPEOF
    echo "✅ .opencode/opencode.json 已生成"
fi

# 7. 检测项目并填充模板
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/sync-templates.sh" 2>/dev/null && echo "✅ 模板已根据项目信息填充"

echo "================================"
echo "🎉 注入完成！"
echo ""
echo "注入产物："
echo "  .cursorrules              - AI 行为规则（根目录）"
echo "  .opencode/                - opencode CLI 配置（根目录）"
echo "  $VIBE_OUT/core/           - 核心模板文件（已填充）"
echo "  $VIBE_OUT/README.md       - 注入清单"
echo ""
echo "IDE 配置见 README.md 中的 IDE 支持章节"
echo ""
echo "可用命令："
echo "  bash vibe-control/scripts/check.sh     - 运行合规检查"
echo "  bash vibe-control/scripts/sync-core.sh  - 同步核心文件"
echo "  bash vibe-control/scripts/sync-templates.sh - 重新检测并填充模板"
