---
name: vibe-control
description: >
  Use when the user describes a coding task in a project governed by vibe-control.
  Triggers on keywords: modify, implement, add, change, refactor, fix, update, new feature, bug, execute, run, do, apply.
  Guides the AI through impact analysis, modification protocol, and quality gates.
---

# vibe-control 强制工作流

项目已接入 vibe-control 控制体系。**你必须严格按以下流程响应所有编码任务，不得跳过任何步骤。**

> 🚫 **硬性禁令**：在任务日志文件（`.vibe/tasks/*.md`）创建并完成影响分析之前，**绝对禁止**执行任何文件修改操作（包括 write、edit、bash 中的 sed/rm/mv 等）。必须先建日志，再写代码。违反此规则将被 check.sh 硬拦截（exit 1）。
>
> ⚠️ 违规处罚：跳过第2步（影响分析）直接写代码，或跳过第5步（模板更新）直接提交，视为任务失败。用户有权要求回滚。

## 第1步：加载上下文

**必须**读取 **`core/AI_CONTROL.md`** 和 **`core/DEPENDENCY_MAP.md`**（如果 `.vibe/core/` 存在则读它），了解：
- 项目技术栈和硬性约束
- 模块间依赖关系
- 修改协议

## 第2步：创建任务日志并输出影响分析

**开始任何编码工作前，必须执行以下操作：**

### 2a. 创建任务日志文件

```bash
bash vibe-control/scripts/task-log.sh "<简要任务描述>"
```

该命令会生成 `.vibe/tasks/YYYYMMDD-HHMM-描述.md`，作为本次任务的记录文件。

### 2b. 填写影响分析

在任务日志文件的 `## 影响分析` 表格中填写本次修改的影响范围。**必须填写完整文件路径**（相对项目根目录，如 `scripts/check.sh` 而非 `check.sh`），因为 `check.sh` 会根据该表做 git staging 对齐检测。

| 受影响文件 | 涉及符号 | 影响类型（直接/间接） |
|---|---|---|
| scripts/check.sh | 任务日志检查逻辑 | 直接 |

### 2c. 输出修改计划

在任务日志文件的 `## 修改计划` 表格中填写：

| 文件 | 修改内容 | 向后兼容 |
|---|---|---|

### 2d. 等待用户确认

使用 `question` 工具让用户点选（不要让其手动输入）：

```
options: ["确认执行", "修改方案", "取消"]
```

- 确认 → 进入第3步
- 修改方案 → 回到 2b/2c 调整计划
- 取消 → 终止

> ⚠️ **豁免条款**：如果用户已通过自然语言明确表达执行意图（如"执行"、"开始"、"改吧"、"改"），AI 可以直接进入第3步，无需再弹 question 工具。仅在用户说"可以"、"好"、"嗯"、"确认"等可能存在歧义的回应时，才必须使用 question 工具让用户精确选择。

## 第3步：执行修改

逐文件修改。**每完成一个文件**，必须在任务日志文件的 `## 执行核对清单` 中更新一行，**状态列填写 `✅`**：

| 状态 | 文件 | 修改内容 | 类型检查通过 | 测试通过 |
|---|---|---|---|---|
| ✅ | scripts/check.sh | 对齐检查 | N/A | N/A |

> ⚠️ `check.sh` 会验证：每个修改文件必须在核对清单中有 `| ✅ | 文件名 | ...` 行。状态留空或写别的 → ❌ 拦截。
- 该文件是否在影响分析列表中
- 修改方案是否与修改计划一致

## 第4步：验证

**必须**运行以下检查（在任务日志文件的 `## 验证结果` 中逐项标记）：
- [ ] 运行 `[类型检查命令]` 和 `[Lint 命令]`
- [ ] 运行已有测试
- [ ] 检查是否有残留的注释代码
- [ ] 检查是否引入了未确认的新依赖
- [ ] 检查是否在代码中写入了敏感信息

全部通过后才可进入第5步。

## 第5步：更新模板（必须执行）

> ⚠️ **在提交之前，必须完成以下检查。** 这是确保控制体系与代码保持同步的关键步骤。

### 5a. 检查 DEPENDENCY_MAP.md 是否过时

对照本次修改涉及的文件清单，检查 `DEPENDENCY_MAP.md`：
- 新增的文件/模块是否在依赖关系图和矩阵中？
- 移除了的文件/模块是否已从地图中清理？

### 5b. 检查 AI_CONTROL.md 是否过时

- 新增了依赖包 → 是否需要更新"依赖引入管控"相关说明？
- 新增了目录结构 → 是否需要更新约束中引用的文件路径？
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

### 5e. 检查 README.md 是否需要更新（必须执行）

> 新增了脚本、修改了命令名称、调整了注入产物清单时，**必须同步更新 README.md**。

对照本次修改检查：
- 新增文件（脚本/核心文件）→ README.md 的文件说明表是否已添加对应行？
- 修改了命令用法 → README.md 的命令示例是否同步？
- 调整了注入产物 → README.md 的快速开始章节是否反映最新结构？

遗漏此步骤提交将被 `check.sh` 拦截。

## 第6步：提示提交与推送

> 🚫 **硬性禁令**：`check.sh` 全部通过后，如果输出中包含 `请确认是否提交` 信号（工作区有未提交修改），AI **必须先使用 `question` 工具让用户确认提交/推送，然后才能结束对话或输出总结。不得跳过此步骤直接输出总结。**
>
> 违反此规则视为任务未完成，用户有权要求回滚。

> 全部验证通过后，**必须**执行 `git status` 查看待提交文件清单。

### 6a. 提示提交

使用 `question` 工具让用户点选：

```
options: ["提交（推荐）", "暂不提交"]
```

选择"提交" → 执行 `git add -A && git commit`。"暂不提交" → 任务结束。

### 6b. 提示推送

`git commit` 成功后，**必须**再次执行 `git status`。如果输出包含 `Your branch is ahead of`，使用 `question` 工具：

```
options: ["推送（推荐）", "暂不推送"]
```

选择"推送" → 执行 `git push`。"暂不推送" → 任务结束。推送完成后才算任务真正结束。

### 推送失败处理

若 `git push` 失败（被拒绝/网络错误/pre-push 拦截），输出恢复命令：

```bash
# 诊断问题
bash vibe-control/scripts/recover.sh

# 常见恢复
git pull --rebase          # 远程有新提交
git push                   # 重试
```

## 通用约束

- 数据模型定义只能修改 `[类型定义文件]`，不得在其他文件重新定义类型
- API 调用必须使用 `[API 封装文件]` 中的函数，不得自行创建请求实例
- 环境变量仅通过 `[环境变量访问方式]` 访问
- 修改出错时，主动告知 `git revert` / `git checkout` 回滚命令
