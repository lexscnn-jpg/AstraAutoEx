# AstraAutoEx

AI 驱动的短剧自动化生产平台。输入故事创意或小说文本，自动完成从剧本到成片的全流程：

**小说/创意 → 剧本 → 分镜 → 角色设计 → 场景图 → 配音 → 视频生成 → 唇形同步 → 合成成片**

基于 Elixir Phoenix + LiveView 构建，OTP 原生并发替代 BullMQ，部署仅需 App + PostgreSQL。

## 技术栈

| 层 | 技术 |
|---|---|
| 语言 | Elixir 1.18+ / Erlang OTP 27+ |
| Web 框架 | Phoenix 1.8 + LiveView 1.1 |
| 数据库 | PostgreSQL 16 + Ecto (13 migrations, 16 performance indexes) |
| 任务队列 | OTP GenServer + DynamicSupervisor (无需 Redis) |
| 实时推送 | Phoenix PubSub + LiveView WebSocket (无需 SSE) |
| 存储 | 本地文件系统 / S3 (MinIO) |
| AI 提供商 | FAL, ARK, Google, MiniMax, API易, RunningHub (6 provider, 1:1 移植) |
| 前端 | Tailwind CSS 4 + Glass Design System + Heroicons |
| 视频合成 | FFmpeg (concat, speed adjust, SRT subtitles, BGM mix) |
| 部署 | Docker 多阶段构建 + docker-compose + GitHub Actions CI |
| 测试 | 152 tests, 0 failures |
| 许可证 | BSL 1.1 (2030-04-13 转 Apache 2.0) |

## 快速开始

### 环境要求

- PostgreSQL >= 16 (需单独安装并运行)
- Elixir + Erlang 已内置在 `tools/` 目录，无需单独安装

### 安装与启动

```bash
cd AstraAutoEx

# 加载开发环境 (自动设置 PATH)
source env.sh

# 安装依赖 + 创建数据库 + 运行迁移 + 构建前端资产
mix setup

# 启动开发服务器
mix phx.server
```

或使用快捷脚本：

```bash
bin/dev mix setup
bin/dev mix phx.server
```

打开 [http://localhost:4000](http://localhost:4000)

首次访问自动跳转到 Setup Wizard (4 步引导)：
1. 创建管理员账号
2. 配置 AI 提供商 + API Key
3. 选择存储方式 (本地 / S3)
4. 完成 → 自动登录

### Docker 部署

```bash
# 生成密钥
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# 启动 (App + PostgreSQL)
docker-compose up -d
```

应用启动后自动运行数据库迁移，访问 `http://localhost:4000`。

## 项目结构

```
lib/
├── astra_auto_ex/               # 业务逻辑层 (15 个 Context)
│   ├── accounts/                # 用户认证 (User, UserToken, UserPreference, UserBalance)
│   ├── projects/                # 项目管理
│   ├── characters/              # 角色 + 外观
│   ├── locations/               # 场景 + 场景图
│   ├── production/              # 制作流水线
│   │   ├── novel_project.ex     #   项目配置 (模型选择、链式模式)
│   │   ├── episode.ex           #   剧集 (小说文本、SRT、合成状态)
│   │   ├── clip.ex              #   场景片段 (内容、剧本)
│   │   ├── storyboard.ex        #   分镜合集
│   │   ├── panel.ex             #   分镜帧 (图片/视频/唇同步/候选图)
│   │   ├── shot.ex              #   镜头
│   │   └── voice_line.ex        #   台词 + 语音
│   ├── media/                   # 媒体对象 (stable public_id via SHA256)
│   ├── storage/                 # 存储适配器
│   │   ├── provider.ex          #   Behaviour 接口
│   │   ├── local_provider.ex    #   本地文件系统
│   │   ├── s3_provider.ex       #   S3 / MinIO
│   │   └── server.ex            #   GenServer 单例
│   ├── ai/                      # AI 提供商集成
│   │   ├── provider.ex          #   Behaviour (6 个回调)
│   │   ├── gateway.ex           #   路由分发
│   │   ├── async_poller.ex      #   统一异步轮询 (PROVIDER:TYPE:ID)
│   │   ├── capabilities.ex      #   模型能力注册表
│   │   └── providers/           #   6 个 Provider 实现
│   │       ├── fal.ex           #     FAL (Flux, Kling)
│   │       ├── ark.ex           #     火山引擎 (Seedream, Seedance)
│   │       ├── google.ex        #     Google (Imagen, VEO, Gemini)
│   │       ├── minimax.ex       #     海螺 (视频, TTS, 音乐)
│   │       ├── apiyi.ex         #     API易 (LLM + 图片 + VEO 三通道)
│   │       └── running_hub.ex   #     RunningHub (238+ 模型)
│   ├── workers/                 # OTP Worker 系统
│   │   ├── supervisor.ex        #   rest_for_one 监督树
│   │   ├── task_scheduler.ex    #   1s 轮询 DB 调度任务
│   │   ├── task_runner.ex       #   执行单个任务 + heartbeat
│   │   ├── concurrency_limiter.ex # ETS 并发控制
│   │   ├── handler_registry.ex  #   任务类型 → Handler 映射
│   │   └── handlers/            #   28+ Handler 实现
│   │       ├── image_handlers.ex    # ImagePanel, ImageCharacter, ImageLocation
│   │       ├── video_handlers.ex    # VideoPanel, LipSync, VideoCompose
│   │       ├── voice_handlers.ex    # VoiceLine, VoiceDesign, MusicGenerate
│   │       ├── text_handlers.ex     # StoryToScript, ScriptToStoryboard, ClipsBuild, etc.
│   │       ├── ai_asset_handlers.ex # AICreateCharacter/Location, AIModify*
│   │       ├── sd_handlers.ex       # SD 短剧 8 阶段工作流
│   │       └── handler_helpers.ex   # Provider dispatch, progress, storage
│   ├── tasks/                   # 任务管理 (44 种类型)
│   ├── billing/                 # 计费 (freeze → confirm → rollback)
│   ├── asset_hub/               # 全局素材库 (角色/场景/语音/文件夹)
│   ├── short_drama/             # 短剧系列 (8 阶段状态机)
│   └── workflows/               # 工作流引擎 (GraphRun/Step/Event)
│
└── astra_auto_ex_web/           # Web 层
    ├── router.ex                # 路由
    ├── plugs/                   # SetupRedirect, LocalePlug
    ├── controllers/             # PageController, FileController, UserSession
    ├── live/
    │   ├── setup_live.ex        # Setup Wizard (4 步, i18n)
    │   ├── home_live.ex         # 项目列表 (i18n)
    │   ├── workspace_live/      # 主工作区 (6 Stage + PanelEditor + Upload)
    │   ├── profile_live/        # 用户设置 (Providers / Models / Billing)
    │   ├── asset_hub_live/      # 全局素材管理 (角色/场景/声音)
    │   └── assistant_live/      # AI 助手 (LiveComponent + Standalone)
    └── components/              # 共享 UI 组件
```

## 数据库

38 个 Ecto Schema，10 个迁移文件，11 个 Context：

| Context | 表 | 说明 |
|---------|---|------|
| Accounts | users, user_preferences, user_balances | 认证 + 偏好 + 余额 |
| Projects | projects | 项目容器 |
| Characters | characters, character_appearances | 角色 + 外观变体 |
| Locations | locations, location_images | 场景 + 场景图 |
| Production | novel_projects, episodes, clips, storyboards, panels, shots, voice_lines | 制作流水线 |
| Media | media_objects | 统一媒体注册 |
| Tasks | tasks, task_events | 任务队列 + 事件审计 |
| Billing | balance_freezes, balance_transactions, usage_costs | 三阶段计费 |
| AssetHub | global_characters, global_character_appearances, global_locations, global_location_images, global_voices, global_asset_folders | 全局素材 |
| ShortDrama | series_plans, episode_scripts | 短剧规划 |
| Workflows | graph_runs, graph_steps, graph_step_attempts, graph_events, graph_checkpoints, graph_artifacts | 工作流引擎 |

## AI 提供商

| Provider | 能力 | 认证 | 异步轮询格式 |
|----------|------|------|-------------|
| FAL | 图片, 视频 | `Key {apiKey}` | `FAL:TYPE:endpoint:requestId` |
| ARK (火山) | 图片 (Seedream), 视频 (Seedance) | `Bearer {apiKey}` | `ARK:TYPE:taskId` |
| Google | 图片 (Imagen), 视频 (VEO), LLM (Gemini) | `x-goog-api-key` | `GOOGLE:VIDEO:operationName` |
| MiniMax (海螺) | 视频 (Hailuo), TTS, 音乐 | `Bearer {apiKey}` | `MINIMAX:TYPE:taskId` |
| API易 | LLM (OpenAI兼容), 图片 (Google SDK), 视频 (VEO) | `Bearer {apiKey}` | `OPENAI:VIDEO:token:videoId` |
| RunningHub | 图片, 视频, LLM, 音频 (238+ 模型) | `Bearer {apiKey}` | `RUNNINGHUB:TYPE:taskId` |

### API易 三条独立通道

| 通道 | 协议 | 说明 |
|------|------|------|
| LLM | OpenAI 兼容 | `POST /v1/chat/completions` |
| 图片 | Google GenAI SDK | base_url 去掉 `/v1`，用 Google SDK |
| 视频 | 自定义 VEO | `POST /v1/videos`，模型名自动拼接 `-landscape` / `-fl` 后缀 |

## OTP 监督树

```
Application
├── Repo (Ecto)
├── PubSub (Phoenix.PubSub)
├── Storage.Server (GenServer — provider 单例)
├── Workers.Supervisor (rest_for_one)
│   ├── ConcurrencyLimiter (GenServer + ETS)
│   │   └── 默认: image:20, video:5, voice:10, text:50
│   ├── TaskRunnerSupervisor (DynamicSupervisor)
│   │   └── TaskRunner × N (每个任务一个进程)
│   └── TaskScheduler (GenServer)
│       ├── 每 1s 轮询 DB 调度 queued 任务
│       └── 每 30s watchdog 扫描 stale 任务
└── Endpoint (Phoenix)
```

## 任务系统

44 种任务类型，4 个队列：

| 队列 | 并发 | 任务类型 |
|------|------|---------|
| image | 20 | image_panel, image_character, image_location, panel_variant, modify_asset_image, regenerate_group, asset_hub_image, asset_hub_modify |
| video | 5 | video_panel, lip_sync, video_compose |
| voice | 10 | voice_line, voice_design, asset_hub_voice_design, music_generate |
| text | 50 | analyze_novel, story_to_script, script_to_storyboard, ai_create_character, sd_* 等 |

任务生命周期：`queued → processing → completed / failed / canceled`

失败重试：指数退避 (2s × 2^attempt)，默认最多 5 次。Watchdog 每 30s 检测 heartbeat 超过 5 分钟的任务并标记失败。

## 计费系统

三阶段提交，Ecto.Multi 事务保证原子性：

```
freeze(amount) → 扣减 balance，增加 frozen_amount，创建 BalanceFreeze(pending)
    ↓
confirm(charged) → 结算实际费用，退还差额，BalanceFreeze → confirmed
    ↓ (失败时)
rollback(freeze_id) → 返还冻结金额，BalanceFreeze → rolled_back
```

## 国际化

Gettext 双语支持 (en / zh)，4 个翻译域：

- `default` — 通用 UI (Save, Cancel, Next, Back...)
- `auth` — 登录/注册
- `setup` — Setup Wizard
- `projects` — 项目列表

LocalePlug 自动检测 cookie / Accept-Language header。

## 路由

| 路径 | 页面 | 说明 |
|------|------|------|
| `/` | Landing | 首页 (未登录) |
| `/setup` | SetupLive | 首次启动引导 (4 步) |
| `/users/register` | Registration | 注册 |
| `/users/log-in` | Login | 登录 |
| `/home` | HomeLive | 项目列表 + 创建 |
| `/projects/:id` | WorkspaceLive | 主工作区 (7 Stage) |
| `/profile` | ProfileLive | 个人设置 |
| `/asset-hub` | AssetHubLive | 全局素材管理 |
| `/assistant` | AssistantLive | AI 助手 |
| `/api/files/*` | FileController | 本地文件服务 |
| `/dev/dashboard` | LiveDashboard | 开发监控 (仅 dev) |
| `/dev/mailbox` | Swoosh | 邮件预览 (仅 dev) |

## 常用命令

```bash
mix setup              # 完整初始化 (deps + db + assets)
mix phx.server         # 启动开发服务器
mix test               # 运行测试 (112 tests)
mix ecto.migrate       # 运行数据库迁移
mix ecto.reset         # 重置数据库
mix format             # 格式化代码
docker-compose up -d   # Docker 部署
```

## 配置

### 环境变量 (生产)

| 变量 | 说明 | 默认 |
|------|------|------|
| `DATABASE_URL` | PostgreSQL 连接串 | 必填 |
| `SECRET_KEY_BASE` | Phoenix 密钥 (64+ 字符) | 必填 |
| `PHX_HOST` | 域名 | localhost |
| `PORT` | HTTP 端口 | 4000 |
| `STORAGE_TYPE` | 存储类型 (local / s3) | local |

### S3 配置 (可选)

在 `config/runtime.exs` 或环境变量中设置：

```elixir
config :astra_auto_ex, :s3,
  bucket: "astra-auto",
  region: "us-east-1",
  endpoint: "https://s3.amazonaws.com",
  access_key_id: "...",
  secret_access_key: "..."
```

## 许可证

[Business Source License 1.1](LICENSE)

- 非生产用途免费
- 生产/商业用途需购买商业授权
- 2030-04-13 起自动转为 Apache License 2.0
