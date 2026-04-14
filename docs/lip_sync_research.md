# 口型同步（Lip Sync）技术方案调研

## 什么是口型同步
口型同步是将音频语音与视频人物的嘴唇运动对齐的技术，使角色看起来像在说话。
在短剧视频生产中，口型同步解决的核心问题是：AI 生成的视频画面中角色的嘴部动作与 TTS 配音不匹配。

## 技术方案对比

### 方案 1: Wav2Lip（推荐入门）
- **原理**: 给定一段视频和一段音频，Wav2Lip 会修改视频中人物的嘴唇区域使其与音频同步
- **优点**: 开源免费、效果稳定、支持任意语言
- **缺点**: 需要 GPU、分辨率限制（最佳 480p-720p）、非嘴部区域不变
- **API**: RunningHub 等平台提供托管版
- **集成方式**: 视频生成后 → 配音生成后 → 调用 Wav2Lip API → 替换原视频

### 方案 2: SadTalker
- **原理**: 从单张图片 + 音频生成说话头部视频
- **优点**: 只需一张图就能生成说话视频、表情更自然
- **缺点**: 仅支持面部/头部、不适合全身动态场景
- **适用**: 数字人直播、新闻播报类短剧

### 方案 3: Video Retalking
- **原理**: 对已有视频进行嘴唇替换，比 Wav2Lip 更高质量
- **优点**: 高分辨率支持、边缘更自然
- **缺点**: 计算量更大、速度慢

### 方案 4: AI 视频模型原生支持
- **原理**: 新一代视频生成模型（如可灵2.0、Sora）在生成时直接接受音频输入
- **优点**: 一步到位、无后处理
- **缺点**: 模型能力尚在发展中，不是所有模型都支持
- **例如**: MiniMax 的视频模型未来可能支持 audio-driven video generation

## 推荐实施路径

### 短期（v0.8.0）
1. 在成片阶段添加"口型同步"开关
2. 集成 Wav2Lip API（通过 RunningHub 或 FAL）
3. 流程：视频 + 配音 → Wav2Lip → 替换视频 URL

### 中期
1. 探索 SadTalker 用于数字人直播场景
2. 评估 Video Retalking 的质量提升

### 长期
1. 跟进 AI 视频模型的原生音频驱动能力
2. 当模型支持时，直接在视频生成阶段传入音频

## 在 AstraAutoEx 中的集成点

```
管线流程:
故事 → 剧本 → 分镜 → 图像 → 视频 → 配音 → [口型同步] → 合成
                                              ↑ 新增步骤
```

### 需要修改的文件
- `lib/astra_auto_ex/workers/handlers/video_handler.ex` — 添加 lip_sync 后处理
- `lib/astra_auto_ex_web/live/workspace_live/show.ex` — 成片阶段添加开关
- `lib/astra_auto_ex/production/panel.ex` — 添加 `lip_synced_video_url` 字段
- 数据库迁移 — Panel 表新增字段

### API 调用示例（Wav2Lip via RunningHub）
```elixir
# 伪代码
def lip_sync(video_url, audio_url) do
  request = %{
    "video_url" => video_url,
    "audio_url" => audio_url,
    "model" => "wav2lip",
    "quality" => "high"
  }
  
  Helpers.generate_video(user_id, "runninghub", request)
end
```

## 字幕同步（已有基础）
字幕同步与口型同步不同：
- **字幕同步**: 文字出现时机与音频对齐 → 已通过 VoiceLine 时间戳实现
- **口型同步**: 嘴唇运动与音频对齐 → 需要额外 AI 处理
