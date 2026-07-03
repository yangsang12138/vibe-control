#!/bin/bash
set -e

# vibe-control 项目模块依赖扫描器
# 读取 .vibe/detect.json，根据项目类型自动解析源码 import 关系
# 生成 Mermaid 依赖图 + 依赖矩阵表格，写入 .vibe/core/DEPENDENCY_MAP.md 的 PROJECT_DEPS 区

DETECT_FILE="${1:-.vibe/detect.json}"
DEP_MAP_FILE="${2:-.vibe/core/DEPENDENCY_MAP.md}"

PROJECT_TYPE=$(grep '"PROJECT_TYPE"' "$DETECT_FILE" 2>/dev/null | sed 's/.*: *"\(.*\)".*/\1/' || echo "Unknown")

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
DEPS_FILE="$TMP_DIR/deps"
MODULES_FILE="$TMP_DIR/modules"
CONTENT_FILE="$TMP_DIR/content"

> "$DEPS_FILE"
> "$MODULES_FILE"
> "$CONTENT_FILE"

sanitize_id() {
    echo "$1" | sed 's/[^a-zA-Z0-9_]/_/g'
}

# ============ Python 解析器 ============

resolve_python_import() {
    local mod_path="$1"
    local dir="$2"  # directory of the importing file, for relative imports

    # Relative import: .module or ..module
    case "$mod_path" in
        .*)
            local depth=0
            local rest="$mod_path"
            while [ "${rest:0:1}" = "." ]; do
                rest="${rest:1}"
                depth=$((depth + 1))
            done
            local base="$dir"
            local i=1
            while [ $i -lt $depth ]; do
                base=$(dirname "$base")
                i=$((i + 1))
            done
            local rel_file="${base}/${rest}.py"
            local rel_init="${base}/${rest}/__init__.py"
            [ -f "$rel_file" ] && echo "$rel_file" && return 0
            [ -f "$rel_init" ] && echo "$rel_init" && return 0
            return 0
            ;;
    esac

    # Absolute import: foo.bar.baz → foo/bar/baz.py or foo/bar/baz/__init__.py
    local file_path="${mod_path//.//}.py"
    local init_path="${mod_path//./\/}/__init__.py"
    [ -f "$file_path" ] && echo "$file_path" && return 0
    [ -f "$init_path" ] && echo "$init_path" && return 0
    return 0
}

scan_python() {
    echo "扫描 Python import 关系..."
    local found=0

    while IFS= read -r file; do
        relpath="${file#./}"
        dir=$(dirname "$relpath")
        while IFS= read -r line; do
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
            [ -z "$trimmed" ] && continue
            [[ "$trimmed" == \#* ]] && continue

            # "import X, Y, Z" or "import X.Y.Z"
            if [[ "$trimmed" =~ ^import[[:space:]]+([a-zA-Z_.]+) ]]; then
                body="${trimmed#import }"
                body=$(echo "$body" | sed 's/#.*//')  # strip comments
                IFS=',' read -ra parts <<< "$body"
                for mod in "${parts[@]}"; do
                    mod=$(echo "$mod" | tr -d '[:space:]')
                    [ -z "$mod" ] && continue
                    resolved=$(resolve_python_import "$mod" "$dir")
                    [ -n "$resolved" ] && echo "$relpath:$resolved" >> "$DEPS_FILE" && found=1
                done
            fi

            # "from X.Y.Z import A, B"
            if [[ "$trimmed" =~ ^from[[:space:]]+([a-zA-Z_.]+)[[:space:]]+import ]]; then
                body="${trimmed#from }"
                mod_path="${body%% import*}"
                mod_path=$(echo "$mod_path" | tr -d '[:space:]')
                [ -z "$mod_path" ] && continue
                resolved=$(resolve_python_import "$mod_path" "$dir")
                [ -n "$resolved" ] && echo "$relpath:$resolved" >> "$DEPS_FILE" && found=1
            fi
        done < "$file"
    done < <(find . -name "*.py" \
        -not -path "./vibe-control/*" \
        -not -path "./.vibe/*" \
        -not -path "./.git/*" \
        -not -path "./venv/*" \
        -not -path "./.venv/*" \
        -not -path "./__pycache__/*" \
        -not -path "*/__pycache__/*" \
        -not -path "./node_modules/*" \
        2>/dev/null)

    return $found
}

# ============ JS/TS 解析器 ============

scan_js() {
    echo "扫描 JS/TS import 关系..."
    local found=0

    while IFS= read -r file; do
        relpath="${file#./}"
        dir=$(dirname "$relpath")
        while IFS= read -r line; do
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
            [ -z "$trimmed" ] && continue
            [[ "$trimmed" == \* ]] && continue

            # import ... from './path'  or  import ... from '../path'
            if [[ "$trimmed" =~ from[[:space:]]+[\'\"](\.[^\"\']+)[\"\'] ]]; then
                import_path="${BASH_REMATCH[1]}"
                base_path="$dir/$import_path"
                for ext in "" .js .ts .tsx .jsx; do
                    [ -f "${base_path}${ext}" ] && resolved="${base_path}${ext}" && break
                done
                [ -z "$resolved" ] && [ -f "${base_path}/index.js" ] && resolved="${base_path}/index.js"
                [ -z "$resolved" ] && [ -f "${base_path}/index.ts" ] && resolved="${base_path}/index.ts"
                if [ -n "$resolved" ]; then
                    echo "$relpath:${resolved#./}" >> "$DEPS_FILE" && found=1
                fi
            fi
        done < "$file"
    done < <(find . -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" \
        -not -path "./vibe-control/*" \
        -not -path "./.vibe/*" \
        -not -path "./.git/*" \
        -not -path "./node_modules/*" \
        -not -path "./dist/*" \
        -not -path "./build/*" \
        2>/dev/null)

    return $found
}

# ============ Bash 解析器 ============

scan_bash() {
    echo "扫描 Bash 脚本依赖..."
    local found=0

    while IFS= read -r file; do
        relpath="${file#./}"
        # Only scan target project scripts, skip vibe-control itself
        [[ "$relpath" == vibe-control/* ]] && continue
        [[ "$relpath" == .vibe/* ]] && continue

        while IFS= read -r line; do
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
            if [[ "$trimmed" =~ bash[[:space:]]+\"?([a-zA-Z0-9_/.-]+\.sh)\"? ]]; then
                target="${BASH_REMATCH[1]}"
                [ -f "$target" ] && echo "$relpath:$target" >> "$DEPS_FILE" && found=1
            fi
        done < "$file"
    done < <(find . -name "*.sh" \
        -not -path "./vibe-control/*" \
        -not -path "./.vibe/*" \
        -not -path "./.git/*" \
        2>/dev/null)

    return $found
}

# ============ 依赖内容生成 ============

generate_content() {
    if [ ! -s "$DEPS_FILE" ]; then
        echo "未检测到模块间依赖关系。"
        return 1
    fi

    # 路径归一化：通过 realpath 消除 symlink 别名，去重
    {
        > "$TMP_DIR/deps_norm"
        while IFS=: read -r src dst; do
            src_real=$(realpath "$src" 2>/dev/null || echo "$src")
            dst_real=$(realpath "$dst" 2>/dev/null || echo "$dst")
            src_real="${src_real#$(pwd)/}"
            dst_real="${dst_real#$(pwd)/}"
            [ "$src_real" != "$dst_real" ] && echo "$src_real:$dst_real" >> "$TMP_DIR/deps_norm"
        done < "$DEPS_FILE"
        sort -u "$TMP_DIR/deps_norm" -o "$DEPS_FILE"
    }

    # 收集所有模块
    while IFS=: read -r src dst; do
        echo "$src" >> "$MODULES_FILE"
        echo "$dst" >> "$MODULES_FILE"
    done < "$DEPS_FILE"
    sort -u "$MODULES_FILE" -o "$MODULES_FILE"

    # 生成 Mermaid 图
    {
        echo '```mermaid'
        echo 'graph TD'
        while IFS= read -r mod; do
            id="$(sanitize_id "$mod")"
            label="$mod"
            echo "    m_${id}[${label}]"
        done < "$MODULES_FILE"
        while IFS=: read -r src dst; do
            src_id="m_$(sanitize_id "$src")"
            dst_id="m_$(sanitize_id "$dst")"
            echo "    ${src_id} --> ${dst_id}"
        done < "$DEPS_FILE"
        echo '```'
    } > "$TMP_DIR/mermaid"

    # 生成依赖矩阵表格
    {
        echo '| 模块 | 导入 | 被导入 | 影响程度 |'
        echo '|---|---|---|---|'
        while IFS= read -r mod; do
            # 该模块导入了谁
            imports=$(grep "^${mod}:" "$DEPS_FILE" | cut -d: -f2 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            # 谁导入了该模块
            imported_by=$(grep ":${mod}$" "$DEPS_FILE" | cut -d: -f1 | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
            # 影响程度
            count=$(grep -c ":${mod}$" "$DEPS_FILE" 2>/dev/null || echo 0)
            [ "$count" -ge 3 ] 2>/dev/null && impact="高" || [ "$count" -ge 1 ] 2>/dev/null && impact="中" || impact="低"
            echo "| $mod | ${imports:--} | ${imported_by:--} | $impact |"
        done < "$MODULES_FILE"
    } > "$TMP_DIR/table"

    # 合并
    {
        echo ""
        echo "## 项目模块依赖"
        echo ""
        echo "> 以下由 \`scan-modules.sh\` 根据源码 \`import\` 语句自动生成。"
        echo "> 每次运行 \`sync-templates.sh\` 时刷新。如需添加注释或说明，写在此提示之后即可。"
        echo ""
        echo "### 模块依赖图"
        echo ""
        cat "$TMP_DIR/mermaid"
        echo ""
        echo "### 模块依赖表"
        echo ""
        cat "$TMP_DIR/table"
    } > "$CONTENT_FILE"

    return 0
}

# ============ 写入 DEPENDENCY_MAP.md ============

inject_content() {
    if [ ! -f "$DEP_MAP_FILE" ]; then
        echo "⚠️  $DEP_MAP_FILE 不存在，跳过项目模块扫描"
        return 1
    fi

    START_LINE=$(grep -n '<!-- PROJECT_DEPS_START -->' "$DEP_MAP_FILE" | head -1 | cut -d: -f1)
    END_LINE=$(grep -n '<!-- PROJECT_DEPS_END -->' "$DEP_MAP_FILE" | head -1 | cut -d: -f1)

    if [ -z "$START_LINE" ] || [ -z "$END_LINE" ]; then
        echo "⚠️  $DEP_MAP_FILE 缺少 PROJECT_DEPS 标记，无法注入"
        return 1
    fi

    head -n "$START_LINE" "$DEP_MAP_FILE" > "${DEP_MAP_FILE}.tmp"
    cat "$CONTENT_FILE" >> "${DEP_MAP_FILE}.tmp"
    tail -n +$((END_LINE)) "$DEP_MAP_FILE" >> "${DEP_MAP_FILE}.tmp"
    mv "${DEP_MAP_FILE}.tmp" "$DEP_MAP_FILE"

    echo "✅ 项目模块依赖已更新"
}

# ============ 主逻辑 ============

echo ""

case "$PROJECT_TYPE" in
    "Python Application")
        if ! scan_python; then
            echo "  未发现 Python import 关系"
        fi
        ;;
    "Web Application (Next.js)"|"Static Site (Astro)"|"Frontend App (Vite)")
        if ! scan_js; then
            echo "  未发现 JS/TS import 关系"
        fi
        ;;
    "Bash Tool")
        if ! scan_bash; then
            echo "  未发现 Bash 脚本依赖（目标项目自身）"
        fi
        ;;
    *)
        echo "⏭️  未知项目类型 ($PROJECT_TYPE)，跳过模块扫描"
        exit 0
        ;;
esac

if generate_content; then
    inject_content
else
    echo "⏭️  未检测到足够的模块依赖信息"
fi
