#!/bin/bash
set -e

# vibe-control 注入脚本
# 将控制体系软链接到当前项目

echo "🔧 vibe-control 注入开始..."
echo "================================"

VIBE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIBE_OUT=".vibe"

# 判断：被注入（子模块）还是自托管
if [ -f "vibe-control/core/AI_CONTROL.md" ]; then
    MODE="injected"
elif [ -f "core/AI_CONTROL.md" ]; then
    MODE="selfhost"
else
    echo "❌ 未找到 vibe-control 核心文件，请确认在项目根目录执行"
    exit 1
fi

# 1. 创建 .vibe/ 目录（所有注入产物集中于此）
mkdir -p "$VIBE_OUT/core"

# 2. 注入规则文件
if [ -f "$VIBE_ROOT/rules/.cursorrules" ]; then
    ln -sf "$VIBE_ROOT/rules/.cursorrules" "$VIBE_OUT/cursorrules"
    echo "✅ $VIBE_OUT/cursorrules 已链接"
fi

# 3. 注入核心模板文件
for file in AI_CONTROL.md DEPENDENCY_MAP.md TASK_TEMPLATE.md; do
    src="$VIBE_ROOT/core/$file"
    dst="$VIBE_OUT/core/$file"
    if [ -f "$src" ]; then
        if [ "$MODE" = "injected" ]; then
            ln -sf "../../vibe-control/core/$file" "$dst"
        else
            ln -sf "../../core/$file" "$dst"
        fi
        echo "✅ $dst 已链接"
    fi
done

# 4. 生成 .vibe/README.md 清单
cat > "$VIBE_OUT/README.md" << 'VIBEMD'
# vibe-control 注入清单

本目录由 `vibe-control/scripts/inject.sh` 自动生成，**请勿手动编辑**。

## 注入文件

| 文件 | 来源 | 用途 |
|---|---|---|
| `cursorrules` | `vibe-control/rules/.cursorrules` | AI 行为规则 |
| `core/AI_CONTROL.md` | `vibe-control/core/AI_CONTROL.md` | 项目总控文件 |
| `core/DEPENDENCY_MAP.md` | `vibe-control/core/DEPENDENCY_MAP.md` | 模块依赖地图 |
| `core/TASK_TEMPLATE.md` | `vibe-control/core/TASK_TEMPLATE.md` | 标准任务模板 |

## IDE 配置

各 IDE 读取规则文件的方式不同，请根据使用的 IDE 配置：

| IDE | 操作 |
|---|---|
| **Cursor** | 打开 Settings → Rules → User Rules / Project Rules，添加 `.vibe/cursorrules` |
| **opencode CLI** | 无需配置，`.opencode/` 已自动注册 |
| **GitHub Copilot** | 在项目根创建 `.github/copilot-instructions.md`，内容 `include .vibe/cursorrules` |
VIBEMD
echo "✅ $VIBE_OUT/README.md 已生成"

# 5. 加入 .gitignore
if [ -f ".gitignore" ]; then
    if ! grep -q "^\.vibe$" .gitignore 2>/dev/null; then
        echo ".vibe" >> .gitignore
        echo "✅ .gitignore 已更新"
    fi
fi

# 6. 在 package.json 中添加脚本
if [ -f "package.json" ]; then
    node -e "
        const pkg = require('./package.json');
        pkg.scripts = pkg.scripts || {};
        pkg.scripts['vibe-check'] = 'bash vibe-control/scripts/check.sh';
        pkg.scripts['vibe-update'] = 'bash vibe-control/scripts/update.sh';
        require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
    " 2>/dev/null && echo "✅ package.json 已添加 vibe-check 和 vibe-update 脚本" || echo "⚠️  package.json 更新失败"
fi

# 7. 安装 git pre-commit 钩子
if [ -d ".git" ]; then
    cp "$VIBE_ROOT/scripts/pre-commit" .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo "✅ pre-commit 钩子已安装"
fi

# 8. 生成 opencode 配置
if [ ! -f ".opencode/opencode.json" ]; then
    mkdir -p .opencode
    if [ "$MODE" = "injected" ]; then
        SKILL_PATH="vibe-control/.opencode/skills"
        INSTR_PREFIX="vibe-control/core"
    else
        SKILL_PATH=".opencode/skills"
        INSTR_PREFIX="core"
    fi
    cat > .opencode/opencode.json << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    "$INSTR_PREFIX/AI_CONTROL.md",
    "$INSTR_PREFIX/DEPENDENCY_MAP.md",
    "$INSTR_PREFIX/TASK_TEMPLATE.md"
  ],
  "skills": {
    "paths": ["$SKILL_PATH"]
  }
}
EOF
    echo "✅ .opencode/opencode.json 已生成"
fi

echo "================================"
echo "🎉 注入完成！"
echo ""
echo "注入产物（$VIBE_OUT/）："
echo "  $VIBE_OUT/cursorrules      - AI 行为规则"
echo "  $VIBE_OUT/core/              - 核心模板文件"
echo "  $VIBE_OUT/README.md         - 注入清单"
echo ""
echo "IDE 配置见 README.md 中的 IDE 支持章节"
echo ""
echo "可用命令："
echo "  npm run vibe-check          - 运行合规检查"
echo "  npm run vibe-update         - 升级 vibe-control"
echo "  bash vibe-control/scripts/sync-core.sh - 同步核心文件"
