#!/bin/bash
set -e

# vibe-control 项目边界检测工具
# 用法: bash vibe-control/scripts/scope-check.sh <路径>
# 返回值: 0 = 在当前项目内, 1 = 在当前项目外

TARGET_PATH="${1:-}"
if [ -z "$TARGET_PATH" ]; then
    echo "用法: bash vibe-control/scripts/scope-check.sh <路径>"
    exit 2
fi

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$GIT_ROOT" ]; then
    echo "❌ 当前目录不是 Git 仓库"
    exit 2
fi

ABS_PATH=$(realpath "$TARGET_PATH" 2>/dev/null || echo "$(cd "$(dirname "$TARGET_PATH")" 2>/dev/null && pwd)/$(basename "$TARGET_PATH")")

if [ -z "$ABS_PATH" ]; then
    echo "⚠️  无法解析路径: $TARGET_PATH"
    exit 1
fi

case "$ABS_PATH" in
    "$GIT_ROOT"*) exit 0;;
    *)            exit 1;;
esac
