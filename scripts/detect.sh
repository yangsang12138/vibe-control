#!/bin/bash
# vibe-control 项目信息检测脚本
# 扫描目标项目，输出检测结果到 .vibe/detect.json

set -e
OUT="${1:-.vibe/detect.json}"
mkdir -p "$(dirname "$OUT")"

# --- 项目基本信息 ---
PROJECT_NAME=""
PROJECT_TYPE=""
TECH_STACK=""
DATE="$(date +%Y-%m-%d)"
VIBE_VERSION="1.0.0"

# 从 package.json 获取项目名
if [ -f "package.json" ]; then
    NAME=$(node -e "try{console.log(require('./package.json').name||'')}catch(e){}" 2>/dev/null)
    [ -n "$NAME" ] && PROJECT_NAME="$NAME"
    # 检测技术栈
    DEPS=$(node -e "try{
        const p=require('./package.json');
        const d={...p.dependencies,...p.devDependencies};
        const r=[];
        if(d.react)r.push('React');
        if(d.vue||d['nuxt'])r.push('Vue');
        if(d.next)r.push('Next.js');
        if(d.express)r.push('Express');
        if(d.typescript)r.push('TypeScript');
        if(d.tailwindcss)r.push('TailwindCSS');
        if(d.prisma)r.push('Prisma');
        if(d['@supabase/supabase-js'])r.push('Supabase');
        console.log(r.join(', '));
    }catch(e){}" 2>/dev/null)
    [ -n "$DEPS" ] && TECH_STACK="$DEPS"
fi

# 从 pyproject.toml 获取项目名
if [ -f "pyproject.toml" ]; then
    NAME=$(grep '^name[[:space:]]*=' pyproject.toml 2>/dev/null | sed 's/.*=[[:space:]]*"\(.*\)"/\1/' | tr -d ' ')
    [ -z "$PROJECT_NAME" ] && [ -n "$NAME" ] && PROJECT_NAME="$NAME"
fi

# 从 Cargo.toml 获取项目名
if [ -f "Cargo.toml" ]; then
    NAME=$(grep '^name[[:space:]]*=' Cargo.toml 2>/dev/null | sed 's/.*=[[:space:]]*"\(.*\)"/\1/' | tr -d ' ')
    [ -z "$PROJECT_NAME" ] && [ -n "$NAME" ] && PROJECT_NAME="$NAME"
fi

# 没检测到则用目录名
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$(basename "$(pwd)")"
fi

# 追加平台信息到技术栈
OS="$(uname -s)"
TECH_STACK="${TECH_STACK}${TECH_STACK:+, }${OS}"
[ -f "package.json" ] && TECH_STACK="${TECH_STACK}, Node.js $(node -v 2>/dev/null | sed 's/v//')"

# --- 项目类型推断 ---
if [ -f "next.config.js" ] || [ -f "next.config.ts" ] || [ -f "next.config.mjs" ]; then
    PROJECT_TYPE="Web Application (Next.js)"
elif [ -f "astro.config.mjs" ] || [ -f "astro.config.ts" ]; then
    PROJECT_TYPE="Static Site (Astro)"
elif [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
    PROJECT_TYPE="Frontend App (Vite)"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    PROJECT_TYPE="Python Application"
elif [ -d "scripts" ]; then
    SH_COUNT=$(ls scripts/*.sh 2>/dev/null | wc -l | tr -d ' ')
    [ "$SH_COUNT" -ge 3 ] 2>/dev/null && PROJECT_TYPE="Bash Tool"
fi

[ -z "$PROJECT_TYPE" ] && PROJECT_TYPE="Unknown"

# --- 工具链检测 ---
TYPE_CHECK_COMMAND=""
LINT_COMMAND=""
TEST_COMMAND=""
BUILD_COMMAND=""

if [ -f "tsconfig.json" ]; then
    TYPE_CHECK_COMMAND="npx tsc --noEmit"
fi

if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
    # 检查 package.json scripts
    if [ -f "package.json" ]; then
        HAS_LINT=$(node -e "try{const p=require('./package.json');console.log(p.scripts&&p.scripts.lint?'yes':'')}catch(e){}" 2>/dev/null)
        [ "$HAS_LINT" = "yes" ] && LINT_COMMAND="npm run lint" || LINT_COMMAND="npx eslint ."
    fi
fi

if [ -f "package.json" ]; then
    HAS_TEST=$(node -e "try{const p=require('./package.json');console.log(p.scripts&&(p.scripts.test||p.scripts['test:run'])?'yes':'')}catch(e){}" 2>/dev/null)
    [ "$HAS_TEST" = "yes" ] && TEST_COMMAND="npm test"
    HAS_BUILD=$(node -e "try{const p=require('./package.json');console.log(p.scripts&&p.scripts.build?'yes':'')}catch(e){}" 2>/dev/null)
    [ "$HAS_BUILD" = "yes" ] && BUILD_COMMAND="npm run build"
fi

# --- 项目结构检测 ---
TYPE_DEFINITION_FILE=""
API_FILE=""
COMPONENTS_DIR=""
ENV_ACCESS=""
ENV_EXAMPLE_FILE=""

[ -d "types" ] && TYPE_DEFINITION_FILE="types/index.ts"
[ -d "src/types" ] && TYPE_DEFINITION_FILE="src/types/index.ts"
[ -f "types/models.ts" ] && TYPE_DEFINITION_FILE="types/models.ts"
[ -f "src/types/models.ts" ] && TYPE_DEFINITION_FILE="src/types/models.ts"

[ -d "lib" ] && API_FILE="lib/api.ts"
[ -f "src/lib/api.ts" ] && API_FILE="src/lib/api.ts"
[ -f "lib/api.ts" ] && API_FILE="lib/api.ts"
[ -f "api/index.ts" ] && API_FILE="api/index.ts"

[ -d "components/ui" ] && COMPONENTS_DIR="components/ui/"
[ -d "src/components/ui" ] && COMPONENTS_DIR="src/components/ui/"
[ -d "src/components" ] && [ -z "$COMPONENTS_DIR" ] && COMPONENTS_DIR="src/components/"

[ -f ".env.example" ] && ENV_EXAMPLE_FILE=".env.example"
[ -f ".env.sample" ] && ENV_EXAMPLE_FILE=".env.sample"
[ -f "env.example" ] && ENV_EXAMPLE_FILE="env.example"

if [ -f "tsconfig.json" ] || [ -f "package.json" ]; then
    ENV_ACCESS="process.env"
fi

COVERAGE_THRESHOLD="80"

# --- 输出 JSON ---
cat > "$OUT" << JSONEOF
{
  "PROJECT_NAME": "$PROJECT_NAME",
  "PROJECT_TYPE": "$PROJECT_TYPE",
  "TECH_STACK": "$TECH_STACK",
  "DATE": "$DATE",
  "VIBE_VERSION": "$VIBE_VERSION",
  "TYPE_DEFINITION_FILE": "$TYPE_DEFINITION_FILE",
  "API_FILE": "$API_FILE",
  "COMPONENTS_DIR": "$COMPONENTS_DIR",
  "ENV_ACCESS": "$ENV_ACCESS",
  "ENV_EXAMPLE_FILE": "$ENV_EXAMPLE_FILE",
  "TYPE_CHECK_COMMAND": "$TYPE_CHECK_COMMAND",
  "LINT_COMMAND": "$LINT_COMMAND",
  "TEST_COMMAND": "$TEST_COMMAND",
  "COVERAGE_THRESHOLD": "$COVERAGE_THRESHOLD",
  "BUILD_COMMAND": "$BUILD_COMMAND"
}
JSONEOF

echo "✅ 检测完成：$OUT"
