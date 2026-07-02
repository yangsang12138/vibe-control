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

## 第5步：更新模板（必须执行）

> ⚠️ **在提交之前**，必须完成以下检查。这是确保控制体系与代码保持同步的关键步骤。

### 5a. 检查 DEPENDENCY_MAP.md 是否过时

对照本次修改涉及的文件清单，检查 `DEPENDENCY_MAP.md`：
- 新增的文件/模块是否在依赖关系图和矩阵中？
- 移除了的文件/模块是否已从地图中清理？

### 5b. 检查 AI_CONTROL.md 是否过时

- 新增了依赖包 → 是否需要更新"依赖引入管控"相关说明？
- 新增了目录结构（types、components/ui 等）→ 是否需要更新约束中引用的文件路径？
- 修改了技术栈 → 是否需要更新项目基本信息？

### 5c. 运行模板同步

```bash
bash vibe-control/scripts/sync-templates.sh
```
这步会自动重新检测项目结构并填充 `.vibe/core/*.md`。

### 5d. 运行合规检查

```bash
bash vibe-control/scripts/check.sh
```
确保新加的模块没有被 DEPENDENCY_MAP 过时检测标记为 warning。

## 通用约束

- 数据模型定义只能修改 `[类型定义文件]`，不得在其他文件重新定义类型
- API 调用必须使用 `[API 封装文件]` 中的函数，不得自行创建请求实例
- 环境变量仅通过 `[环境变量访问方式]` 访问
- 修改出错时，主动告知 `git revert` / `git checkout` 回滚命令
