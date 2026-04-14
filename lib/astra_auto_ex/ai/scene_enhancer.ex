defmodule AstraAutoEx.AI.SceneEnhancer do
  @moduledoc """
  Maps scene_type to camera style descriptors and parses [TAG:...] markers
  in panel descriptions to generate enhanced visual prompts.
  """

  @scene_styles %{
    "daily" => %{
      shots: "中景/近景",
      angles: "平视, 过肩交替",
      moves: "慢推拉跟",
      mood: "自然日常",
      tips: "对话场景用正反打，生活化细节特写穿插"
    },
    "emotion" => %{
      shots: "近景/特写",
      angles: "平视",
      moves: "慢推/环绕, 交叉记忆与现实",
      mood: "情感共鸣",
      tips: "浅景深虚化背景，面部微表情捕捉，光影渲染情绪"
    },
    "action" => %{
      shots: "快速切换景别",
      angles: "仰角/俯角/荷兰角",
      moves: "急推, 手持跟拍, 速度变化",
      mood: "紧张刺激",
      tips: "速度变化+手持跟踪+快切，冲击力画面"
    },
    "epic" => %{
      shots: "极远景建立",
      angles: "俯角/吊臂",
      moves: "叙事无人机 (高空→跟拍→近景)",
      mood: "宏大壮阔",
      tips: "大景别展示环境规模，缓慢推进建立氛围"
    },
    "suspense" => %{
      shots: "POV主观视角",
      angles: "荷兰角",
      moves: "慢推压迫, 突然切换",
      mood: "悬疑压迫",
      tips: "低调光+轮廓光+反射，慢推制造压迫感"
    }
  }

  @tag_enhancements %{
    "ACTION" => "速度变化 + 手持跟踪 + 快切，画面充满冲击力和动态张力",
    "MONTAGE" => "交叉剪辑 + 冷暖色调对比，时间跳跃蒙太奇",
    "AERIAL" => "叙事无人机运镜：高空建立→跟拍移动→近景细节",
    "BULLET-TIME" => "时间冻结 + 360°环绕 + 悬浮碎片，子弹时间效果",
    "ATMOSPHERE" => "低调光 + 轮廓光 + 反射面，氛围渲染优先"
  }

  @doc "Enhance a video prompt based on scene_type and description tags."
  def enhance_video_prompt(video_prompt, scene_type, description \\ nil) do
    style = Map.get(@scene_styles, scene_type, @scene_styles["daily"])
    tags = if description, do: extract_tags(description), else: []

    parts = [video_prompt]

    parts =
      parts ++
        ["[镜头风格] #{style.shots}, #{style.moves}, #{style.angles}"]

    parts =
      Enum.reduce(tags, parts, fn {tag, content}, acc ->
        enhancement = Map.get(@tag_enhancements, tag, "")

        if enhancement != "" do
          acc ++ ["[#{tag}] #{content}: #{enhancement}"]
        else
          acc
        end
      end)

    Enum.join(parts, "\n")
  end

  @doc "Enhance an image prompt with scene-appropriate photography direction."
  def enhance_image_prompt(image_prompt, scene_type) do
    style = Map.get(@scene_styles, scene_type, @scene_styles["daily"])
    "#{image_prompt}\n[摄影指导] #{style.mood}, #{style.shots}, #{style.tips}"
  end

  @doc "Extract [TAG:content] markers from text."
  def extract_tags(text) when is_binary(text) do
    Regex.scan(~r/\[([A-Z_-]+):([^\]]+)\]/, text)
    |> Enum.map(fn [_full, tag, content] -> {tag, String.trim(content)} end)
  end

  def extract_tags(_), do: []

  @doc "Get scene style info for a given scene_type."
  def get_style(scene_type), do: Map.get(@scene_styles, scene_type)

  @doc "List all available scene types."
  def scene_types, do: Map.keys(@scene_styles)
end
