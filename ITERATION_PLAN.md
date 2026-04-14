# AstraAutoEx 迭代实施蓝图 v0.7.0（修订版 R2）

> 基于 ECC Planner + 2 轮用户审阅 + 原项目深度代码分析 + MiniMax API 研究。

---

## 实施顺序与依赖关系

```
Phase A (基础修复)              Phase B (核心功能)              Phase C (高级功能)
┌─────────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│ A1. 翻译检查 (#3)    │     │ B1. 素材库5类CRUD    │     │ C1. 首尾帧核心 (#6)  │
│ A2. 导航栏+手册 (#7) │     │ B2. 首页全面修复 (#4)│     │ C2. 配音+字幕 (#6)   │
│ A3. 4步引导 (#5)    │     │ B3. 项目页核心 (#6)  │     │ C3. AI剪辑优化 (#6)  │
└─────────────────────┘     └──────────────────────┘     └──────────────────────┘
```

---

## Phase A：基础修复（可并行）

### A1. 翻译检查 (#3)
- 扫描全部 `dgettext`/`gettext` 调用，补全缺失中文翻译
- 重点：panel_editor.ex、素材库、首页
- **文件：** `projects.po`, `errors.po`

### A2. 导航栏优化 (#7)
- 右侧 flex 增加 gap + padding
- 新增"使用手册"按钮 → `/guide` 页面（5分钟出片指南）
- **文件：** `root.html.heex`, **新建** `guide_live.ex`, `router.ex`

### A3. 4步引导流程 (#5)
- **新建** `ImportWizard` LiveComponent（来源→解析→映射→确认）
- config_stage 中嵌入"智能导入"按钮
- **文件：** **新建** `import_wizard.ex`, `show.ex`

---

## Phase B：核心功能

### B1. 素材库 5 类完整 CRUD (#1 + #2)

**5 类资产：**

| 资产 | Schema | 创建字段 | 生图 |
|------|--------|---------|------|
| 角色 | GlobalCharacter + Appearance | 名称、别名、简介 | 三视图（左1/3正面特写 + 右2/3三视图排列） |
| 场景 | GlobalLocation + Image | 名称、画风、描述 | 场景参考图 |
| 道具 | **新建** GlobalProp | 名称、类型、描述 | 道具设定图（左1/3主视图 + 右2/3三视图） |
| 音色 | GlobalVoice | 名称、性别、语言 | 试听预览 |
| 音效/音乐 | **新建** GlobalSfx / GlobalBgm | 名称、类别 | 文件上传 / MiniMax 生成 |

**生图方式（可选）：**
- **文生图**（默认）：纯提示词生成
- **图生图 + 提示词**（新增）：上传参考图 → 配合提示词 → image-to-image 生成
  - 支持上传最多 5 张参考图（原项目 `referenceImageUrls` max 5）
  - 同时输入描述提示词，引导生成方向

**抽卡机制（参考原项目 `normalizeImageGenerationCount`）：**
- 每次生成可设置**候选数量**（1-4 张），默认 1
- 生成后以网格展示所有候选
- 用户**择优选择**一张作为最终参考图（`selectedIndex`）
- **删除**不需要的候选（释放存储空间）
- 支持"再抽一轮"重新生成新候选

**每类资产的完整操作：**
- **全部生成**：一键为所有未生成的资产批量生成
- **单个生成**：为指定资产生成
- **全部重试**：重新生成所有失败的
- **单个重试**：重新生成指定失败的
- **删除**：删除参考图（保留资产记录）
- **精调**：指令式图像修改（原项目 `modify-asset-image` 逻辑）
  - 输入：修改指令文本 + 可选额外参考图
  - 流程：加载当前图 → 配合修改提示词 → 调用编辑模型 → 更新图片
  - 保留前一版本（支持撤销）

**音效/音乐 — MiniMax API 集成：**
- 模型：`music-2.6`（用户订阅 MAX 极速版）
- 端点：`POST https://api.minimaxi.com/v1/music_generation`
- 参数：prompt（风格/情绪/场景）、lyrics（歌词，支持 [Verse]/[Chorus] 结构标签）
- 支持纯音乐模式（`is_instrumental: true`）
- 输出格式：URL（24小时有效）或 hex

**新增文件：**
- `character_form.ex`, `location_form.ex`, `prop_form.ex`, `voice_form.ex`, `music_form.ex`
- `global_prop.ex`, `global_sfx.ex`, `global_bgm.ex` (schema)
- 数据库迁移文件
- `asset_hub.ex` 补全 CRUD 函数

---

### B2. 首页全面修复 (#4)

#### B2.1 画面比例（扩展为 10 种 + 场景标签）

| 比例 | 场景标签 | 典型用途 |
|------|---------|---------|
| **16:9** (默认) | 横屏 · 长视频 | B站/YouTube/电脑端 |
| **9:16** | 竖屏 · 短剧/短视频 | 抖音/快手/ReelShort/DramaBox |
| **1:1** | 方形 · 封面/头像 | 社交平台通用 |
| **3:2** | 横屏 · 风景/剧情 | 风景类短剧 |
| **2:3** | 竖屏 · 海报/数字人 | 角色海报/数字人立绘 |
| **4:3** | 横屏 · 传统电视 | 老素材/保守裁切 |
| **3:4** | 竖屏 · 数字人直播 | 数字人直播带货/图文混排 |
| **5:4** | 横屏 · 广告Banner | PC端广告横幅 |
| **4:5** | 竖屏 · 信息流广告 | 社交信息流广告投放 |
| **21:9** | 超宽 · 电影感 | 电影级大片/全景镜头 |

- 线框预览图标（按比例渲染矩形块）
- 默认 16:9

#### B2.2 画风选择器 — 预设 + 自定义向导

**预设部分：** 接入 `ArtStyles` 模块 17 种预设，中文标签下拉

**自定义画风（参考原项目 `artStyle === 'custom'` 逻辑）：**
- 选择"自定义"后展开编辑区域
- **填写向导**：提供默认模板（基于最接近的预设提示词）
- **用户只需修改核心描述**，模板结构保持不变
- 自定义提示词存储在 `NovelProject.art_style_prompt` 字段
- `getArtStylePrompt()` 逻辑：custom → 返回用户自定义；预设 → 返回对应中文提示词

#### B2.3 AI写作闪退修复
- 检查 `dispatch_ai_outline` 错误处理

#### B2.4 标题动画（TypewriterHero）
- JS Hook：逐字打字（55ms/字）+ 删除 + 循环
- 主标题 focus-pull 呼吸动画 CSS
- 每字弹入（scale + bounce）

#### B2.5 项目管理页（`/projects`）
模块化卡片显示：
- 项目名称 + 简介（2行截断）
- 主要人物（头像列表）
- **集数统计**
- **图片数量**（已生成分镜图数 / 总面板数）
- **视频数量**（已生成视频数 / 总面板数）
- **完成度**（百分比进度条）
- 最后更新时间
- 分页（8个/页）+ 搜索 + 编辑/删除

#### B2.6 "查看全部"链接 → `navigate={~p"/projects"}`

**新增文件：** `projects_live/index.ex`, `router.ex` 路由

---

### B3. 项目页核心功能 (#6)

#### B3.1 自动链/全自动 — 暂停/恢复/停止控制器
- 开关 UI + tooltip 说明
- **运行时控制器**：
  - ⏸ **暂停**：暂停当前步骤后的自动继续
  - ▶ **恢复**：从暂停处继续
  - ⏹ **停止**：终止管线，保留已完成结果
- 状态机：`idle → running → paused ↔ running → stopped`
- 控制器仅在管线运行时显示

#### B3.2 "AI帮我写" — 集数选择 + 使用提示

**管线中的角色：** 仅用于**故事阶段**，从灵感生成大纲。后续步骤（剧本拆解→分镜→视频）由管线自动完成。

**实现：**
- 添加 `phx-click="open_ai_write"` 事件
- 弹窗内**灰度使用提示**：
  > "输入创意灵感，AI 生成完整故事大纲。确认后管线自动进行剧本拆解、角色/场景提取、分镜生成。"
- **集数选择器**：数字输入框（1-100集），默认根据内容长度自动推算
- 集数写入 LLM 提示词：`"请将故事拆分为{episode_count}集，每集..."`
- 复用为共享 LiveComponent（首页+项目页共用）

#### B3.3 "开始创作"按钮
- 同样增加**集数选择**（如果故事阶段有内容但未设置集数）
- 增加**使用提示**弹出说明管线将执行的步骤
- 管线启动动画弹窗（`pipeline_modal.ex`）：
  - 渐变旋转 spinner + 星光图标
  - 旋转状态文字 + 渐变进度条 + 计时器
  - 毛玻璃遮罩

#### B3.4 角色/场景/道具提取 — 移植原项目 orchestrator

**原项目三阶段（`orchestrator.ts`）：**
1. 并行 LLM 分析：角色(`analyze_characters`) + 场景(`analyze_locations`) + 道具(`analyze_props`)
2. Clip 分割：边界锚点匹配，每 clip 关联 location + characters[] + props[]
3. 剧本转化：合并提取结果 + clip 内容

**Elixir 移植：**
- `Task.async_stream` 并发 3 个 LLM 调用（替代 `Promise.all`）
- JSON 解析 + 容错（`safeParseJsonObject` 等价）
- 合并去重：LLM 提取 + 素材库已有资产
- 写入 checkpoint 支持断点恢复

**完整操作按钮（参考原项目，每类实体）：**
- **全部生成** — 一键为所有提取出的角色/场景/道具生成参考图
- **单个生成** — 为指定实体生成参考图
- **全部重试** — 重新生成所有失败的
- **单个重试** — 重新生成指定失败的
- **删除** — 删除参考图，保留实体记录
- **精调（指令式修改）** — 输入修改指令 → 加载当前图 → 编辑模型生成 → 更新（保留前版本可撤销）

**角色三视图提示词（原项目）：**
> "角色设定图，画面分为左右两个区域：【左侧区域】占约1/3宽度，正面特写；【右侧区域】占约2/3宽度，三视图横向排列（正面全身、侧面全身、背面全身），三视图高度一致。纯白色背景。"

**道具设定图提示词（原项目）：**
> "道具设定图，画面分为左右两个区域：【左侧区域】占约1/3宽度，道具主体主视图特写；【右侧区域】占约2/3宽度，三视图横向排列（正面、侧面、背面）。纯白色背景，无人物。"

#### B3.5 配音音色 — 实际集成到视频语音 + 可跳过
- 渲染 `VoicePicker` 组件（已存在未挂载）
- 为角色分配音色后，**音色 ID 写入 VoiceLine 记录**
- 生成视频时，voice_handler 使用分配的音色 ID 调用 TTS API
- **可选"后期配音"**：勾选后跳过此步骤，管线继续推进
- **字幕同步检查**：
  - VoiceLine 生成后，音频时长与字幕时间戳对齐
  - 检查字幕是否与面板视频时长匹配
  - 不匹配时自动调整或提示用户

#### B3.6 分镜 — 角色+场景+道具标签 + 一致性生图

**标签系统：**
- 每个面板下方显示出场实体标签：
  - 🔵 角色标签（蓝色）
  - 🟢 场景标签（绿色）
  - 🟠 道具标签（橙色）
- 标签数据来源：clip 分割时关联的 `characters[]`、`location`、`props[]`

**一致性生图（核心，参考原项目 `collectPanelReferenceImages` + `buildPanelPromptContext`）：**

原项目实现逻辑：
1. `collectPanelReferenceImages()`：
   - 收集面板草图（如有）
   - 遍历面板关联角色 → 查找角色外观 → 取选中索引的参考图 URL
   - 查找面板关联场景 → 取选中的场景图 URL
   - 返回：`string[]`（草图 + 角色图 + 场景图）
2. `buildPanelPromptContext()`：
   - 面板信息：shot_type, camera_move, description
   - 角色外观上下文：name, appearance, description
   - 场景参考上下文：name, description, available_slots
   - 合成为 JSON 对象
3. 调用图像生成：
   - **非 image-to-image，而是 text-to-image + referenceImages 参数**
   - prompt = 剧情描述 + 画风提示词
   - referenceImages = 收集到的角色/场景参考图 URL 数组
   - 模型利用参考图保持视觉一致性

**Elixir 移植优化：**
- 相同逻辑：收集参考图 → 构建 prompt context → text-to-image with references
- 增加道具参考图收集（原项目有道具提取但分镜生图时未明确使用道具图）
- 缓存参考图 URL，避免每次生图重新查询数据库

#### B3.7 阶段命名 "Film" → "成片"
#### B3.8 面板编辑弹窗翻译补全

---

## Phase C：高级功能

### C1. 首尾帧核心功能 (#6)

**原项目完整实现（深度研究结果）：**

1. **智能配对**：连续面板自动配对（同 storyboard + panelIndex 相邻）
2. **LLM 提示词重写**（`rewriteFlPromptWithLLM`）：
   - 输入：首帧描述、尾帧描述、首帧对白、尾帧对白、画风
   - LLM temperature: 0.3，输出 20-200 字过渡描述
   - 回退：同场景→"镜头自然过渡：{尾帧描述}"，跨场景→"场景转换至：{尾帧描述}"
3. **批量生成**：`Promise.all` 并行为所有面板对生成 FL prompt → 提交任务
4. **模型验证**：`capabilities.video.firstlastframe === true`（如 ARK Seedance 2.0）
5. **任务去重**：`dedupeKey: video_panel:${panel.id}`
6. **已生成跳过**：FL 模式包含所有有图面板（不像 normal 模式只取无视频的）

**Elixir 移植方案：**

| 原项目 | Elixir 版 | 优化 |
|--------|----------|------|
| `Promise.all` FL prompt | `Task.async_stream` + `ConcurrencyLimiter` | 控制并发数避免 API 限流 |
| 内存状态跟踪 | Task 表 checkpoint + PubSub | 断点恢复，失败单独重试 |
| 单次批量提交 | GenServer 任务队列 | 排队 + 优先级 + 超时管理 |
| 无场景连续性评分 | soft scoring 排序 | 优先生成"最需要过渡"的面板对 |

**新增文件：**
- `first_last_frame.ex` — LiveComponent
- `fl_prompt_rewriter.ex` — LLM 过渡提示词
- `video_handler.ex` — 添加 FL 模式
- 迁移：Panel 表新增 `first_last_frame_prompt`, `fl_video_url`, `video_generation_mode`

**验收标准：**
- 相邻面板间可生成过渡视频
- LLM 自动重写过渡描述 + 支持自定义
- 批量生成 + 单独重试 + 断点恢复
- 成片阶段全局开关 + FL 模型选择

### C2. 配音音色 + 字幕同步 (#6)
- MiniMax 2.8HD 300+ 系统音色浏览/筛选/试听
- VoicePicker 分页+搜索（性别/语言）
- 自定义音色上传
- **字幕与语音同步验证**

**新增文件：** `voice_presets.ex`

### C3. AI 剪辑面板优化 (#6)
- 布局：左 5/12 → 右 7/12
- 预览窗口 min-h-400px + 深色背景 + 视频控制条
- 缩略图放大

---

## 风险点与应对

| 风险 | 应对方案 |
|------|----------|
| 图像生成 API 需有效 Key | UI 框架先行，API 封装为可 mock 接口 |
| MiniMax 音乐/音色 API | 用户已订阅 MAX 极速版，使用 `music-2.6` 模型 |
| show.ex 1700+ 行膨胀 | 新功能全部提取为独立 LiveComponent |
| 首尾帧模型兼容性 | 验证 ARK Seedance 2.0 支持，备选模型列表 |
| 三阶段提取复杂 | 分步移植+测试：角色→场景→道具 |
| 精调/撤销功能 | 保留 previousImageUrl，支持一步撤销 |

---

### B4. 计费记录 + 统计面板（新增需求）

**目标：** 精确追踪每次 API 调用的成本，按维度统计

**文件清单：**
- `lib/astra_auto_ex/billing/api_call_log.ex` — **新建**：API 调用记录 Schema
- `lib/astra_auto_ex/billing/cost_tracker.ex` — **新建**：成本追踪模块
- `lib/astra_auto_ex/billing/statistics.ex` — **新建**：统计查询
- `lib/astra_auto_ex_web/live/profile_live/billing_stats.ex` — **新建**：统计面板组件
- `priv/repo/migrations/xxx_create_api_call_logs.exs` — **新建**

**API 调用日志表（`api_call_logs`）：**
```
id, user_id, project_id, project_name,
model_key (如 "ark:doubao-seedance-2-0"),
model_type (text/image/video/voice/music),
pipeline_step (story_to_script/extract_characters/generate_image/generate_video/...),
input_tokens, output_tokens,
status (success/failed/timeout),
cost_estimate (根据单价计算),
duration_ms,
inserted_at
```

**记录时机：** 在所有 handler（text/image/video/voice）的 API 调用前后自动记录

**统计面板（设置页 → 计费标签）：**
- **按模型统计**：每个模型的调用次数、成功率、总费用 — 饼图
- **按项目统计**：每个项目的总费用、各管线步骤占比 — 堆叠柱状图
- **按日期统计**：每日/每周/每月费用趋势 — 折线图
- **模型单价设置**：用户可配置每个模型的单次调用费用
- **费用公式**：`总费用 = Σ (调用次数 × 单价)` 或 `Σ (token数 × 单价/1K)`

**图表实现：** 使用 JS Hook + Chart.js 或纯 SVG 渲染

---

## 版本规划

| 版本 | 内容 |
|------|------|
| v0.6.1 | 翻译补全 + 导航栏 + 引导流程 |
| v0.6.2 | 首页（10比例/画风自定义向导/动画/项目管理页+完成度） |
| v0.6.3 | 素材库 5 类 CRUD（抽卡+图生图+精调）+ MiniMax 音乐 |
| v0.6.4 | 项目页（自动链控制器/AI写作集数/管线弹窗/3类提取+6操作/配音集成/分镜标签+一致性/改名） |
| v0.6.5 | 计费记录 + 统计面板（按模型/项目/日期 + 分布图 + 单价配置） |
| v0.7.0 | 首尾帧核心 + 音色300+ + 字幕同步 + AI剪辑优化 |
