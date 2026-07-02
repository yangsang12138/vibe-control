#!/bin/bash
set -e

# vibe-control 合规检查脚本

PASS=0
FAIL=0

echo "🔍 vibe-control 合规检查"
echo "================================"

# 检查 TypeScript
if [ -f "tsconfig.json" ]; then
    echo "检查 TypeScript 类型..."
    if npx tsc --noEmit 2>/dev/null; then
        echo "✅ TypeScript 类型检查通过"
        PASS=$((PASS+1))
    else
        echo "❌ TypeScript 类型检查失败"
        FAIL=$((FAIL+1))
    fi
else
    echo "⏭️  跳过 TypeScript 检查（无 tsconfig.json）"
fi

# 检查 ESLint
if [ -f "eslint.config.js" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ]; then
    echo "检查 ESLint..."
    if npm run lint --silent 2>/dev/null; then
        echo "✅ ESLint 检查通过"
        PASS=$((PASS+1))
    else
        echo "❌ ESLint 检查失败"
        FAIL=$((FAIL+1))
    fi
else
    echo "⏭️  跳过 ESLint 检查（无配置文件）"
fi

# 检查控制文件是否存在
echo "检查控制文件完整性..."
for file in "vibe-control/core/AI_CONTROL.md" "vibe-control/core/DEPENDENCY_MAP.md" "vibe-control/core/TASK_TEMPLATE.md" "vibe-control/rules/.cursorrules"; do
    if [ -f "$file" ]; then
        echo "✅ $file 存在"
        PASS=$((PASS+1))
    else
        echo "❌ $file 缺失"
        FAIL=$((FAIL+1))
    fi
done

# 检查 .cursorrules 链接
if [ -L ".cursorrules" ]; then
    echo "✅ .cursorrules 正确链接"
    PASS=$((PASS+1))
elif [ -f ".cursorrules" ]; then
    echo "⚠️  .cursorrules 存在但不是软链接"
else
    echo "❌ .cursorrules 缺失"
    FAIL=$((FAIL+1))
fi

echo "================================"
echo "检查结果: ✅ $PASS 通过 | ❌ $FAIL 失败"

if [ $FAIL -gt 0 ]; then
    exit 1
fi
