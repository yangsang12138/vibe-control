#!/bin/bash
# vibe-control 状态查看脚本

echo "📊 vibe-control 状态"
echo "========================"

# 检测模式
if [ -f "vibe-control/core/AI_CONTROL.md" ]; then
    MODE="注入模式（子模块）"
    PREFIX="vibe-control/"
    VIBE_DIR="vibe-control"
elif [ -f "core/AI_CONTROL.md" ]; then
    MODE="自托管"
    PREFIX=""
    VIBE_DIR="."
else
    echo "❌ 未检测到 vibe-control"
    exit 1
fi
echo "模式: $MODE"

# 版本信息
if [ -d "$VIBE_DIR/.git" ]; then
    TAG=$(cd "$VIBE_DIR" && git describe --tags --always 2>/dev/null || echo "unk")
    echo "版本: $TAG"
fi

# 子模块信息
if [ "$MODE" = "注入模式（子模块）" ]; then
    if git submodule status vibe-control >/dev/null 2>&1; then
        echo "子模块: $(git submodule status vibe-control 2>/dev/null | sed 's/^ //' | awk '{print $1}')"
    fi
fi

echo "------------------------"

# .vibe/ 产物清单
echo "注入产物 (.vibe/):"
if [ -d ".vibe" ]; then
    for item in .vibe/* .vibe/core/*; do
        if [ -f "$item" ]; then
            MTIME=$(date -r "$item" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
            echo "  $item  [$MTIME]"
        fi
    done 2>/dev/null
    # 任务日志
    TASK_COUNT=$(ls -1 .vibe/tasks/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TASK_COUNT" -gt 0 ] 2>/dev/null; then
        echo "  .vibe/tasks/ (${TASK_COUNT} 个日志)"
    fi
else
    echo "  (空 — 尚未注入)"
fi

echo "------------------------"

# 配置文件（根目录）
echo "根目录配置:"
for item in .cursorrules .opencode/opencode.json .git/hooks/pre-commit; do
    if [ -f "$item" ]; then
        echo "  ✅ $item"
    fi
done

# package.json 脚本
if [ -f "package.json" ]; then
    HAS_CHECK=$(node -e "try{const p=require('./package.json');console.log(p.scripts&&p.scripts['vibe-check']?'yes':'')}catch(e){}" 2>/dev/null)
    HAS_UPDATE=$(node -e "try{const p=require('./package.json');console.log(p.scripts&&p.scripts['vibe-update']?'yes':'')}catch(e){}" 2>/dev/null)
    if [ "$HAS_CHECK" = "yes" ]; then
        echo "  npm run vibe-check   → bash vibe-control/scripts/check.sh"
    fi
    if [ "$HAS_UPDATE" = "yes" ]; then
        echo "  npm run vibe-update  → bash vibe-control/scripts/update.sh"
    fi
fi

echo "========================"
echo "运行合规检查: bash ${PREFIX}scripts/check.sh"
