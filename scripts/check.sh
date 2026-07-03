#!/bin/bash
set -e

# 异常退出时输出诊断提示（非静默吞错）
trap 'echo ""; echo "⚠️  check.sh 异常退出，建议运行: bash vibe-control/scripts/recover.sh"' ERR

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
PREFIX="vibe-control/"

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

# 检查根目录 .cursorrules 链接
if [ -f ".cursorrules" ]; then
    echo "✅ .cursorrules 存在（根目录）"
    PASS=$((PASS+1))
else
    echo "❌ .cursorrules 缺失（根目录）"
    FAIL=$((FAIL+1))
fi

# 项目边界扫描
echo "项目边界扫描..."
OUTSIDE_REFS=0
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    for file in $(git diff --cached --name-only 2>/dev/null; git diff --name-only 2>/dev/null); do
        [ ! -f "$file" ] && continue
        _dir=$(dirname "$file")
        while IFS= read -r ref; do
            [ -z "$ref" ] && continue
            resolved=$(cd "$_dir" 2>/dev/null && realpath "$ref" 2>/dev/null || echo "")
            case "$resolved" in
                "$GIT_ROOT"*) continue;;
                "") continue;;
                *) echo "❌ $file 引用项目外路径: $ref → $resolved"; OUTSIDE_REFS=1;;
            esac
        done < <(grep -oE '\.\./[a-zA-Z0-9_/.-]+' "$file" 2>/dev/null || true)
    done
fi
if [ $OUTSIDE_REFS -eq 0 ]; then
    echo "✅ 无跨项目路径引用"
    PASS=$((PASS+1))
else
    echo "   请移除跨项目路径引用，或改为相对项目内的路径"
    FAIL=$((FAIL+1))
fi

# 检查 DEPENDENCY_MAP 是否过时（仅限 vibe-control 自身仓库）
if [ -f "core/AI_CONTROL.md" ] && [ -d "scripts" ]; then
    echo "检查 DEPENDENCY_MAP 是否过时..."
    if bash "${PREFIX}scripts/generate-depmap.sh" --check > /dev/null 2>&1; then
        echo "✅ DEPENDENCY_MAP.md 与 scripts/ 结构一致"
        PASS=$((PASS+1))
    else
        echo "⚠️  DEPENDENCY_MAP.md 可能过时，请运行 bash vibe-control/scripts/generate-depmap.sh 更新"
        PASS=$((PASS+1))
    fi

    # 检查 README.md 是否覆盖所有脚本
    echo "检查 README.md 文件说明表..."
    MISSING_README=0
    for script in scripts/*.sh; do
        name=$(basename "$script")
        if [ -f "$script" ]; then
            if ! grep -q "$name" README.md 2>/dev/null; then
                echo "⚠️  $name 未在 README.md 文件说明表中记录"
                MISSING_README=1
            fi
        fi
    done
    if [ $MISSING_README -eq 0 ]; then
        echo "✅ README.md 已覆盖所有脚本"
        PASS=$((PASS+1))
    else
        echo "⚠️  README.md 可能过时，请更新文件说明表"
        PASS=$((PASS+1))
    fi

    # 零泄漏自检：验证 inject.sh 产物均在 .gitignore 中
    echo "检查 inject.sh 产物零泄漏..."
    INJECT_FILE="scripts/inject.sh"
    GITIGNORE_FILE=".gitignore"
    LEAK=0
    if [ -f "$INJECT_FILE" ] && [ -f "$GITIGNORE_FILE" ]; then
        # 从 inject.sh 提取所有 > "path" 输出路径
        # 格式: cat > "$VIBE_OUT/..." 或 cat > ".opencode/..."
        OUTPUTS=$(grep -oE '>[[:space:]]*"?(\$[A-Z_]+/)?(\.[a-z][a-zA-Z0-9_./-]*)"?' "$INJECT_FILE" 2>/dev/null | \
            sed 's/^>[[:space:]]*"//' | sed 's/"$//' | \
            sed 's/\$VIBE_OUT\//.vibe\//g' | \
            grep '^\.' | grep -v '\.gitignore' | grep -v '\.git/hooks' | sort -u)
        for f in $OUTPUTS; do
            # 取顶级目录名，检查是否在 .gitignore 中
            TOP_DIR="${f%%/*}"
            if ! grep -q "^${TOP_DIR}$" "$GITIGNORE_FILE" 2>/dev/null; then
                echo "❌ 泄漏风险: $f 由 inject.sh 生成但 $TOP_DIR/ 未在 .gitignore 中"
                LEAK=1
            fi
        done
    fi
    if [ $LEAK -eq 0 ]; then
        echo "✅ 注入产物已全部 .gitignore 覆盖"
        PASS=$((PASS+1))
    else
        echo "   请在 .gitignore 中添加对应目录"
        FAIL=$((FAIL+1))
    fi
fi

# 检查任务日志（有未提交修改时强制要求）
if git rev-parse --git-dir > /dev/null 2>&1; then
    HAS_MODS=0
    if ! git diff --quiet 2>/dev/null; then HAS_MODS=1; fi
    if ! git diff --cached --quiet 2>/dev/null; then HAS_MODS=1; fi
    if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then HAS_MODS=1; fi
    
    if [ $HAS_MODS -eq 1 ]; then
        if [ ! -d ".vibe/tasks" ] || [ -z "$(ls -A .vibe/tasks 2>/dev/null)" ]; then
            echo "❌ .vibe/tasks/ 为空 — 有未提交修改但缺少任务日志"
            echo "   必须运行: bash ${PREFIX}scripts/task-log.sh \"任务描述\""
            FAIL=$((FAIL+1))
        else
            # 检查任务日志是否已填写内容（非空模板）
            FILLED=0
            for log in .vibe/tasks/*.md; do
                [ -f "$log" ] || continue
                IMPACT=$(sed -n '/^## 影响分析/,/^## 修改计划/p' "$log" 2>/dev/null | grep -v '\-\-\-' | grep -c '^|.*[a-zA-Z0-9].*|' 2>/dev/null || echo 0)
                CHECKLIST=$(sed -n '/^## 执行核对清单/,/^## 验证结果/p' "$log" 2>/dev/null | grep -v '\-\-\-' | grep -c '^|.*[a-zA-Z0-9].*|' 2>/dev/null || echo 0)
                if [ "$IMPACT" -gt 0 ] 2>/dev/null && [ "$CHECKLIST" -gt 0 ] 2>/dev/null; then
                    FILLED=1
                    break
                fi
            done
            if [ $FILLED -eq 1 ]; then
                echo "✅ .vibe/tasks/ 存在任务日志（影响分析+核对清单已填写）"
                PASS=$((PASS+1))

                # 对齐检查：所有已修改文件必须出现在影响分析表和核对清单（✅）中
                ALL_MODS=$( {
                    git diff --cached --name-only 2>/dev/null
                    git diff --name-only 2>/dev/null
                    git ls-files --others --exclude-standard 2>/dev/null | grep -v '^\.vibe/'
                } | sort -u)
                UNREPORTED=0
                for file in $ALL_MODS; do
                    [ -f "$file" ] || continue
                    case "$file" in
                        .vibe/*|vibe-control/*) continue ;;
                    esac
                    FNAME=$(basename "$file")
                    FOUND_IMPACT=0
                    FOUND_CHECK=0
                    for log in .vibe/tasks/*.md; do
                        [ -f "$log" ] || continue
                        # 影响分析表
                        [ $FOUND_IMPACT -eq 0 ] && sed -n '/^## 影响分析/,/^## 修改计划/p' "$log" 2>/dev/null | grep -qF "$FNAME" 2>/dev/null && FOUND_IMPACT=1
                        # 核对清单（状态列必须是 ✅）
                        [ $FOUND_CHECK -eq 0 ] && sed -n '/^## 执行核对清单/,/^## 验证结果/p' "$log" 2>/dev/null | grep -v '\-\-\-' | grep '^| ✅' | grep -qF "$FNAME" 2>/dev/null && FOUND_CHECK=1
                        [ $FOUND_IMPACT -eq 1 ] && [ $FOUND_CHECK -eq 1 ] && break
                    done
                    if [ $FOUND_IMPACT -eq 0 ]; then
                        echo "❌ $file — 已修改但未出现在影响分析中"
                        UNREPORTED=1
                    fi
                    if [ $FOUND_CHECK -eq 0 ]; then
                        echo "❌ $file — 已修改但核对清单未标记 ✅"
                        UNREPORTED=1
                    fi
                done
                if [ $UNREPORTED -eq 0 ]; then
                    echo "✅ 所有修改文件已记录：影响分析 ✅ + 核对清单 ✅"
                    PASS=$((PASS+1))
                else
                    echo "   请在 .vibe/tasks/*.md 的影响分析表中补录上述文件"
                    FAIL=$((FAIL+1))
                fi
            else
                echo "❌ .vibe/tasks/ 中有日志文件，但影响分析表和核对清单未填写"
                echo "   至少填写影响分析一行 + 核对清单一行，不得留空表提交"
                FAIL=$((FAIL+1))
            fi
        fi
    fi
fi

echo "================================"
echo "检查结果: ✅ $PASS 通过 | ❌ $FAIL 失败"

# 未提交修改提示（防止 AI 跳过提交确认步骤）
if git rev-parse --git-dir > /dev/null 2>&1; then
    DIRTY=0
    git diff --quiet 2>/dev/null || DIRTY=1
    git diff --cached --quiet 2>/dev/null || DIRTY=1
    [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ] && DIRTY=1
    if [ $DIRTY -eq 1 ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⏎  请确认是否提交"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
fi

if [ $FAIL -gt 0 ]; then
    exit 1
fi
