# vibe-control

AI Vibe coding 全流程工程控制体系。可注入到任意现有项目，提供统一的需求沟通、架构约束、修改协议、质量检查标准。

## 核心理念

- **控制平面与业务代码分离**：控制文件通过 Git Submodule 引入，注入产物均在 `.gitignore` 中，不提交到目标代码库
- **一处维护，处处升级**：优化 Prompt 后，所有接入项目一键同步
- **渐进式约束**：从松散到严格，随项目成熟度逐步收紧

## 命令

所有命令均以 `bash vibe-control/scripts/` 为前缀，在项目根目录执行。

| 场景 | 命令 | 说明 |
|---|---|---|
| **首次接入** | `init.sh` | 添加子模块 → 注入控制文件 → 安装钩子 → 配置 .gitignore |
| **升级控制脚本** | `sync-core.sh` | 拉取子模块最新版本 → 重新注入，当 vibe-control 仓库有更新时使用 |
| **模板同步** | `sync-templates.sh` | 自动检测项目类型 → 填充控制模板占位符 → 生成依赖关系图 |
| **合规检查** | `check.sh` | 敏感信息扫描、控制文件完整性、依赖地图一致性、README 覆盖、零泄漏检测、任务日志对齐 |
| **PR 前检查** | `pr-check.sh` | 合规检查 + 所有任务日志摘要，推送前由 pre-push 钩子自动调用 |
| **诊断恢复** | `recover.sh` | 检查 .vibe/ 结构、钩子状态、.gitignore 覆盖，输出修复命令或自动恢复 |
| **查看状态** | `status.sh` | 显示注入版本、目录结构、产物清单 |
| **任务日志** | `task-log.sh "描述"` | 创建 `.vibe/tasks/YYYYMMDD-HHMM-描述.md`，AI 编码任务开始前必运行 |

提交前 `check.sh` 检测任务日志：
- 无日志 → ❌ exit 1，**提交被阻止**
- 有日志但影响分析表或核对清单为空 → ❌ exit 1，**提交被阻止**
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
| `scripts/generate-depmap.sh` | 自动生成依赖关系图和修改检查清单（DEPENDENCY_MAP.md） |
| `scripts/sync-templates.sh` | 一键同步，detect + fill + generate-depmap 合并执行 |
| `scripts/sync-core.sh` | **同步核心文件**，更新子模块 + 刷新软链 |
| `scripts/check.sh` | 合规检查，验证项目是否满足基本约束 |
| `scripts/task-log.sh` | 任务日志生成脚本，为每次编码任务创建跟踪记录 |
| `scripts/status.sh` | 查看 vibe-control 状态：版本、模式、注入产物 |
| `scripts/pr-check.sh` | PR 前完整检查，汇总任务日志摘要 + 合规状态 |
| `scripts/recover.sh` | 诊断修复：检查 .vibe/ 钩子 gitignore 状态，输出修复命令 |
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
