# AstraAutoEx 项目规范与记忆

> **每次开始新会话时必须读取此文件。**

## 项目概述
AstraAutoEx 是 AI 驱动的短剧/漫画视频生产平台，从 Next.js 原项目 (AstraAuto) 迁移到 Elixir/Phoenix。
管线流程：故事 → 剧本 → 分镜 → 图像 → 视频 → 配音 → 合成。

**原项目路径**: `C:\Users\lexsc\Desktop\AI S\AstraAuto` (Next.js + Prisma + MySQL)
**重构指南**: `C:\Users\lexsc\Desktop\AI S\AstraAuto → AstraAutoEx 完美重构指南.MD`

## 技术栈
- 语言: Elixir 1.19 + OTP 28
- 框架: Phoenix 1.8 + LiveView 1.1
- 数据库: PostgreSQL + Ecto
- 前端: Tailwind CSS v4 + HEEx 模板 + JS Hooks
- 任务队列: OTP GenServer (TaskScheduler + TaskRunner + ConcurrencyLimiter)
- AI 提供商: API易, MiniMax, Google, ARK, FAL, RunningHub (6个)
- 测试: ExUnit + `mix test`（覆盖率: `mix test --cover`）
- 代码质量: `mix format` + `mix credo`（如已安装）
- Elixir 路径: `C:\ProgramData\chocolatey\lib\Elixir\tools\bin\mix.bat`
- 启动命令: `cd C:\Users\lexsc\Desktop\AstraAutoEx && mix phx.server` (需保持终端窗口)

## 核心原则（每次都必须遵守）
- 遵循 AGENTS.md 中的 Phoenix v1.8 / LiveView / Ecto 规范
- 写代码前先规划（Planner），写实现前先写测试（TDD: Red → Green → Refactor）
- 测试覆盖率目标 ≥ 80%，每次修改后运行测试，不允许跳过
- HEEx 模板中 textarea 用 `<textarea><%= @val %></textarea>` 不用 `value=`
- `phx-value-*` 仅适用于 `phx-click`，`phx-change` 需用 `<form>` + hidden input
- Character schema 没有 `image_url`/`description` 字段，用 `appearances` 和 `introduction`
- VoiceLine schema 没有 `status`/`voice_id` 字段，用 `audio_url` 判断状态，用 `voice_preset_id`
- Panel schema 用 `camera_move`（不是 `camera_movement`），没有 `scene_type`/`dialogue`
- 函数组件的 assigns 需要在调用处显式传入，不会自动继承父组件的 assigns
- 函数超过 50 行必须拆分
- 每次改动后检查浏览器 `http://localhost:4000` 验证编译是否通过
- 翻译：所有 `dgettext("projects", "...")` 字符串都需在 `priv/gettext/zh/LC_MESSAGES/projects.po` 有中文翻译
- 每次迭代更新版本号 (`root.html.heex` 中的 `Beta vX.Y.Z`) 并追加更新日志

## 代码风格
- 使用 `@spec` 类型注解标注公开函数
- 模式匹配优先，避免 `if/else` 嵌套
- 管道操作符 `|>` 保持数据流清晰
- 模块命名遵循 Phoenix 约定（`AstraAutoEx.Context` / `AstraAutoExWeb.Live`）
- 文件不超过 300 行（`show.ex` 除外，历史原因约 1800 行）
- 所有 async 操作（Task/GenServer）必须有超时和错误处理

## 关键文件路径
| 文件 | 用途 |
|------|------|
| `lib/astra_auto_ex_web/live/workspace_live/show.ex` | 主工作区 LiveView（最大文件，~1800行） |
| `lib/astra_auto_ex_web/live/home_live.ex` | 首页 + AI 写作 |
| `lib/astra_auto_ex_web/live/profile_live/index.ex` | 设置页（AI厂商/模型配置/提示词/计费） |
| `lib/astra_auto_ex_web/live/asset_hub_live/index.ex` | 素材库 |
| `lib/astra_auto_ex_web/components/layouts/root.html.heex` | 全局导航栏 + 版本号 |
| `lib/astra_auto_ex/workers/handlers/` | 所有任务处理器（image/video/voice/text/sd） |
| `lib/astra_auto_ex/ai/art_styles.ex` | 17+1 画风预设 |
| `lib/astra_auto_ex/ai/scene_enhancer.ex` | 场景类型→镜头风格映射 |
| `lib/astra_auto_ex/ai/prompt_catalog.ex` | 44 个双语提示词模板 |
| `lib/astra_auto_ex/billing/cost_estimator.ex` | Token 成本预估 |
| `lib/astra_auto_ex/production.ex` | 生产上下文（Episode/Clip/Storyboard/Panel/VoiceLine） |
| `lib/astra_auto_ex/characters.ex` | 角色上下文 |
| `lib/astra_auto_ex/tasks.ex` | 任务上下文 |
| `priv/gettext/zh/LC_MESSAGES/projects.po` | 工作区中文翻译（主要翻译文件） |
| `priv/gettext/zh/LC_MESSAGES/errors.po` | 错误消息中文翻译 |
| `assets/js/app.js` | JS Hooks（VideoPlayer/AudioPlayer/DragSort/ImageCrop） |

## 数据库 Schema 注意事项
- Episode: `novel_text` 存故事文本，`title` 存剧集名
- Panel: `image_url`, `video_url`, `shot_type`, `camera_move`, `description`
- Character → has_many CharacterAppearance（`image_url` 在 appearance 上）
- VoiceLine: 无 `status` 字段，通过 `audio_url` 是否为空判断完成状态
- NovelProject: `auto_chain_enabled`, `full_auto_chain_enabled`, `art_style`, `video_ratio`
- Task: `status` 可为 queued/processing/completed/failed

## 工作区 5 个阶段
1. **故事 (story)** — config_stage: 故事输入 + 比例 + 画风 + 自动链开关
2. **剧本 (script)** — script_stage: 剧本拆解 + 角色/场景列表
3. **分镜 (storyboard)** — storyboard_stage: 面板网格 + 图像生成 + 重试
4. **制作 (film)** — video_stage: 视频/配音生成 + 重试
5. **AI 剪辑 (compose)** — compose_stage: 左右分栏（面板选择+设置 | 预览+导出）

## 当前项目状态 (v0.6.1)
- 最后完成: 迭代 v0.6.1-v0.7.0 全量实施（7大commit，~3700+行）
  - Phase A: 42条翻译补全+5修正、导航栏Guide按钮、5步出片指南页、ImportWizard 4步向导
  - Phase B: 首页10比例+17画风+自定义+打字机动画、ProjectsLive项目管理页（图片数/视频数/完成度）、素材库5类CRUD表单+3新Schema+迁移、自动链暂停/恢复/停止控制器、AI写作handler、PipelineModal动画弹窗、计费ApiCallLog+CostTracker+BillingStats面板
  - Phase C: FlPromptRewriter首尾帧、VoicePresets音色、FirstLastFrame UI、AI剪辑预览放大
  - 集成: 全部组件挂载到父视图，0 errors 0 warnings
- 进行中: 无
- 下一步:
  - 端到端生成测试（需要有效 API Key 调通 AI 提供商）
  - 素材库"精调"功能实际接入图像编辑模型
  - MiniMax 2.8HD 300+ 系统音色 API 对接
  - 抽卡功能 UI（候选网格+选择+删除）
  - 剪映导出实际实现（XML 时间线格式）
  - 分镜一致性生图：collectPanelReferenceImages 逻辑深度实现
- 已知问题:
  - "Episode 1" 在标题中仍为英文
  - 自动链 toggle 开关 CSS 在部分主题下不显示滑块（需调试 peer-checked）
  - 计费统计数据为空（需要实际 API 调用后才有记录）

## 重要决策记录
- 从 Next.js 迁移到 Phoenix LiveView：利用 OTP 并发处理 AI 任务，无需 Redis/BullMQ
- 画风系统：17+1 预设从原项目 constants.ts 完整移植，每个含中英双语提示词
- 场景增强器：将 scene_type→镜头风格硬编码为 Elixir 映射，代替纯提示词方式
- Auto Chain 默认关闭：防止不成熟时浪费 Token 成本
- 配音批量生成：使用 voice_line IDs（不是 panel IDs），修复了原始实现的错误
- AI Edit 分栏：左 7 右 5 的 grid 布局，右栏放预览+导出
- 版本管理：每次迭代更新 root.html.heex 中的版本号，点击弹出更新日志

---

## ECC 工作流规范（Everything Claude Code 完整方法论）

> 基于 [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) 核心方法论，适配 Elixir/Phoenix 技术栈。

### 1. 会话开始（每次必做）

1. 读取本文件 `CLAUDE.md`，了解项目规范和当前状态
2. 运行 `git log --oneline -10` 和 `git status` 了解当前状态
3. 检查 `.claude/sessions/` 下最新的 session 文件（如存在）
4. 输出项目状态摘要，询问今天要做什么

### 2. 会话结束（每次必做）

1. **更新 CLAUDE.md** 中的「当前项目状态」部分：
   - 最后完成的工作
   - 进行中但未完成的任务
   - 下一步计划
   - 发现的问题和注意事项

2. **创建 session 文件**：在 `.claude/sessions/YYYY-MM-DD.md` 记录：
   - 完成的功能列表
   - 重要技术决策及原因
   - 遇到的坑和解决方案
   - 下次继续的起点

3. 如有未提交代码，生成建议的 git commit message
4. 记录本次会话的技术决策和踩坑

### 3. Planner Agent — 功能规划（写代码前先规划）

开始实现新功能前，先充当架构师角色输出实现蓝图：

1. **功能分解**：拆解成独立的子任务，标注依赖关系
2. **实现顺序**：按依赖顺序排列，标注哪些可以并行
3. **文件清单**：需要创建/修改的文件列表（含路径）
4. **接口定义**：先定义类型/`@spec`/数据结构，再实现逻辑
5. **验收标准**：每个子任务的完成标准
6. **风险点**：潜在的技术难点和应对方案

> 规划阶段不写任何实现代码。输出完成后等待确认再开始实现。

### 4. TDD 工作流（Red → Green → Refactor，不得跳步）

**必须严格按顺序执行，任何阶段不得跳过：**

#### RED 阶段（先写失败的测试）
1. 根据功能需求，先写测试用例（不要写实现代码）
2. 测试必须覆盖三类场景：
   - 正常情况（happy path）
   - 边界情况（空值、极值、并发）
   - 错误情况（无效输入、网络失败、超时）
3. 运行 `mix test`，确认测试失败（如果通过说明测试写错了）
4. 等待确认后再进入下一阶段

#### GREEN 阶段（写最少的代码让测试通过）
1. 只写能让测试通过的最简单实现
2. 不要过度设计，不要写测试没覆盖的代码
3. 运行 `mix test`，确认所有测试通过
4. 等待确认后再进入下一阶段

#### REFACTOR 阶段（重构，保持测试通过）
1. 消除重复代码
2. 优化命名和结构
3. 应用 Elixir 惯用模式（管道、模式匹配、with 语句）
4. 每次重构后立即运行 `mix test` 确认没有破坏
5. 输出重构前后的对比说明

**TDD 最终输出：**
- 测试文件完整代码
- 实现文件完整代码
- 测试覆盖率报告：`mix test --cover`（目标 ≥ 80%）

### 5. 验证循环（每次改动后必须执行）

按以下顺序依次运行，任何一步失败立即停下来修复，不得跳过：

| 步骤 | 命令 | 说明 |
|------|------|------|
| 1. 编译检查 | `mix compile` | 无 CompileError / KeyError / UndefinedFunctionError |
| 2. 格式检查 | `mix format --check-formatted` | 代码格式符合规范 |
| 3. 单元测试 | `mix test` | 所有测试通过 |
| 4. 覆盖率检查 | `mix test --cover` | 目标 ≥ 80%（关键模块） |
| 5. 浏览器验证 | 刷新 `localhost:4000` | 页面正常渲染，无运行时错误 |
| 6. 翻译检查 | 检查 `.po` 文件 | 新增的 `dgettext` 字符串有中文翻译 |
| 7. 版本更新 | 更新 `root.html.heex` | 如有重大改动，更新版本号 + 更新日志 |

**规则：**
- 任何一步 ❌ 失败 → 立即停止，显示错误详情，修复后从第 1 步重新开始
- 全部 ✅ 通过 → `git commit` + `git push`

### 6. Code Reviewer Agent — 代码审查

对当前修改进行全面评审，按严重级别分类：

#### 正确性
- [ ] 逻辑是否有 bug 或边界情况未处理
- [ ] 错误处理是否完整（`with` / `case` 的所有分支）
- [ ] 异步处理是否正确（GenServer 超时、Task race condition、未处理的消息）

#### 可维护性
- [ ] 函数是否单一职责（超过 50 行需拆分）
- [ ] 命名是否清晰表达意图
- [ ] 是否有重复代码需要抽取为共享函数

#### 性能
- [ ] 是否有 N+1 查询（Ecto preload 是否正确）
- [ ] 是否有不必要的重复计算
- [ ] 大数据量场景是否考虑（分页/流式处理）

#### 安全
- [ ] 用户输入是否经过验证（Ecto changeset）
- [ ] 是否有 SQL 注入 / XSS 风险
- [ ] 敏感信息（API Key）是否被硬编码（应使用环境变量）

**严重级别标记：**
- 🔴 **严重**：必须修复，影响功能正确性或安全性
- 🟡 **建议**：应该优化，影响可维护性或性能
- 🟢 **最佳实践**：可以改进，提升代码质量

### 7. 效率自检（周审）

每周对 Claude Code 使用方式进行 harness 效率审计，每项打分 1-10：

| 维度 | 检查内容 | 目标分 |
|------|----------|--------|
| **CLAUDE.md 完整度** | 技术栈说明、编码规范、项目状态记录 | ≥ 8 |
| **上下文利用率** | 每次 session 有明确任务目标，避免重复解释 | ≥ 8 |
| **测试覆盖** | 是否在写测试（TDD 或至少有测试），覆盖率 ≥ 80% | ≥ 7 |
| **验证习惯** | 改动后运行测试 / 编译检查 / 浏览器验证 | ≥ 9 |
| **Session 记忆** | 保存工作进度，记录技术决策，session 文件完整 | ≥ 7 |

**输出要求：** 总分 + 每项详细建议 + 优先改进的前 3 件事

### 快速参考：推荐使用顺序

```
1. 每次开始工作 → 会话开始（加载上下文）
2. 开发新功能   → Planner（规划）→ TDD（Red→Green→Refactor）→ Code Review（审查）
3. 功能完成后   → 验证循环（7步全跑）
4. 每次结束工作 → 会话结束（保存进度 + session 文件）
5. 每周定期     → 效率自检（Harness Audit）
```

---

## Git 分支
- `main`: 原始上传代码
- `claude/magical-jackson`: 所有改进（8个commit），待合并 PR
  - PR 链接: https://github.com/lexscnn-jpg/AstraAutoEx/pull/new/claude/magical-jackson
