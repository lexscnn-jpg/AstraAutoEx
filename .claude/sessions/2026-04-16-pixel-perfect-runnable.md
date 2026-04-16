# 2026-04-16 — 像素级重构使之能用 (v0.9.1)

## 用户原始需求
> 像素级重构项目，使之能用

明确选择：同步推进 UI 对齐 + 端到端可用 / autonomous / 允许真实 MiniMax API 调用。

## 执行总览

进入会话时 v0.9.0 文档声称代码 92% 完整，36 handler 注册，224 tests 0 fail。但实际 **没人确认过它能跑**。本次工作核心：把"代码完成"变成"程序能跑且 5 阶段都不崩"。

## 关键发现与修复

### 环境层（P0 之前的 P-1）

1. **Erlang 被 Windows Device Guard 拦截**
   - 现象：`C:\ProgramData\chocolatey\bin\erl.exe` 被策略阻止
   - 误判：Program Files 下 Erlang 看似 OTP 16，实际是 OTP 28（erts-16.3.1 是内部版本号）
   - 解：`start.bat` 把 `C:\Program Files\Erlang OTP\bin` 提到 PATH 最前面，绕过 Chocolatey shim

2. **preview_start 找不到 mix**
   - 解：新增 `.claude/phx-wrapper.bat` 设置 PATH 后调 mix；`.claude/launch.json` 改走 wrapper

### LiveView 层（P0 阻塞）

3. **剧本阶段切换无效**（最大 bug）
   - 现象：点"剧本"按钮但页面不变；点 storyboard/film 都 OK，唯独 script 失败
   - 表面结论错了：以为 LiveView 没收到 phx-click，怀疑过 dgettext 翻译缺失、phx-disable 等
   - 真实根因：服务端 log 显示 `KeyError :title not found in Clip` —— `clip.title` 字段根本不存在（应该用 `summary` 或自动编号）
   - 二次崩溃：修完 clip.title 后又 `KeyError :image_url not found in Location` —— 同问题，has_many 关联未理解
   - 三次崩溃：character 也是 `image_url`/`description` 字段不存在
   - 解：
     - 新增 `character_thumb/1` 和 `location_thumb/1` 两个 helper，从 `has_many` 关联安全取首图
     - `char.description` 改用 `char.introduction`
     - `clip.title` 改用 `dgettext("projects", "Clip #%{n}", n: idx + 1)`

4. **panel 卡片漏渲染道具标签**
   - 现象：`parse_panel_props/1` 函数定义了但未引用（编译警告）
   - 实质：道具标签从未在 UI 出现（角色/场景都有）
   - 解：在 `sb_panel_card/1` 中接通 + 模板加 emerald 色 tag 渲染

5. **music_generate_handler 类型不匹配（4 处警告）**
   - 错误地用 `Minimax.poll_task/2`（返回视频/文件结构）来轮询音乐
   - 实际 MiniMax 音乐 API 是同步的（返回 `%{audio: binary, status: :completed}`）
   - 解：删除整个 `poll_until_done/5` 函数 + 简化 execute 只走同步路径

### 性能与体验层（P1）

6. **TaskScheduler 每秒轮询**淹没日志
   - 解：`@poll_interval` 1秒 → 5秒；`@watchdog_interval` 30秒 → 60秒
   - dev.exs 加 `config :logger, level: :info` 抑制 SQL :debug 噪声

7. **LiveView 热重载偶尔失效**（`:econnaborted`）
   - 现象：源码改完后 hot reload 报 stack trace 显示老行号
   - 解：未根治，但用 preview_stop + preview_start 强制重启就 OK；记录到已知问题

## 验证结果（截图证据）

| 页面 | 结果 |
|---|---|
| 首页（未登录）| ✅ "星辰自动漫剧 / AI影视Studio" 标题 + 中文 nav + 4 项目卡 |
| 登录 | ✅ admin (5078534@qq.com) 登录成功 |
| 工作区 - 故事 | ✅ 故事文本框、比例选择、画风、自动链开关 |
| 工作区 - 剧本（修复前崩溃）| ✅ 5 个片段卡 + 角色（0）+ 场景（6） |
| 工作区 - 分镜 | ✅ 384 片段 / 124 镜头 + 3 列网格 |
| 工作区 - 成片 | ✅ 124 个面板真实生成的电影质感图（数据已存在） |
| 工作区 - AI 剪辑 | ✅ 视频素材 0/124 + 选择列表 |
| 设置 | ✅ 9 厂商（API易/MiniMax 已连接）+ 4 Tab |
| 模型配置 | ✅ 7 步骤 × 3 类型（llm/image/video）下拉 |
| 素材库 | ✅ 范围切换 + 7 资产类型 Tab + 1 角色卡 |
| 使用手册 | ✅ "5 分钟出片指南" + 5 步骤详细说明 |

## 数据点

- 当前 PG 数据：12 个项目，2 个用户，多个剧集
- 项目 12 已实跑过完整管线：124 个面板都生成了图像
- 这意味着**重构指南声称的核心管线在过去某次跑通过**，只是后续 schema/字段重构破坏了 LiveView 渲染

## 用户给我的反馈（隐性）

- 通过同步推进 UI + 功能 + autonomous 模式，确认用户不希望被反复确认细节
- 接受真实 API 调用，意味着用户对 v0.9.x 的"看起来漂亮"满意，下一步聚焦"真能产出"

## 下次会话起点

1. **真实 API 端到端**：开新项目 → 输入故事 → 跑 story_to_script → 检查 clips 是否真的有 `summary`/`location` 字段
2. **像素级 UI 残差对齐**：
   - 首页 Hero 打字机效果（`TypewriterHero` 组件）
   - AI 写作模态框 4 阶段（输入/加载/预览/错误）
   - 分镜卡片 hover 操作条（目前 always-visible）
3. **短剧 8 任务系统**：CLAUDE.md 列了但未实测
4. **Production 数据修复**：项目 12 的 `clip.characters` 是 nil（剧本阶段右侧"角色 (0)"），可能是 split_clips 没填字段

## 技术决策记录

- 选择 helper 函数（`character_thumb/1`）而不是 schema virtual field，因为 has_many 关联 preload 控制权在 context，virtual field 容易触发 NotLoaded 错误
- 删除 music_generate 的 poll 路径而不是保留为 dead code，因为 type checker 给出明确反馈说 MiniMax 音乐 API 就是同步的
- 把 `start.bat` 修改为绕过 Chocolatey shim 而不是请求用户禁用 Device Guard，因为：(a) 用户安全策略不应被代码改动，(b) 真实路径就在 Program Files 已是干净方案
