#!/bin/bash
set -e

# vibe-control 核心文件同步脚本
# 拉取最新代码 → 重新注入

echo "🔄 正在同步 vibe-control 核心文件..."
echo "================================"

VIBE_ROOT="$(pwd)/vibe-control"

if [ ! -f "$VIBE_ROOT/scripts/check.sh" ]; then
    echo "❌ 未找到 vibe-control，请在项目根目录执行"
    exit 1
fi

# 更新 vibe-control
if [ -d "$VIBE_ROOT/.git" ]; then
    echo "更新 vibe-control..."
    if git -C "$VIBE_ROOT" pull; then
        echo "✅ vibe-control 已更新到最新"
    else
        echo "⚠️  当前协议连接失败，尝试备选协议..."
        CURRENT_URL=$(git -C "$VIBE_ROOT" remote get-url origin 2>/dev/null)
        case "$CURRENT_URL" in
            git@github.com:*)
                echo "   SSH → HTTPS 回退..."
                git -C "$VIBE_ROOT" remote set-url origin \
                    "$(echo "$CURRENT_URL" | sed 's|git@github.com:|https://github.com/|')"
                if git -C "$VIBE_ROOT" pull; then
                    echo "✅ HTTPS 连接成功（已从 SSH 自动切换）"
                else
                    echo "❌ HTTPS 也连接失败，请检查网络"
                    git -C "$VIBE_ROOT" remote set-url origin "$CURRENT_URL"
                fi
                ;;
            https://github.com/*)
                echo "   HTTPS → SSH 回退..."
                git -C "$VIBE_ROOT" remote set-url origin \
                    "$(echo "$CURRENT_URL" | sed 's|https://github.com/|git@github.com:|')"
                if git -C "$VIBE_ROOT" pull; then
                    echo "✅ SSH 连接成功（已从 HTTPS 自动切换）"
                else
                    echo "❌ SSH 也连接失败，请检查网络"
                    git -C "$VIBE_ROOT" remote set-url origin "$CURRENT_URL"
                fi
                ;;
            *)
                echo "❌ 无法识别 URL 协议，请检查"
                ;;
        esac
    fi
fi

# 重新注入
bash "$VIBE_ROOT/scripts/inject.sh"

echo "================================"
echo "🎉 同步完成！"
