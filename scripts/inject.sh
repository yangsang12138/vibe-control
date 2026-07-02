#!/bin/bash
set -e

# vibe-control 注入脚本
# 将控制体系软链接到当前项目

echo "🔧 vibe-control 注入开始..."
echo "================================"

# 获取脚本所在目录的父目录（vibe-control 根目录）
VIBE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. 链接 .cursorrules
if [ -f "$VIBE_ROOT/rules/.cursorrules" ]; then
    if [ -L ".cursorrules" ] || [ ! -f ".cursorrules" ]; then
        ln -sf "$VIBE_ROOT/rules/.cursorrules" .cursorrules
        echo "✅ .cursorrules 已链接"
    else
        echo "⚠️  .cursorrules 已存在且不是软链接，跳过（请手动处理）"
    fi
    # 将 .cursorrules 加入项目 .gitignore（软链接不应被目标项目跟踪）
    if [ -f ".gitignore" ]; then
        if ! grep -q "^\.cursorrules$" .gitignore 2>/dev/null; then
            echo -e "\n# vibe-control 输出，不提交到目标仓库\n.cursorrules" >> .gitignore
            echo "✅ .gitignore 已添加 .cursorrules"
        fi
    fi
fi

# 2. 在 package.json 中添加脚本
if [ -f "package.json" ]; then
    # 使用 node 操作 JSON 以避免依赖 jq
    node -e "
        const pkg = require('./package.json');
        pkg.scripts = pkg.scripts || {};
        pkg.scripts['vibe-check'] = 'bash vibe-control/scripts/check.sh';
        pkg.scripts['vibe-update'] = 'bash vibe-control/scripts/update.sh';
        require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
    " 2>/dev/null && echo "✅ package.json 已添加 vibe-check 和 vibe-update 脚本" || echo "⚠️  package.json 更新失败，请手动添加脚本"
fi

# 3. 安装 git pre-commit 钩子
if [ -d ".git" ]; then
    cp "$VIBE_ROOT/scripts/pre-commit" .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo "✅ pre-commit 钩子已安装"
fi

# 4. 软链核心文件到项目根
for file in AI_CONTROL.md DEPENDENCY_MAP.md TASK_TEMPLATE.md; do
    src="$VIBE_ROOT/core/$file"
    dst="$file"
    if [ -f "$src" ] && [ ! -f "$dst" ]; then
        # 自托管：文件在同级 core/；被注入：文件在 vibe-control/core/
        if [ -f "vibe-control/core/$file" ]; then
            ln -sf "vibe-control/core/$file" "$dst"
        else
            ln -sf "core/$file" "$dst"
        fi
        echo "✅ $dst 已链接"
    elif [ ! -f "$src" ]; then
        echo "⚠️  $src 不存在，跳过"
    fi
done

# 5. 核心文件软链加入 .gitignore
if [ -f ".gitignore" ]; then
    for file in AI_CONTROL.md DEPENDENCY_MAP.md TASK_TEMPLATE.md; do
        if ! grep -q "^$file$" .gitignore 2>/dev/null; then
            echo "$file" >> .gitignore
        fi
    done
    echo "✅ .gitignore 已添加核心文件条目"
fi

# 6. 生成 opencode 配置（每次对话自动加载核心文件 + 注册 skill）
if [ ! -f ".opencode/opencode.json" ]; then
    mkdir -p .opencode
    # 判断：被注入模式下文件在 vibe-control/；自托管在同级
    if [ -f "vibe-control/.opencode/skills/vibe-control/SKILL.md" ]; then
        SKILL_PATH="vibe-control/.opencode/skills"
    elif [ -f ".opencode/skills/vibe-control/SKILL.md" ]; then
        SKILL_PATH=".opencode/skills"
    else
        SKILL_PATH=""
    fi
    cat > .opencode/opencode.json << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "instructions": [
    "$(if [ -f "vibe-control/core/AI_CONTROL.md" ]; then echo "vibe-control/core/AI_CONTROL.md"; else echo "core/AI_CONTROL.md"; fi)",
    "$(if [ -f "vibe-control/core/DEPENDENCY_MAP.md" ]; then echo "vibe-control/core/DEPENDENCY_MAP.md"; else echo "core/DEPENDENCY_MAP.md"; fi)",
    "$(if [ -f "vibe-control/core/TASK_TEMPLATE.md" ]; then echo "vibe-control/core/TASK_TEMPLATE.md"; else echo "core/TASK_TEMPLATE.md"; fi)"
  ]$(if [ -n "$SKILL_PATH" ]; then echo ","
    echo "  \"skills\": {"
    echo "    \"paths\": [\"$SKILL_PATH\"]"
    echo "  }"; fi)
}
EOF
    echo "✅ .opencode/opencode.json 已生成"
fi

echo "================================"
echo "🎉 注入完成！"
echo ""
echo "项目根新增软链："
echo "  AI_CONTROL.md     - 总控文件"
echo "  DEPENDENCY_MAP.md - 依赖地图"
echo "  TASK_TEMPLATE.md  - 任务模板"
echo "  .cursorrules      - AI 行为规则"
echo ""
echo "opencode 配置："
echo "  .opencode/opencode.json - 自动加载核心文件 + Skill"
echo ""
echo "可用命令："
echo "  npm run vibe-check    - 运行项目合规检查"
echo "  npm run vibe-update   - 升级 vibe-control 到最新版本"
echo "  bash vibe-control/scripts/sync-core.sh - 手动同步核心文件"
