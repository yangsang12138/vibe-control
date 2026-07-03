#!/bin/bash
set -e

DESCRIPTION="$*"
if [ -z "$DESCRIPTION" ]; then
    echo "用法: bash vibe-control/scripts/task-log.sh \"任务描述\""
    exit 1
fi

DATE=$(date +%Y%m%d-%H%M)
SAFE_DESC=$(echo "$DESCRIPTION" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
FILENAME="${DATE}-${SAFE_DESC}.md"

TASK_DIR=".vibe/tasks"
mkdir -p "$TASK_DIR"
FILEPATH="$TASK_DIR/$FILENAME"

cat > "$FILEPATH" << FILEEOF
# 任务日志: ${DESCRIPTION}

> 生成时间: $(date '+%Y-%m-%d %H:%M')
> 任务模板路径: vibe-control/core/TASK_TEMPLATE.md

---

## 影响分析

> 填写**完整文件路径**（相对于项目根目录），以匹配 check.sh 对齐检测。

| 受影响文件（完整路径） | 涉及符号 | 影响类型（直接/间接） |
|---|---|---|
| | | |

## 修改计划

| 文件（完整路径） | 修改内容 | 向后兼容 |
|---|---|---|
| | | |

## 执行核对清单

| 状态 | 文件（完整路径） | 修改内容 | 类型检查通过 | 测试通过 |
|---|---|---|---|---|
| | | | | |

## 验证结果

- [ ] 类型检查通过
- [ ] Lint 通过
- [ ] 测试通过
- [ ] 无残留注释代码
- [ ] 无未确认新依赖
- [ ] 无敏感信息泄漏

## 备注

FILEEOF

echo "$FILEPATH"
