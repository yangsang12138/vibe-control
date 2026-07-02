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

# 敏感信息扫描
echo "敏感信息扫描..."
PATTERNS=(
    "sk-[a-zA-Z0-9]{20,}"      # OpenAI/LLM API key
    "AKIA[0-9A-Z]{16}"         # AWS Access Key
    "ghp_[a-zA-Z0-9]{36}"      # GitHub Personal Access Token
    "gho_[a-zA-Z0-9]{36}"      # GitHub OAuth Token
    "ghu_[a-zA-Z0-9]{36}"      # GitHub User Token
    "ghs_[a-zA-Z0-9]{36}"      # GitHub Server Token
    "glpat-[a-zA-Z0-9\-]{20,}" # GitLab Personal Access Token
    "(password|secret|token|api[_-]?key)\s*[:=]\s*[\"'][^\"']{4,}[\"']" # 通用敏感赋值
)
HAS_SECRET=0
# 排除 vibe-control 自身目录、node_modules、.git
EXCLUDE_DIRS="vibe-control|node_modules|\.git|dist|build|coverage"

# 使用 grep 逐个模式检查
for pattern in "${PATTERNS[@]}"; do
    if command -v ggrep &> /dev/null; then
        MATCHES=$(grep -rInE --exclude-dir={vibe-control,node_modules,.git,dist,build,coverage} "$pattern" . 2>/dev/null || true)
    else
        MATCHES=$(grep -rInE "$pattern" --exclude-dir=vibe-control --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=coverage . 2>/dev/null || true)
    fi
    if [ -n "$MATCHES" ]; then
        echo "❌ 发现疑似敏感信息:"
        echo "$MATCHES" | while read -r line; do
            # 只输出文件名和行号，不输出内容避免二次泄漏
            file=$(echo "$line" | cut -d: -f1)
            lineno=$(echo "$line" | cut -d: -f2)
            echo "   $file:$lineno"
        done
        HAS_SECRET=1
    fi
done

if [ $HAS_SECRET -eq 0 ]; then
    echo "✅ 未发现敏感信息泄漏"
    PASS=$((PASS+1))
else
    FAIL=$((FAIL+1))
fi
# 自动检测：在 vibe-control 自身仓库还是被注入项目
if [ -f "core/AI_CONTROL.md" ] && [ ! -d "vibe-control" ]; then
    PREFIX=""
else
    PREFIX="vibe-control/"
fi

echo "检查控制文件完整性..."
for file in "core/AI_CONTROL.md" "core/DEPENDENCY_MAP.md" "core/TASK_TEMPLATE.md" "rules/.cursorrules"; do
    if [ -f "${PREFIX}${file}" ]; then
        echo "✅ ${PREFIX}${file} 存在"
        PASS=$((PASS+1))
    else
        echo "❌ ${PREFIX}${file} 缺失"
        FAIL=$((FAIL+1))
    fi
done

# 检查 .vibe/cursorrules 链接
if [ -f ".vibe/cursorrules" ]; then
    echo "✅ .vibe/cursorrules 存在"
    PASS=$((PASS+1))
else
    echo "❌ .vibe/cursorrules 缺失"
    FAIL=$((FAIL+1))
fi

echo "================================"
echo "检查结果: ✅ $PASS 通过 | ❌ $FAIL 失败"

if [ $FAIL -gt 0 ]; then
    exit 1
fi
