#!/bin/bash
set -e

echo "🚦 vibe-control PR 检查"
echo "========================"

CHECK="vibe-control/scripts/check.sh"

if [ ! -f "$CHECK" ]; then
    echo "❌ 未找到 vibe-control"
    exit 1
fi

FAIL=0

# 1. 合规检查
echo ""
echo "▶ 运行合规检查..."
if bash "$CHECK"; then
    echo "✅ 合规检查通过"
else
    echo "❌ 合规检查失败"
    FAIL=1
fi

echo ""
echo "========================"
echo "▶ 任务日志摘要:"

if [ -d ".vibe/tasks" ] && [ -n "$(ls -A .vibe/tasks 2>/dev/null)" ]; then
    for log in .vibe/tasks/*.md; do
        [ -f "$log" ] || continue
        TITLE=$(head -1 "$log" 2>/dev/null | sed 's/^# //')
        MTIME=$(date -r "$log" '+%m-%d %H:%M' 2>/dev/null || echo "unk")
        IMPACT_COUNT=$(sed -n '/^## 影响分析/,/^## 修改计划/p' "$log" 2>/dev/null | grep -v '\-\-\-' | grep -c '^|.*[a-zA-Z0-9].*|' || echo 0)
        CHECK_COUNT=$(sed -n '/^## 执行核对清单/,/^## 验证结果/p' "$log" 2>/dev/null | grep -v '\-\-\-' | grep -c '^| ✅' 2>/dev/null || echo 0)
        printf "  %-50s 影响:%s  ✅:%s  %s\n" "$TITLE" "$IMPACT_COUNT" "$CHECK_COUNT" "$MTIME"
    done
    TOTAL=$(ls -1 .vibe/tasks/*.md 2>/dev/null | wc -l | tr -d ' ')
    echo "  ---"
    echo "  共 $TOTAL 个任务日志"
else
    echo "  (无任务日志)"
fi

echo ""
echo "========================"
if [ $FAIL -gt 0 ]; then
    echo "❌ PR 检查未通过"
    exit 1
else
    echo "✅ PR 检查通过，可以提交"
fi
