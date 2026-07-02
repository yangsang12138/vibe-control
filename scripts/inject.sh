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

echo "================================"
echo "🎉 注入完成！"
echo ""
echo "可用命令："
echo "  npm run vibe-check    - 运行项目合规检查"
echo "  npm run vibe-update   - 升级 vibe-control 到最新版本"
echo ""
echo "AI 协作文件："
echo "  core/AI_CONTROL.md    - 总控文件（贴给 AI）"
echo "  core/TASK_TEMPLATE.md - 任务模板（复制填写）"
echo "  core/DEPENDENCY_MAP.md - 依赖地图（修改前必查）"
