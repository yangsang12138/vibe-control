#!/bin/bash
# vibe-control 模板填充脚本
# 读取 .vibe/detect.json 的检测结果，将 core/*.md 模板中的占位符替换为实际值
# 输出到 .vibe/core/*.md

set -e

DETECT_FILE="${1:-.vibe/detect.json}"
TEMPLATE_DIR="${2:-core}"
OUTPUT_DIR="${3:-.vibe/core}"

if [ ! -f "$DETECT_FILE" ]; then
    echo "⚠️  $DETECT_FILE 不存在，请先运行 detect.sh"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 占位符 → detect.json 键名映射（中文 [] 格式）
# 格式用空格分隔：占位符文本 detect_json_key
PLACEHOLDER_MAP=(
    "类型定义文件/目录:TYPE_DEFINITION_FILE"
    "类型定义文件:TYPE_DEFINITION_FILE"
    "API 封装文件:API_FILE"
    "组件目录:COMPONENTS_DIR"
    "环境变量访问方式:ENV_ACCESS"
    "环境变量示例文件:ENV_EXAMPLE_FILE"
    "类型检查命令:TYPE_CHECK_COMMAND"
    "Lint 命令:LINT_COMMAND"
    "测试命令:TEST_COMMAND"
    "覆盖率阈值:COVERAGE_THRESHOLD"
    "测试覆盖命令:TEST_COMMAND"
    "构建命令:BUILD_COMMAND"
    "性能检查命令:BUILD_COMMAND"
)

fill_template() {
    local src="$1"
    local dst="$2"
    local filename
    filename=$(basename "$src")

    if [ ! -f "$src" ]; then
        echo "⚠️  模板不存在：$src"
        return
    fi

    cp "$src" "$dst"

    # 1. 替换 {{KEY}} 模式
    while IFS= read -r key; do
        [ -z "$key" ] && continue
        value=$(jq -r --arg k "$key" 'if has($k) then .[$k] else "" end' "$DETECT_FILE" 2>/dev/null)
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "''" ]; then
            sed -i '' "s/{{$key}}/$value/g" "$dst" 2>/dev/null || true
        fi
    done < <(jq -r 'keys[]' "$DETECT_FILE" 2>/dev/null)

    # 2. 剩余的 {{...}} 标记为 TODO
    perl -i -pe 's/\{\{([^}]+)\}\}/\{\{TODO: $1\}\}/g' "$dst" 2>/dev/null || true

    # 3. 替换中文 [] 占位符
    for entry in "${PLACEHOLDER_MAP[@]}"; do
        placeholder="${entry%%:*}"
        detect_key="${entry##*:}"
        value=$(jq -r --arg k "$detect_key" 'if has($k) then .[$k] else "" end' "$DETECT_FILE" 2>/dev/null)
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "''" ]; then
            sed -i '' "s/\[$placeholder\]/$value/g" "$dst" 2>/dev/null || true
        fi
    done

    echo "✅ 已填：$filename → $dst"
}

# 逐个处理模板文件
for file in AI_CONTROL.md DEPENDENCY_MAP.md TASK_TEMPLATE.md; do
    fill_template "$TEMPLATE_DIR/$file" "$OUTPUT_DIR/$file"
done
