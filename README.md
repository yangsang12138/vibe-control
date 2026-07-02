# vibe-control

AI Vibe coding 全流程工程控制体系。可注入到任意现有项目，提供统一的需求沟通、架构约束、修改协议、质量检查标准。

## 核心理念

- **控制平面与业务代码分离**：控制文件通过 Git Submodule 引入，不污染主项目
- **一处维护，处处升级**：优化 Prompt 后，所有接入项目一键同步
- **渐进式约束**：从松散到严格，随项目成熟度逐步收紧

## 快速开始

### 一键初始化（推荐）
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yangsang12138/vibe-control/main/scripts/init.sh)
```

### 或分步手动
```bash
git submodule add https://github.com/yangsang12138/vibe-control.git vibe-control
bash vibe-control/scripts/inject.sh
```

### 同步核心文件到最新
```bash
bash vibe-control/scripts/sync-core.sh
```

### 查看注入状态
```bash
bash vibe-control/scripts/status.sh
```

### PR 前完整检查
```bash
bash vibe-control/scripts/pr-check.sh
```

### 运行项目合规检查
```bash
npm run vibe-check
# 或直接执行
bash vibe-control/scripts/check.sh
```

### 任务日志（AI 工作流强制）
每次 AI 编码任务开始时，必须生成任务日志以跟踪修改过程：

```bash
bash vibe-control/scripts/task-log.sh "任务描述"
```

该命令创建 `.vibe/tasks/YYYYMMDD-HHMM-描述.md`，AI 在任务过程中逐步填写：
1. **影响分析** — 列出所有受影响文件和符号
2. **修改计划** — 每文件的最小修改方案
3. **执行核对清单** — 逐文件确认编译/测试结果
4. **验证结果** — 类型检查、Lint、敏感信息扫描

提交前 `check.sh` 检测任务日志：
- 无日志 → ❌ exit 1，**提交被阻止**
- 有日志但**影响分析表或核对清单为空** → ❌ exit 1，**提交被阻止**
- 两表均已填写至少一行 → ✅ 放行

## 文件说明

| 文件 | 用途 |
|---|---|
| `core/AI_CONTROL.md` | 项目总控文件，定义技术栈、不可动摇的约束、修改协议 |
| `core/DEPENDENCY_MAP.md` | 模块依赖地图，修改任意模块前必查 |
| `core/TASK_TEMPLATE.md` | 标准任务模板，新需求时复制填写 |
| `rules/.cursorrules` | Cursor AI 自动遵守的行为规则 |
| `scripts/init.sh` | **一键初始化**，添加子模块 + 注入 + 软链 |
| `scripts/inject.sh` | 注入引擎，将控制体系链接到项目 |
| `scripts/detect.sh` | 项目自动检测，输出 .vibe/detect.json |
| `scripts/fill-templates.sh` | 模板填充，将 core/*.md 占位符替换为实际值 |
| `scripts/sync-templates.sh` | 一键同步，detect + fill 合并执行 |
| `scripts/sync-core.sh` | **同步核心文件**，更新子模块 + 刷新软链 |
| `scripts/check.sh` | 合规检查，验证项目是否满足基本约束 |
| `scripts/task-log.sh` | 任务日志生成脚本，为每次编码任务创建跟踪记录 |
| `scripts/status.sh` | 查看 vibe-control 状态：版本、模式、注入产物 |
| `scripts/pr-check.sh` | PR 前完整检查，汇总任务日志摘要 + 合规状态 |
| `scripts/update.sh` | 升级脚本，等同 sync-core.sh |

## 维护方式

1. 在 vibe-control 仓库中优化模板或脚本
2. 提交推送
3. 在任意接入项目中执行 `bash vibe-control/scripts/sync-core.sh`

## IDE 支持

vibe-control 将配置文件注入根目录，其余产物全部集中在 `.vibe/`。各 IDE 读取方式如下：

| IDE | 配置方式 |
|---|---|
| **opencode CLI** | ✅ 自动生效。`.opencode/` 在根目录，每次对话自动加载核心文件 |
| **Cursor** | ✅ 自动生效。`.cursorrules` 在根目录，Cursor 自动读取 |
| **GitHub Copilot** | 创建 `.github/copilot-instructions.md`，内容为 `include .cursorrules` |
| **Continue.dev** | 在 `~/.continue/config.json` 或项目 `.continuerc.json` 中设置 `"rules": [".cursorrules"]` |
| **其他 IDE** | 在对应 AI 助手的规则配置中引用 `.cursorrules` |

> `.cursorrules` 和 `.opencode/` 均在 `.gitignore` 中，不会提交到目标仓库。
