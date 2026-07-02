# vibe-control

AI Vibe coding 全流程工程控制体系。可注入到任意现有项目，提供统一的需求沟通、架构约束、修改协议、质量检查标准。

## 核心理念

- **控制平面与业务代码分离**：控制文件通过 Git Submodule 引入，不污染主项目
- **一处维护，处处升级**：优化 Prompt 后，所有接入项目一键同步
- **渐进式约束**：从松散到严格，随项目成熟度逐步收紧

## 快速开始

### 首次注入到已有项目
```bash
# 在目标项目根目录执行
git submodule add https://github.com/你的账号/vibe-control.git vibe-control
bash vibe-control/scripts/inject.sh
git add .gitmodules vibe-control .cursorrules
git commit -m "chore: 注入 vibe-control 控制体系"
```

### 升级到最新版本
```bash
bash vibe-control/scripts/update.sh
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
| `scripts/inject.sh` | 注入脚本，将控制体系软链接到项目 |
| `scripts/check.sh` | 合规检查，验证项目是否满足基本约束 |

## 维护方式

1. 在 vibe-control 仓库中优化模板或脚本
2. 提交推送
3. 在任意接入项目中执行 `bash vibe-control/scripts/update.sh`
