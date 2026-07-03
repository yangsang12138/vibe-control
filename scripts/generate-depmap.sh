#!/bin/bash
set -e

# vibe-control 依赖关系图自动生成脚本
# 扫描 scripts/ 中所有脚本的调用/读写/安装关系，生成 Mermaid 图、依赖矩阵、修改检查清单
# 用法: bash scripts/generate-depmap.sh [--check]
#   --check  仅检查是否有变化，不写入文件（用于 check.sh 集成）

VIBE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$VIBE_ROOT/scripts"
CORE_DIR="$VIBE_ROOT/core"
DEPMAP_FILE="$CORE_DIR/DEPENDENCY_MAP.md"
SKILL_FILE="$VIBE_ROOT/.opencode/skills/vibe-control/SKILL.md"

CHECK_MODE=false
[[ "$1" == "--check" ]] && CHECK_MODE=true

# 临时文件（bash 3 兼容，macOS 不支持关联数组）
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

CALLS_FILE="$TMPDIR/calls"
WRITES_FILE="$TMPDIR/writes"
READS_FILE="$TMPDIR/reads"
INSTALLS_FILE="$TMPDIR/installs"
SCRIPTS_FILE="$TMPDIR/scripts"
FILES_FILE="$TMPDIR/files"

: > "$CALLS_FILE"
: > "$WRITES_FILE"
: > "$READS_FILE"
: > "$INSTALLS_FILE"
: > "$SCRIPTS_FILE"
: > "$FILES_FILE"

add_script() { echo "$1" >> "$SCRIPTS_FILE"; }
add_file()   { echo "$1" >> "$FILES_FILE"; }

scan_script_file() {
    local file_path="$1"
    local rel_path="$2"
    [[ ! -f "$file_path" ]] && return

    add_script "$rel_path"

    while IFS= read -r line; do
        # 去掉首部全部空白
        trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"
        [[ "$trimmed" == \#* ]] && continue
        [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] && continue

        # 检测是否 echo/printf/cat 输出行（文本中的 bash 不是真实调用）
        skip_bash=false
        case "$trimmed" in
            echo*) skip_bash=true ;;
            printf*) skip_bash=true ;;
            cat*) skip_bash=true ;;
        esac

        if ! $skip_bash; then
            # bash "$SCRIPT_DIR/target.sh"
            if [[ "$line" =~ bash[[:space:]]+\"\$SCRIPT_DIR/([^\"]+\.sh)\" ]]; then
                t="scripts/${BASH_REMATCH[1]}"
                add_script "$t"; echo "$rel_path:$t" >> "$CALLS_FILE"
            fi

            # bash "$VIBE_ROOT/scripts/target.sh"
            if [[ "$line" =~ bash[[:space:]]+\"\$VIBE_ROOT/scripts/([^\"]+\.sh)\" ]]; then
                t="scripts/${BASH_REMATCH[1]}"
                add_script "$t"; echo "$rel_path:$t" >> "$CALLS_FILE"
            fi

            # bash "$DIR/scripts/target.sh"
            if [[ "$line" =~ bash[[:space:]]+\"\$DIR/scripts/([^\"]+\.sh)\" ]]; then
                t="scripts/${BASH_REMATCH[1]}"
                add_script "$t"; echo "$rel_path:$t" >> "$CALLS_FILE"
            fi

            # bash vibe-control/scripts/target.sh
            if [[ "$line" =~ bash[[:space:]]+vibe-control/scripts/([a-zA-Z0-9_.-]+) ]]; then
                t="scripts/${BASH_REMATCH[1]}"
                add_script "$t"; echo "$rel_path:$t" >> "$CALLS_FILE"
            fi

            # bash scripts/target.sh
            if [[ "$line" =~ bash[[:space:]]+scripts/([a-zA-Z0-9_.-]+) ]]; then
                t="scripts/${BASH_REMATCH[1]}"
                add_script "$t"; echo "$rel_path:$t" >> "$CALLS_FILE"
            fi
        fi

        # cat > "path" / cat > path
        if [[ "$line" =~ cat[[:space:]]+\>[[:space:]]*\"?([a-zA-Z0-9_./-]+)\"? ]]; then
            f="${BASH_REMATCH[1]}"
            f="${f//\$VIBE_OUT\//.vibe/}"
            [[ "$f" != *'$'* ]] && { add_file "$f"; echo "$rel_path:$f" >> "$WRITES_FILE"; }
        fi

        # cat << ... > "path"
        if [[ "$line" =~ cat[[:space:]]+.*\>[[:space:]]*\"?([a-zA-Z0-9_./-]+)\"? ]]; then
            f="${BASH_REMATCH[1]}"
            f="${f//\$VIBE_OUT\//.vibe/}"
            [[ "$f" != *'$'* ]] && { add_file "$f"; echo "$rel_path:$f" >> "$WRITES_FILE"; }
        fi

        # echo ... >> "path"
        if [[ "$line" =~ echo[[:space:]]+.*[[:space:]]+\>\>[[:space:]]*\"?([a-zA-Z0-9_./-]+)\"? ]]; then
            f="${BASH_REMATCH[1]}"
            [[ "$f" != *'$'* ]] && { add_file "$f"; echo "$rel_path:$f" >> "$WRITES_FILE"; }
        fi

        # cp src "dst"
        if [[ "$line" =~ cp[[:space:]]+\"?([^\"[:space:]]+)\"?[[:space:]]+\"?([a-zA-Z0-9_./-]+)\"? ]]; then
            dst="${BASH_REMATCH[2]}"
            dst="${dst//\$VIBE_ROOT\/scripts\//}"
            dst="${dst//\$VIBE_ROOT\/rules\//}"
            dst="${dst//\$VIBE_ROOT\//}"
            [[ "$dst" != *'$'* ]] && { add_file "$dst"; echo "$rel_path:$dst" >> "$INSTALLS_FILE"; }
        fi

        # ln -sf ... "dst"
        if [[ "$line" =~ ln[[:space:]]+-sf[[:space:]]+\"?([^\"[:space:]]+)\"?[[:space:]]+\"?([a-zA-Z0-9_./-]+)\"? ]]; then
            dst="${BASH_REMATCH[2]}"
            dst="${dst//\$VIBE_ROOT\//}"
            [[ "$dst" != *'$'* ]] && { add_file "$dst"; echo "$rel_path:$dst" >> "$INSTALLS_FILE"; }
        fi

        # writeFileSync('path')
        if [[ "$line" =~ writeFileSync\(\'([^\']+)\' ]]; then
            f="${BASH_REMATCH[1]}"
            [[ "$f" != *'$'* ]] && { add_file "$f"; echo "$rel_path:$f" >> "$WRITES_FILE"; }
        fi

        # require('./path.json')
        if [[ "$line" =~ require\(\'\.\/?([^\']+\.(json|js))\', ]]; then
            f="${BASH_REMATCH[1]}"
            [[ "$f" != *'$'* ]] && { add_file "$f"; echo "$rel_path:$f" >> "$READS_FILE"; }
        fi

        # jq ... "file.json"
        if [[ "$line" =~ jq[[:space:]]+.*[[:space:]]+\"([^\"]+\.json)\" ]]; then
            f="${BASH_REMATCH[1]}"
            [[ "$f" != *'$'* ]] && { add_file "$f"; echo "$rel_path:$f" >> "$READS_FILE"; }
        fi

    done < "$file_path"
}

# === 扫描 ===
for f in "$SCRIPTS_DIR"/*.sh; do
    name=$(basename "$f")
    scan_script_file "$f" "scripts/$name"
done
scan_script_file "$SCRIPTS_DIR/pre-commit" "pre-commit"
scan_script_file "$SCRIPTS_DIR/pre-push" "pre-push"

# SKILL.md
if [ -f "$SKILL_FILE" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ bash[[:space:]]+vibe-control/scripts/([a-zA-Z0-9_.-]+) ]]; then
            t="scripts/${BASH_REMATCH[1]}"
            add_script "$t"; echo "SKILL.md:$t" >> "$CALLS_FILE"
        fi
        if [[ "$line" =~ bash[[:space:]]+scripts/([a-zA-Z0-9_.-]+) ]]; then
            t="scripts/${BASH_REMATCH[1]}"
            add_script "$t"; echo "SKILL.md:$t" >> "$CALLS_FILE"
        fi
        if [[ "$line" =~ core/(AI_CONTROL|DEPENDENCY_MAP|TASK_TEMPLATE)\.md ]]; then
            f="${BASH_REMATCH[0]}"
            add_file "$f"; echo "SKILL.md:$f" >> "$READS_FILE"
        fi
        if [[ "$line" =~ \.vibe/([a-zA-Z_./*]+) ]]; then
            f=".vibe/${BASH_REMATCH[1]}"
            [[ "$f" != *'*' ]] && { add_file "$f"; echo "SKILL.md:$f" >> "$READS_FILE"; }
        fi
    done < "$SKILL_FILE"
fi

# 去重
sort -u "$SCRIPTS_FILE" -o "$SCRIPTS_FILE"
sort -u "$FILES_FILE" -o "$FILES_FILE"
sort -u "$CALLS_FILE" -o "$CALLS_FILE"
sort -u "$WRITES_FILE" -o "$WRITES_FILE"
sort -u "$READS_FILE" -o "$READS_FILE"
sort -u "$INSTALLS_FILE" -o "$INSTALLS_FILE"

# ===================== 生成函数 =====================

get_script_id() {
    local s="$1"
    echo "${s#scripts/}"
}

get_file_id() {
    local f="$1"
    local id="${f//\//_}"
    id="${id//\./_}"
    echo "$id"
}

generate_graph() {
    echo '```mermaid'
    echo 'graph TD'
    echo ''

    echo '    subgraph 脚本'
    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        label="$(get_script_id "$s")"
        id="s_${label//\./_}"
        echo "    ${id}[${label}]"
    done < "$SCRIPTS_FILE"
    echo '    end'
    echo ''

    echo '    subgraph 文件与配置'
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        id="$(get_file_id "$f")"
        echo "    ${id}[${f}]"
    done < "$FILES_FILE"
    echo '    end'
    echo ''

    while IFS=: read -r caller callee; do
        [[ -z "$caller" || -z "$callee" ]] && continue
        c_id="s_$(get_script_id "$caller")"
        cl_id="s_$(get_script_id "$callee")"
        echo "    ${c_id} --> ${cl_id}"
    done < "$CALLS_FILE"

    while IFS=: read -r script file; do
        [[ -z "$script" || -z "$file" ]] && continue
        s_id="s_$(get_script_id "$script")"
        f_id="$(get_file_id "$file")"
        echo "    ${s_id} -->|写入| ${f_id}"
    done < "$WRITES_FILE"

    while IFS=: read -r script file; do
        [[ -z "$script" || -z "$file" ]] && continue
        s_id="s_$(get_script_id "$script")"
        f_id="$(get_file_id "$file")"
        echo "    ${s_id} -.->|安装| ${f_id}"
    done < "$INSTALLS_FILE"

    echo '```'
}

generate_matrix() {
    echo '| 被依赖方（修改它会影响） | 依赖方列表 | 影响程度 | 检查要点 |'
    echo '|---|---|---|---|'

    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        label="$(get_script_id "$s")"

        # 找出调用方
        callers=$(grep ":${s}$" "$CALLS_FILE" | cut -d: -f1 | sort -u || true)
        caller_list=""
        caller_count=0
        for c in $callers; do
            [ -z "$c" ] && continue
            cl="$(get_script_id "$c")"
            [ -z "$caller_list" ] && caller_list="$cl" || caller_list="$caller_list, $cl"
            caller_count=$((caller_count + 1))
        done

        if [ "$caller_count" -ge 3 ]; then
            impact="高"
            check="联动方多，修改后需逐个回归测试"
        elif [ "$caller_count" -ge 1 ]; then
            impact="中"
            check="调用方返回值或接口需同步"
        else
            impact="低"
            check="叶子节点，影响范围有限"
        fi

        echo "| \`$label\` | ${caller_list:--} | $impact | $check |"
    done < "$SCRIPTS_FILE"
}

generate_checklists() {
    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        label="$(get_script_id "$s")"
        echo "### 修改 ${s}"
        echo "- [ ] ${s} — 修改本身"

        # 依赖方（反向调用）
        callers=$(grep ":${s}$" "$CALLS_FILE" | cut -d: -f1 | sort -u || true)
        for c in $callers; do
            [ -z "$c" ] && continue
            cl="$(get_script_id "$c")"
            if [ "$cl" = "SKILL.md" ]; then
                echo "- [ ] ${cl} — 工作流中引用需同步"
            else
                echo "- [ ] ${cl} — 调用方返回值或接口需同步"
            fi
        done

        # 写入的文件
        writes=$(grep "^${s}:" "$WRITES_FILE" | cut -d: -f2- | sort -u || true)
        for f in $writes; do
            [ -z "$f" ] && continue
            echo "- [ ] $f — 输出内容或格式需同步"
        done

        # 安装的文件
        installs=$(grep "^${s}:" "$INSTALLS_FILE" | cut -d: -f2- | sort -u || true)
        for f in $installs; do
            [ -z "$f" ] && continue
            echo "- [ ] $f — 安装逻辑需同步"
        done

        # 读取的文件
        reads=$(grep "^${s}:" "$READS_FILE" | cut -d: -f2- | sort -u || true)
        for f in $reads; do
            [ -z "$f" ] && continue
            echo "- [ ] $f — 读取接口或格式需同步"
        done

        echo ""
    done < "$SCRIPTS_FILE"
}

# ===================== 主逻辑 =====================

GENERATED_CONTENT=$(
    echo "<!-- 由 generate-depmap.sh 自动生成，请勿手动编辑 -->"
    echo ""
    echo "## 依赖关系图"
    echo ""
    generate_graph
    echo ""
    echo "## 关键依赖矩阵"
    echo ""
    generate_matrix
    echo ""
    echo "## 修改检查清单"
    echo ""
    generate_checklists
)

if $CHECK_MODE; then
    if [ ! -f "$DEPMAP_FILE" ]; then
        echo "❌ DEPENDENCY_MAP.md 不存在"
        exit 1
    fi

    CURRENT=$(sed -n '/<!-- DEPGRAPH_START -->/,/<!-- DEPGRAPH_END -->/p' "$DEPMAP_FILE" 2>/dev/null || true)
    NEW_MARKED="<!-- DEPGRAPH_START -->
$GENERATED_CONTENT
<!-- DEPGRAPH_END -->"

    if [ "$CURRENT" != "$NEW_MARKED" ]; then
        echo "❌ DEPENDENCY_MAP.md 已过时，请运行 bash scripts/generate-depmap.sh 更新"
        exit 1
    fi
    echo "✅ DEPENDENCY_MAP.md 与 scripts/ 结构一致"
    exit 0
fi

if [ ! -f "$DEPMAP_FILE" ]; then
    echo "❌ 未找到 $DEPMAP_FILE"
    exit 1
fi

if ! grep -q '<!-- DEPGRAPH_START -->' "$DEPMAP_FILE" 2>/dev/null; then
    echo "❌ $DEPMAP_FILE 中缺少 <!-- DEPGRAPH_START --> 标记"
    echo "请在 DEPENDENCY_MAP.md 中添加:"
    echo "  <!-- DEPGRAPH_START -->"
    echo "  <自动生成内容>"
    echo "  <!-- DEPGRAPH_END -->"
    exit 1
fi

# 替换标记区域
TMPFILE=$(mktemp)
sed -n '1,/<!-- DEPGRAPH_START -->/p' "$DEPMAP_FILE" | sed '$d' > "$TMPFILE"
echo "<!-- DEPGRAPH_START -->" >> "$TMPFILE"
echo "$GENERATED_CONTENT" >> "$TMPFILE"
echo "<!-- DEPGRAPH_END -->" >> "$TMPFILE"
sed -n '/<!-- DEPGRAPH_END -->/,$p' "$DEPMAP_FILE" | tail -n +2 >> "$TMPFILE"

cp "$TMPFILE" "$DEPMAP_FILE"
rm -f "$TMPFILE"
echo "✅ $DEPMAP_FILE 已更新"
