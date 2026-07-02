#!/bin/bash
set -e

echo "🩺 vibe-control 恢复诊断"
echo "========================"

ISSUES=0

# 检测脚本路径
if [ -f "vibe-control/scripts/inject.sh" ]; then
    INJECT="vibe-control/scripts/inject.sh"
    CHECK="vibe-control/scripts/check.sh"
    MODE="注入模式"
elif [ -f "scripts/inject.sh" ]; then
    INJECT="scripts/inject.sh"
    CHECK="scripts/check.sh"
    MODE="自托管"
else
    echo "❌ 未找到 vibe-control，请确认在项目根目录执行"
    exit 1
fi

echo "模式: $MODE"
echo ""

# 1. 检查 .vibe/ 目录
echo "▶ .vibe/ 产物检查"
if [ -d ".vibe" ]; then
    MISSING=0
    for f in core/AI_CONTROL.md core/DEPENDENCY_MAP.md core/TASK_TEMPLATE.md detect.json; do
        if [ -f ".vibe/$f" ]; then
            echo "  ✅ .vibe/$f"
        else
            echo "  ❌ .vibe/$f 缺失"
            MISSING=1
        fi
    done
    if [ $MISSING -eq 1 ]; then
        echo "  → 修复: bash $INJECT"
        ISSUES=$((ISSUES+1))
    fi
else
    echo "  ❌ .vibe/ 目录不存在"
    echo "  → 修复: bash $INJECT"
    ISSUES=$((ISSUES+1))
fi

echo ""

# 2. 检查 Git 钩子
echo "▶ Git 钩子检查"
HOOK_DIR=".git/hooks"
for hook in pre-commit pre-push; do
    if [ -f "$HOOK_DIR/$hook" ]; then
        echo "  ✅ $hook"
    else
        echo "  ❌ $hook 缺失"
        if [ -f "vibe-control/scripts/$hook" ]; then
            echo "  → 修复: cp vibe-control/scripts/$hook $HOOK_DIR/$hook && chmod +x $HOOK_DIR/$hook"
        elif [ -f "scripts/$hook" ]; then
            echo "  → 修复: cp scripts/$hook $HOOK_DIR/$hook && chmod +x $HOOK_DIR/$hook"
        fi
        ISSUES=$((ISSUES+1))
    fi
done

echo ""

# 3. 检查根目录配置
echo "▶ 根目录配置检查"
for item in .cursorrules .opencode/opencode.json; do
    if [ -f "$item" ]; then
        echo "  ✅ $item"
    else
        echo "  ❌ $item 缺失"
        echo "  → 修复: bash $INJECT"
        ISSUES=$((ISSUES+1))
    fi
done

echo ""

# 4. 检查 .gitignore
echo "▶ .gitignore 检查"
if [ -f ".gitignore" ]; then
    for entry in .vibe .cursorrules; do
        if grep -q "^\.vibe$\|^\.cursorrules$" .gitignore 2>/dev/null; then
            : # handled in loop
        else
            if ! grep -q "^$entry$" .gitignore 2>/dev/null; then
                echo "  ❌ $entry 未在 .gitignore 中"
                ISSUES=$((ISSUES+1))
            fi
        fi
    done
    if [ $ISSUES -eq 0 ] || [ "$(echo "$ISSUES" | tail -1)" = "$ISSUES" ]; then
        echo "  ✅ .vibe 和 .cursorrules 已忽略"
    fi
fi

echo ""
echo "========================"
if [ $ISSUES -gt 0 ]; then
    echo "❌ 发现 $ISSUES 个问题，请根据上述建议修复"
    exit 1
else
    echo "✅ 系统状态正常"
fi
