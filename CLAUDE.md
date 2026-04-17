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
- **版本号规则**（每次迭代必须执行）：
  1. 更新 `root.html.heex` 中的 `Beta vX.Y.Z`
  2. 更新 `CLAUDE.md` 中"当前项目状态"的版本号
  3. 在更新日志弹窗中追加本次更新内容
  4. 版本号遵循语义化：patch(bug修复) → minor(功能新增) → major(大版本)

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

## 当前项目状态 (v1.3.0)
- 最后完成: **v1.3.0 — 5 特性并行（流式 LLM + 撤销 + ZIP + Billing + OAuth）** (2026-04-17)
  - **v1.3.0 (2026-04-17) — 最大并行轮，一次性补 5 项原 Next.js 能力:**
  - 🌊 **流式 LLM 输出** (`lib/astra_auto_ex/ai/llm_streamer.ex`)
    - LLMStreamer Task.Supervisor 后台 stream，消息契约 `{:llm_chunk|:llm_done|:llm_error, stream_id, ...}`
    - `Helpers.chat_stream/3` dispatch — apiyi/google 原生 SSE，无流 provider 自动回退 chunk
    - home_live AI 写作弹窗接入，token 实时展示
  - ⏪ **撤销/撤回机制**
    - `Production.update_panel_image_with_history/2` 保留最近 10 版 revision
    - `Production.undo_panel_image/1` 一键回滚
    - image_handlers 全部改走 with_history 版本自动追踪
    - workspace_live `handle_event("undo_panel_image")` UI 入口
  - 📦 **批量 ZIP 导出** (`lib/astra_auto_ex_web/controllers/export_controller.ex`)
    - 内存 / tempfile 双路径（100MB 阈值）
    - 支持 http(s) 和 /uploads/ 两种源
    - 用户权限校验（get_project!/2）
    - route `/projects/:project_id/download/:kind` (images/videos/voices)
    - compose 阶段 UI 加 3 个下载按钮
  - 💳 **Billing Ledger 结算闭环** (`lib/astra_auto_ex/billing/ledger.ex`) — agent worktree 产出
    - `freeze/3`, `claim/2`, `release/1`, `topup/3` 核心 API
    - Ecto.Multi + SELECT FOR UPDATE 行锁保证并发安全
    - claim 按实付封顶，多余回补 balance
    - 全审计流水（balance_transactions 表）
    - 32 tests，Ledger 覆盖率 84.76%
    - 并发竞争测试通过（2 个 7 单位 freeze 对 10 余额只 1 个成功）
  - 🔐 **OAuth 第三方登录** (Google + GitHub) — agent worktree 产出
    - assent 库集成
    - `find_or_create_user_from_oauth/2` 支持邮箱 link 到已有 password 用户
    - 新 migration 加 oauth_provider/oauth_uid 字段 + 部分唯一索引
    - OauthController.request/callback，routes 在 /auth/:provider
    - login 页加 Google + GitHub 品牌按钮
    - auto-confirm OAuth 用户（provider 已验证邮箱）
    - 13 tests
  - 📈 **测试规模**：308 tests 0 failures (6 excluded)
  - 🏗️ **开发模式**：用户请求"全部都做，能并行的并行" → 2 agent worktree 并行 + 3 件主分支串行 = 一轮做 5 件 P0/P1
  - 📦 **commits**: 002d919 (A+B+C 我做), edaaa98 (D Billing agent), 22064b6 (E OAuth agent)
- 历史: v1.2.0 Circuit Breaker (2026-04-17)
  - **v1.2.0 (2026-04-17) — 从 retry-浪费 到 智能熔断:**
  - ⚡ **CircuitBreaker GenServer** (`lib/astra_auto_ex/ai/circuit_breaker.ex` · 280 行)
    - per-provider+capability 状态机：closed / open / half_open 三态
    - 3 连败自动熔断（configurable @consecutive_failure_threshold）
    - 5 分钟冷却（@cool_down_ms）后 half_open 探针
    - 探针成功 → closed 重置；探针失败 → open 重新计时
    - ETS public 表存状态，GenServer cast 序列化写，读走 :ets.lookup 零等待
  - 🔗 **tracked_call 集成** (`handler_helpers.ex`)
    - Call 前 `CircuitBreaker.allow?(provider, capability)`：若 `{:deny, _}` 立即返回 `{:error, :circuit_open}`，零 API 成本
    - Call 后 `CircuitBreaker.record(provider, capability, :success | :failure)`
    - 零侵入：所有 generate_image/video/text/tts 自动受保护
  - 🏁 **ProviderFallback 扩展**：@fallback_triggers 新增 "circuit_open" / "circuit open"，:circuit_open 错误自动触发跨 provider fallback
  - 🛡️ **Supervisor 注册**：`application.ex` children 加入 `AstraAutoEx.AI.CircuitBreaker`，随应用启动
  - 📊 **Observability UI 新区段** "⚡ Circuit Breaker 实时状态"：
    - grid 3-col 卡片布局
    - 彩色 border + background：open 红 / half_open 琥珀 / closed 绿
    - 每卡显示：provider/capability + 状态 chip + 连败数 + 累计失败/总调用
  - ✅ **测试**：10 unit tests (初始状态 / closed→open 阈值 / 独立熔断 / reset / 计数累积 / config 合理性)
  - 📈 **总测试规模**：42 tests (19 Guard + 10 Fallback + 3 Regen + 10 Breaker)
  - 🏗️ **架构演进**：v0.9.9=主动重写 / v1.0.0=重生 image / v1.1.0=可见 / **v1.2.0=会节流**
- 历史: v1.1.0 Observability 面板 (2026-04-17)
  - **v1.1.0 (2026-04-17) — 首次把 5218+ 次 API 调用数据可视化:**
  - 📊 **/observability 新 LiveView**：`lib/astra_auto_ex_web/live/observability_live.ex` (320 行)
  - 🎯 **数据层发现**：`api_call_logs` 表 + `CostTracker.log_call` + `tracked_call` wrapper 早已存在但无 UI，5218 条真实数据被埋没
  - 📈 **6 个展示区**：
    1. 4 KPI 卡（API 总数/成功/失败/成功率，动态着色 ≥90%绿/≥60%琥珀/≥30%橙/红）
    2. Provider × 能力矩阵表（provider×model_type 分组，total/succ/fail/rate/avg_latency）
    3. 🧬 Tier 2 Regen 事件区（purple ring 视觉强调，展示所有 image_regen 触发的任务）
    4. 🏁 Fallback 链区（最近 20 次跨 provider 切换的 billing_info 审计）
    5. Top 10 失败原因（error_message 前 60 字聚合）
    6. 最近 30 个有 billing 记录的任务（inline billing 摘要 + 状态 chip）
  - 🧭 顶部 nav 新增 **"观测"** 链接（bar-chart icon，介于短剧和 AI 助手之间）
  - 💡 **实际数据洞察**：
    - minimax/image: 4009 calls, 158 success (3.9%) — 审核大量 failed
    - minimax/text: 1017 calls, 1009 success (99.2%) — LLM 稳
    - apiyi/video: 39 calls, 16 success (41%) — 横屏首尾帧部分成功
    - google/text: 52 calls, 0 success — 用户未配 Google key
    - minimax/voice: 8 calls, 5 success (62.5%) — TTS 基本 ok
  - 🎨 响应式：grid 1-col mobile, 4-col desktop；KPI 卡 glass-surface 风格
  - 🔧 Ecto queries: group_by provider+type / fragment CASE WHEN for success counts / 按 billing_info JSONB 键筛选
- 历史: v1.0.0 正式版 — Tier 2 Image Regeneration，从"规避"到"治愈" (2026-04-17)
  - **v1.0.0 (2026-04-17) — Image-level rejection 的治愈级方案:**
  - 🧬 **ImageRegenerator 模块** (`lib/astra_auto_ex/ai/image_regenerator.ex`)
    - 当 Tier 1 provider chain 耗尽且错误是 image-level（未成年/minor/nsfw），自动用 LLM 重写 prompt 并重生 image
    - 双层 prompt 强化：sanitize_strict + 专用 image regen anchor（"专业成年角色肖像，30 岁以上职业装，纪实摄影风格"）
    - 默认走 MiniMax image-01（比 Gemini/apiyi 更宽松的审核策略）
    - 不污染 panel.image_url — 新 URL 通过 payload.override_image_url + billing_info.image_regen_new_url 传递
  - 📊 **ProviderFallback Tier 2 escalation**
    - 新决策类型 `{:image_regen, task}` 加入 maybe_trigger_fallback/1 返回值
    - `image_level_rejection?/1` 判定函数（patterns: 未成年/minor/underage/child/nsfw）
    - `_image_regenerated` 循环防护（一次性触发，第二次直接 :chain_exhausted）
  - 🔗 **VideoPanel 接入** `maybe_regenerate_image/3` helper
    - 检查 payload._image_regen_requested → 调 ImageRegenerator → 用 new_url 当 first_frame
    - effective_image_url 优先于 panel.image_url
  - 🔄 **AsyncPollWorker 处理 `{:image_regen, new_task}`** 与 `{:fallback, ...}` 对等
  - 📝 **Observability bug 修复**：error 分支 stale billing_info 快照会覆盖 image_regen report，改为 Tasks.get_task! 重读
  - ✅ **端到端验证**：Panel b7d96e1b
    - 原 prompt 871 字 → sanitize_strict + regen anchor 后 1411 字
    - MiniMax image-01 返回全新 `hailuo-image-algeng-data.oss-cn-wulanchabu.aliyuncs.com/...` URL
    - 新 image 传入 apiyi VEO（后续 transport timeout 非 Tier 2 bug）
  - 🏗️ **系统演进跨越**：v0.9.9 fallback 只能"切 provider 用同一 image"；v1.0.0 能"改 image 再跑"。质的突破
  - 📊 **测试**：32 unit (19 Guard + 10 Fallback + 3 Regen) + 端到端日志验证
- 历史: v0.9.9 超越原项目 — SafePromptGuard + ProviderFallback + Capability Matrix (2026-04-17)
  - **v0.9.9 (2026-04-17) — 用 Elixir/OTP 做原 Next.js 从未做的两件事:**
  - 🛡️ **SafePromptGuard 模块** (`lib/astra_auto_ex/ai/safe_prompt_guard.ex`)
    - 主动 prompt 重写防审核误判：关键词替换表（少女/young girl/young woman → 成年女性 / adult woman in late 20s）
    - 自动 age/context anchor 追加：`All characters are adults (over 25). Fully-clothed cinematic film still.`
    - 中英文检测自动选对应 anchor
    - sanitize_with_report 返回观测报告写入 task.billing_info
    - sanitize_strict 作为二次重试的"documentary-grade"版本
    - **19 个 unit tests 全通过**
  - 🏁 **ProviderFallback 模块** (`lib/astra_auto_ex/ai/provider_fallback.ex`)
    - 任务失败自动创建 fallback task 切换 provider（apiyi → minimax → ark）
    - @fallback_triggers 识别：包含未成年/sensitive/rate limit/usage limit/无可用渠道
    - effective_chain_for/2 动态按用户 api_key 过滤 chain（无 key 的 provider 从链里剥离）
    - billing_info 持久化 fallback_chain_tried 历史
    - **10 个 unit tests 全通过**
  - 📊 **Capability Matrix**（VideoPanel handler 内嵌）
    - `provider_supports_fl?(provider, model)`：apiyi VEO 3.1 → true，MiniMax Hailuo-2.3 → false
    - MiniMax provider 内部也加了 duration gate：Hailuo-2.3 固定 6s 不接受 duration 参数
    - 自动剥离不兼容参数，避免 "invalid params" 错误
  - 🔗 **AsyncPollWorker 集成 Fallback**：async task 失败时也调用 `maybe_trigger_fallback/1`，不限 sync handler
  - ✅ **端到端验证**：panel `df8df708` (apiyi 失败) → ProviderFallback 自动创建 `d6b5d42a` (minimax) → billing_info 链记录完整
  - 🎯 **超越原 Next.js 项目**：探索报告确认原项目对这两个方向**完全没做**（ERROR_CATALOG 有 SENSITIVE_CONTENT 定义但无实际处理；provider router 只是 3 行 if-else）
- 历史: v0.9.8 apiyi VEO 3.1 横屏首尾帧打通 + 4 个 async 链路 P0 修复 (2026-04-16)
  - **v0.9.8 (2026-04-16) — 第二个视频 provider 全链路跑通**:
  - 🎬 **apiyi VEO 3.1 真跑通**：Panel 06347c45 产出 `https://r2cdn.copilotbase.com/r2cdn2/59638cab-5a70-4a0b-9445-4c2af4d17d9a.mp4`，apiyi 横屏首尾帧异步完整链路打通
  - 🔴 P0 模型名双重 transform：handler 里 apply_model_suffix 产生错序 `veo-3.1-fast-landscape-fl`，改为完全让 apiyi provider 内部 `transform_veo_model/1` 处理（生成正确的 `veo-3.1-landscape-fast-fl`）
  - 🔴 P0 Req multipart 2-tuple 格式：`build_file_part` 从 `{field, filename, data, opts}` 改为 `{field, {data, [filename:, content_type:]}}`
  - 🔴 P0 AsyncPoller config 查找：external_id prefix "OPENAI" 要先 `provider_key_from_prefix` 映射到 "apiyi" 再 `Map.get(user_config, key, %{})`，之前 config 永远空崩 api_key fetch
  - 🔴 P0 external_id 4 段解析：apiyi 格式 `OPENAI:VIDEO:base64_token:video_id`，AsyncPoller 新增 token 剥离逻辑（Base.url_decode64 确认是 token 才剥）
  - 🟢 header content-type list pattern：Req 新版 header value 可能是 list，加 `{"content-type", [ct | _]} when is_binary(ct)` 分支
  - 🟢 VideoPanel auto-FL：新增 `find_next_panel_image/1`，默认找下一 panel image 作为 last_frame 启用 VEO -fl 模式
  - 🟢 VideoCompose 第 4 版：**4.5MB / 52s** 混合视频（2 真视频 + 11 静态图 + 字幕 + TTS），比 v0.9.7 多 1.1MB
  - 🔍 **观察**：VEO 3.1 对"少女/young woman"类场景触发内容审核（3/3 批量失败），需要 prompt 规避策略
- 历史: v0.9.7 混合 AI 视频合成 + 短剧 3 步串联 + 视频分享页上线 (2026-04-16)
  - **v0.9.7 (2026-04-16) — 端到端 AI 短剧链路验证完成**:
  - 🎬 **混合 AI 视频合成**：1 真 MiniMax I2V 视频 + 12 静态图像片段 + 字幕 + 中文 TTS 旁白 → **3.4MB / 52s 完整短剧** mp4
  - 🎭 **短剧 3 步串联实测**：sd_topic_selection 已完成（"闪婚后，傅总真香了"等）→ sd_story_outline 通过 load_previous_result 获取上下文生成 "消失的丈夫" 悬疑大纲 → sd_character_dev 生成"陆景琛"角色卡
  - 🔗 **视频分享页发布**：/m/dueS9TfqTgA 渲染 HTML5 video + 剧集标题，可无需登录访问
  - 📊 **V1 批量 11 个 video_panel 任务实测**：2 completed / 15 failed（7 "usage limit exceeded" / 4 "invalid params" 遗留 / 4 "rate limit exceeded"）— MiniMax 视频生成额度有限
  - 🔧 user_preferences 默认 video 模型：`minimax-hailuo-2.3` → `MiniMax-Hailuo-2.3`（大写接受）
  - ✅ V3 AutoChain 确认已实现：image_panel 全部完成后，若 `full_auto_chain=true` 自动触发 video_panel（[image_handlers.ex:320](lib/astra_auto_ex/workers/handlers/image_handlers.ex:320)）
- 历史: v0.9.6 真实 MiniMax I2V 视频 + 短剧串联 + 4 个 P0 修复 (2026-04-16)
  - **v0.9.6 (2026-04-16) — 真实视频生成打通 + 异步轮询流畅**:
  - 🎬 **真实视频生成跑通**：Panel 8a88fe20 获得 MiniMax Hailuo-2.3 生成的 MP4 URL（OSS CDN）
  - 🔴 P0 TaskRunner 加 `{:async, _}` 返回语义：handler 返回 :async 时保留 processing 状态，不走 mark_completed，让 AsyncPollWorker 接管
  - 🔴 P0 VideoPanel 异步分支改走 `{:async, result}` 而不是 `{:ok, result}`
  - 🔴 P0 AsyncPollWorker.atomize_keys/1 对非 map config value 崩（FunctionClauseError）→ 加 catch-all
  - 🔴 P0 apply_model_suffix 只对 API易（VEO 模型）应用 -landscape/-fl 后缀，MiniMax/ARK 跳过（之前导致 "invalid params, incorrect model param input"）
  - 🔴 P0 VideoPanel request 同时设 `:image_url` + `:first_frame_image`（MiniMax 读后者）
  - 🟢 ShortDrama.build_bindings 补 `topic_keyword`（之前 sd_topic_selection 完全没读 UI 传入的关键词）
  - 🟢 新增 `load_previous_result/2`：下游 sd_story_outline / sd_character_dev / sd_episode_directory 自动读上游 task.result.raw 作上下文
  - 🔍 MiniMax 视频模型可用性实测：T2V 可用 `MiniMax-Hailuo-2.3`；I2V-01/Director/live 需 first_frame_image；Hailuo-02 当前 token 不支持
- 历史: v0.9.5 真实 TTS + 有声视频合成 + 短剧 LLM 跑通 + 依赖锁定 (2026-04-16)
  - **v0.9.5 (2026-04-16) — 视频从静音变有声、短剧从空入口到真实跑通:**
  - 🎙️ **真实 TTS 跑通**：voice_line handler 调 MiniMax t2a_v2，5 条中文旁白→32kHz mono PCM_S16LE WAV
  - 🔴 P0 修复 Access.get/3 崩溃：MiniMax TTS response body 用 get_in 抓 hex audio 时遇非 map 崩，改 pattern match
  - 🆕 新增 `save_hex_as_wav/2`：Base.decode16 hex 数据 → 写 `/uploads/voice/tts-<id>.wav` → 返回 download_url
  - 🎬 **有声视频合成**：项目 13 compose 产出 **2.6MB / 48.2s / H.264 视频 + AAC 44.1kHz stereo 音频双流**（纯图片版 2.2MB 相比多出 0.4MB 就是 TTS 音频）
  - 🆕 VideoCompose 新增 `build_voice_segments/1`：从 voice_lines 聚合 audio_path/start_time 传 FFmpeg filter_complex
  - 🆕 `resolve_local_audio/2`：`/uploads/voice/xxx.wav` → `priv/uploads/voice/xxx.wav` 本地路径映射
  - 🎭 **短剧 sd_topic_selection LLM 跑通**：MiniMax 返回 `{title_candidates, genre, sub_genres, target_audience, tone, episode_count, episode_duration...}` 完整 JSON
  - 🆕 短剧卡片依赖锁定：`@prerequisites` map 定义 1→2→3→4→5 线性依赖 + 5→6/7/8 分支；前置未完成时卡片 opacity-60 + 🔒 标签 + 按钮 disabled
  - 🆕 短剧结果展示：完成后"查看结果 ▼" 按钮展开 LLM raw text（font-mono + max-h-60 滚动 + MapSet expanded 控制每步独立折叠）
- 历史: v0.9.4 字幕 burn-in + 短剧 8 任务 UI + Panel 编辑器验证 + LipSync schema (2026-04-16)
  - **v0.9.4 (2026-04-16) — 字幕烧录成功 + 短剧入口上线:**
  - ✅ **字幕 burn-in 真实成功**：帧截图验证 "[旁白] 雨夜，一个疲惫的身影出现在车库入口" 白字黑描边烧到画面底部
  - 🆕 `FFmpeg.simple_concat/3` 支持 subtitle_path：有字幕时走 reencode_concat + `subtitles='...':force_style='...'` filter
  - 🆕 Windows 路径字幕 filter 适配：反斜杠→正斜杠 + 冒号转义（`C:/path` → `C\:/path`）
  - 🆕 **短剧 8 任务 UI**：/short-drama LiveView + 2x4 卡片网格 + nav "短剧" 链接 + 项目选择器 + 选题关键词输入 + PubSub 订阅实时状态
  - 🆕 步骤状态 chip：已完成(绿) / 运行中(蓝) / 失败(红) / 排队中(灰) + 进度%
  - 🔴 P1 预防性: LipSync handler 用 `panel.audio_url` 字段不存在 → 新增 `Production.voice_line_for_panel/1` 从关联 VoiceLine 表读 audio_url
  - ✅ Panel 编辑器验证: DB round-trip 测试 7 字段（description/shot_type/camera_move/location/characters/photography_rules/acting_notes）全正确写入
  - ✅ SubtitleGenerator 需要 audio_url 非空：为测试补 placeholder audio_url，字幕路径才会触发
- 历史: v0.9.3 Compose 端到端跑通 + 敏感词自愈 + sync_global_assets 验证 (2026-04-16)
  - **v0.9.3 (2026-04-16) — 🎉 首个真实合成视频产出:**
  - ✅ **真实视频合成成功**：项目 13 产出 `priv/uploads/compose/projects/13/video/compose-*.mp4`，**2.2MB / 48.2 秒 / 12 个面板**
  - 🆕 新增 `AstraAutoEx.Media.FFmpeg.image_to_video/3`：静态图像 → libx264 视频片段（tune=stillimage + 静音轨方便后续混音）
  - 🆕 新增 `AstraAutoEx.Media.FFmpeg.simple_concat/2`：concat demuxer 作为 filter_complex 失败的自动回退
  - 🆕 VideoCompose 接入图像回退：无 `panel.video_url` 时从 `panel.image_url` 渲染静态片段后再 concat
  - 🔴 P0 修复 schema 不一致：Storyboard 无 `:sort_order` / Panel 用 `:panel_index` / Panel 无 `:audio_url` 与 `:duration`
  - 🔴 P0 修复输出路径：storage_key 含 `projects/N/video/...` 嵌套，compose handler 补 `File.mkdir_p(Path.dirname(output_path))`
  - 🔴 P0 修复 Elixir `or` 严格类型：`p.video_url && p.video_url != ""` 返回 nil 导致 `or` 崩溃，改为 `is_binary && != ""` + `or`
  - 🟢 `run_ffmpeg` 错误传播：不再吞 stderr，真实错误进 task.error_message（之前全报 "output file not found"）
  - 🟢 ImagePanel 敏感词自愈：捕获 "sensitive"/"content_policy"/"敏感"/"violat"，用关键词替换表（刺青→手腕花纹等）重写 prompt 重试一次
  - 🟢 sync_global_assets 实测生效：新项目 14 → characters 表出现 "苏晚"/"玄墨"（之前项目 12 的是 0 角色状态）
  - 🟢 LLM prompt 增强：screenplay prompt 显式要求 clip-level + panel-level `characters`/`location` 数组
  - 🟢 .mp4.mp4 重复后缀 bug 修复：Provider.generate_key 已带 ".mp4"，compose 不再重复添加
- 历史: v0.9.2 全管线真实 API 跑通 + 数据修复 + UI 打磨 (2026-04-16)
  - **v0.9.2 (2026-04-16) — 端到端真实验证 + P0 数据修复:**
  - ✅ **真实 MiniMax API 端到端跑通**：创建项目 13 "雨夜特警"，story→script 2分32秒 / script→storyboard 生成 3 storyboards + 13 panels / image_panel 11/13 成功（85%）
  - 🔴 P0 修复: persist_script_results 传了 `title`/`sort_order`/`project_id` 等**不在 clip schema cast 列表**的字段，全部被静默丢弃。改走 `clip_index` / `characters` / `location` / `screenplay` 等正确字段
  - 🔴 P0 修复: LLM 返回的 `characters` 常是 JSON array（如 `["林岳","神秘少女"]`），schema 要 `:string` → cast 静默失败 → 存为 nil。加 `to_string_field/1` 强制 list→"A, B" 连接
  - 🔴 P0 修复: 剧本阶段右侧 characters/locations 面板始终 0 — `parse_and_persist_analysis` 只在 `analyze_novel` 路径调用，但 StoryToScript 流程跳过它。新增 `sync_global_assets/4` 在 persist_script_results 内聚合 clip/panel 级角色地点，upsert 到全局表
  - 🟡 P1 修复: Watchdog `@stale_threshold` 5 分钟 → 10 分钟，避免 ScriptToStoryboard 长任务（13 panels 顺序生成约 6 分钟）被误判为 stale
  - 🟢 新增: panel 卡片 hover 操作条从 1 按钮扩展为 3 按钮（生成/编辑/删除）+ Production.delete_panel/1 + handle_event("delete_panel") + data-confirm
  - 🟢 新增: TypewriterHero hook 支持 `data-texts` 多句轮播（"|" 分隔），5 个创意场景循环打字删除
  - 🟢 新增: AiWriteModal 增加独立 :error 阶段（红色 alert + 重试按钮 + 取消），取代 put_flash 单一处理
  - 🟢 新增: 首页长文本提示条（> 1000 字），橙色警告 + 引导用集数下拉分集
  - 🟢 清理: music_generate_handler 删除错误复用 poll_task 的死代码分支，消除 4 个类型不匹配警告
  - 🟢 翻译: projects 域追加 Clip 片段编号占位符 / AI Generation Failed / Retry / Cancel
- 历史: v0.9.1 像素级重构使之能用 — 启动链路打通 + 5 阶段端到端 LiveView 渲染验证 (2026-04-16)
  - **v0.9.1 (2026-04-16) — 像素级重构使之能用:**
  - 启动: start.bat 修复 Device Guard 拦截（PATH 优先 `C:\Program Files\Erlang OTP\bin`）
  - 启动: 新增 .claude/phx-wrapper.bat + 修改 .claude/launch.json 让 preview 工具能启动 Phoenix
  - P0 修复: 剧本阶段切换崩溃 — clip.title / char.image_url / loc.image_url / char.description 字段不存在
  - P0 修复: 新增 character_thumb/1 + location_thumb/1 helper（从 has_many 关联安全取首图）
  - 新增: panel 卡片补漏的道具标签渲染（emerald 色 tag）
  - 清理: music_generate_handler 删除错误复用 poll_task 的死分支（4 个类型不匹配警告全消）
  - P1 优化: TaskScheduler 频率 1 秒 → 5 秒；Watchdog 30 秒 → 60 秒
  - P1 优化: dev.exs logger 级别 → :info（SQL 调试日志不再淹没）
  - i18n: projects 域追加 `Clip #%{n}` → "片段 #%{n}"
  - 验证: 5 阶段 LiveView 全部正常渲染（故事/剧本/分镜/成片/AI 剪辑）
  - 验证: 设置页 (9 厂商 + 4 Tab) / 素材库 / 使用手册 / 项目列表 全部 OK
  - 数据: 项目 12 已实跑过完整管线（124 个面板生成图像，多张电影感截图）
- 历史: v0.9.0 灵魂补全 — 核心管线逻辑 + 缺失Handler + FFmpeg增强 + AutoChain DAG + 33翻译域 (2026-04-15)
  - **v0.9.0 (2026-04-15) — 灵魂补全:**
  - 新增 Handler: VoiceDesignHandler(语音克隆) + MusicGenerateHandler(BGM生成) + Watchdog(看门狗) + ShortDrama(短剧8任务) + StoryboardInsert(面板插入) + ShotVariant(镜头变体)
  - FFmpeg: xfade转场滤镜图 + filter_complex动态构建 + 3轨音频混音(0.3/1.0/1.0) + FL尾帧跳过
  - AutoChain: 统一DAG触发器(4触发点+dedupeKey+PubSub) + TaskRunner集成
  - FL首尾帧: 模型名后缀(-landscape/-fl) + 智能配对评分
  - JSON安全: 双引号→「」+ safe_json_decode
  - 角色一致性: 别名"/"匹配 + CHARACTER_PROMPT_SUFFIX自动追加
  - LipSync预处理: 2s最小填充 + 超长裁剪 + WAV块对齐
  - Web: 视频分享页(/m/:public_id) + 脚本导入增强 + 面板拖拽排序 + 22种错误码
  - i18n: 33翻译域完整匹配原项目, 1661条翻译
  - HandlerRegistry: 36种任务类型注册, SD 8种统一路由
  - 测试: 224 tests, 0 failures (+28个新测试)
- 之前: v0.8.2 暗色主题 + 全局AI助手入口 + 内容不重叠 (2026-04-15)
  - **v0.7.0-v0.7.2:** 核心管线打通 + 配音 + 合成 + 一致性生图 + 首尾帧抽卡 + 集数选择器 + 管线动画
  - **v0.7.3:** 口型同步(FAL/Vidu/Bailian) + 素材库项目列表 + 翻译审计
  - **v0.7.4:** 异步轮询系统 + Vidu/Bailian Provider + 6项 Bug 修复
  - **v0.7.5:** 5项 Bug 修复 + 合并到 main
  - **v0.7.6:** 工作区修复 + 计费热力图 + 集数管理
  - **v0.7.7 (2026-04-15):**
  - 修复：模型配置 Tab 崩溃（missing assigns: model_test_result, testing_model_step）
  - 新增：MiniMax chat/2 LLM 接口（/text/chatcompletion_v2）
  - 修复：模型测试结果 Map→String 崩溃（正确提取 content 字段）
  - 修正：MiniMax 模型 ID（MiniMax-M2.7-highspeed，非 m2.7-highspeed）
  - 修复：测试请求传递 model ID（之前缺失导致用错误默认值）
  - 核心：Helpers.chat 请求格式标准化（contents→messages 自动转换）
  - 核心：chat 结果标准化（%{content: str}→str，兼容所有 handler）
  - 新增：管线进度横幅（active_tasks 实时显示 + 任务类型中文标签）
  - 新增：auto_chain/full_auto_chain 持久化到 NovelProject DB
  - 新增：aspect_ratio/art_style 选择持久化（项目级别保存）
  - **v0.7.8 (2026-04-15):**
  - 核心：管线请求标准化（Google contents→OpenAI messages 自动转换）
  - 核心：智能模型路由（按 step ID 查找，fallback 到 type 匹配）
  - 优化：中文 pipeline prompt（MiniMax 输出质量提升）
  - 新增：compose 管线字幕嵌入步骤（SRT→视频）
  - UI：阶段指示器增强（完成✓ + 当前高亮 + 过渡动画）
  - **v0.7.9 (2026-04-15):**
  - 修复：generate_all_voices 改为遍历 voice_lines（之前错误遍历 panels）
  - 修复：generate_all_videos 仅为有图片无视频的面板生成
  - 修复：run_story_to_script 从占位改为实际创建管线任务
  - UI：首页"开始创作"加载 spinner 动画
  - UI：面板底部三色管线进度条（图片/视频/配音）
  - UI：面板标签增强（视频/配音/口型同步彩色标签）
  - **v0.8.0 (2026-04-15):**
  - 核心：AI 助手消息回路修复（send_update 模式替代 send(self())）
  - 核心：AI 助手注入项目上下文（名称/角色/场景/故事摘要 → system prompt）
  - UI：浮动 AI 助手按钮（右下角渐变圆按钮 + hover 放大）
  - UI：面板滑入动画（animate-slide-in-right）
  - UI：快捷提问按钮（分析故事/建议镜头/生成文案）
  - 研究：Flova.ai 竞品研究报告（docs/flova-research-report.md）
- 进行中: 无
- 进行中: 无
- 下一步:
  - 端到端生成测试（真实 API 调用走完 故事→剧本→分镜→图像→视频→配音→合成 全流程）
  - 真实 API 调用端到端测试（用 MiniMax 跑一个新项目从故事 → 成片）
  - 像素级 UI 对齐细节（hover 卡片操作条、AI 写作模态框 4 阶段、首页 Hero 打字机效果）
  - 短剧 8 任务系统的真实场景验证
- 已知问题:
  - 计费统计数据为空（需要实际 API 调用后才有记录）
  - VoiceDesign/MusicGenerate 仅同步 API 验证，异步路径未实现（设计上 MiniMax 无异步音乐 API）
  - LiveView 热重载偶尔不生效（已知 :econnaborted），改 LiveView 模板时需手动重启 phx.server
  - 项目 12 中部分剧本字段（characters）为 nil，剧本阶段右侧角色卡为空
- 启动方法:
  - **方式 1（推荐）**：双击 `start.bat`（已修复 PATH 自动绕过 Device Guard）
  - **方式 2（开发）**：在 bash 里 `export PATH="/c/Program Files/Erlang OTP/bin:$PATH"` 后执行 `mix phx.server`
  - **方式 3（Claude Code）**：使用 preview_start "phoenix"（自动走 .claude/phx-wrapper.bat）
  - 测试账号: 5078534@qq.com / Test1234!@（已重置）

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
