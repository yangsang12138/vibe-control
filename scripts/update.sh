#!/bin/bash
set -e

# vibe-control 升级脚本
# 等同于执行 sync-core.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$DIR/scripts/sync-core.sh"