#!/bin/bash
# vibe-control 状态查看脚本

echo "📊 vibe-control 状态"
echo "========================"

if [ ! -f "vibe-control/core/AI_CONTROL.md" ]; then
    echo "❌ 未检测到 vibe-control"
    exit 1
fi

VIBE_DIR="vibe-control"

# 模式
if [ -f "core/AI_CONTROL.md" ]; then
    echo "模式: 自托管"
else
    echo "模式: 注入模式"
fi

# 版本信息
if [ -d "$VIBE_DIR/.git" ]; then
    TAG=$(cd "$VIBE_DIR" && git describe --tags --always 2>/dev/null || echo "unknown")
    echo "版本: $TAG"
    CURRENT=$(cd "$VIBE_DIR" && git log --oneline -1 --format="%h %s" 2>/dev/null || echo "unknown")
    echo "最新提交: $CURRENT"
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

echo "========================"
echo "运行合规检查: bash vibe-control/scripts/check.sh"
