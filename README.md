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

### 运行项目合规检查
```bash
npm run vibe-check
# 或直接执行
bash vibe-control/scripts/check.sh
```

## 文件说明

| 文件 | 用途 |
|---|---|
| `core/AI_CONTROL.md` | 项目总控文件，定义技术栈、不可动摇的约束、修改协议 |
| `core/DEPENDENCY_MAP.md` | 模块依赖地图，修改任意模块前必查 |
| `core/TASK_TEMPLATE.md` | 标准任务模板，新需求时复制填写 |
| `rules/.cursorrules` | Cursor AI 自动遵守的行为规则 |
| `scripts/init.sh` | **一键初始化**，添加子模块 + 注入 + 软链 |
| `scripts/inject.sh` | 注入引擎，将控制体系链接到项目 |
| `scripts/sync-core.sh` | **同步核心文件**，更新子模块 + 刷新软链 |
| `scripts/check.sh` | 合规检查，验证项目是否满足基本约束 |
| `scripts/update.sh` | 升级脚本，等同 sync-core.sh |

## 维护方式

1. 在 vibe-control 仓库中优化模板或脚本
2. 提交推送
3. 在任意接入项目中执行 `bash vibe-control/scripts/sync-core.sh`

## IDE 支持

vibe-control 将所有文件注入到 `.vibe/` 目录，根目录不产生任何杂文件。各 IDE 读取规则的方式不同，**注入后需按以下方式配置**：

| IDE | 配置方式 |
|---|---|
| **opencode CLI** | ✅ 自动生效。`.opencode/` 配置已注册，每次对话自动加载核心文件 |
| **Cursor** | Settings → Rules → Project Rules，添加路径 `.vibe/cursorrules` |
| **GitHub Copilot** | 创建 `.github/copilot-instructions.md`，内容为 `include .vibe/cursorrules` |
| **Continue.dev** | 在 `~/.continue/config.json` 或项目 `.continuerc.json` 中设置 `"rules": [".vibe/cursorrules"]` |
| **其他 IDE** | 在对应 AI 助手的规则配置中引用 `.vibe/cursorrules` |

> 规则文件路径相对于项目根目录，始终填写 `.vibe/cursorrules` 即可。
