---
name: vibe-control
description: >
  Use when the user describes a coding task in a project governed by vibe-control.
  Triggers on keywords: modify, implement, add, change, refactor, fix, update, new feature, bug.
  Guides the AI through impact analysis, modification protocol, and quality gates.
---

# vibe-control 工作流

项目已接入 vibe-control 控制体系。请按以下流程响应所有编码任务。

## 第1步：加载上下文

读取 **`.vibe/core/AI_CONTROL.md`** 和 **`.vibe/core/DEPENDENCY_MAP.md`**（如不存在则读 `core/` 源文件），了解：
- 项目技术栈和硬性约束
- 模块间依赖关系
- 修改协议

## 第2步：输出影响分析

在写任何代码前，输出：

```
## 影响分析
| 受影响文件 | 涉及符号 | 影响类型（直接/间接） |
|---|---|---|

## 修改计划
| 文件 | 修改内容 | 向后兼容 |
|---|---|---|
```

等待用户确认后再进入下一步。

## 第3步：执行修改

逐文件修改。每完成一个文件，核对：

```
[已完成] 文件名 | 修改内容 | 类型检查通过 | 测试通过
```

## 第4步：验证

- 运行 `[类型检查命令]` 和 `[Lint 命令]`
- 运行已有测试
- 检查是否有残留的注释代码
- 检查是否引入了未确认的新依赖
- 检查是否在代码中写入了敏感信息

## 第5步：更新模板

本次修改涉及的新模块、新依赖、新约束，同步到模板文件中：

1. 如果新增了模块或依赖关系，更新 `.vibe/core/DEPENDENCY_MAP.md`
2. 如果新增了约束或项目信息，更新 `.vibe/core/AI_CONTROL.md`
3. 运行 `bash vibe-control/scripts/sync-templates.sh` 重新检测并更新模板

## 通用约束

- 数据模型定义只能修改 `[类型定义文件]`，不得在其他文件重新定义类型
- API 调用必须使用 `[API 封装文件]` 中的函数，不得自行创建请求实例
- 环境变量仅通过 `[环境变量访问方式]` 访问
- 修改出错时，主动告知 `git revert` / `git checkout` 回滚命令
