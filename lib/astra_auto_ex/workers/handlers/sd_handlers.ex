defmodule AstraAutoEx.Workers.Handlers.SDHandlerBase do
  @moduledoc "Shared base for Short Drama workflow handlers."

  defmacro __using__(opts) do
    step_name = Keyword.fetch!(opts, :step)
    instruction = Keyword.fetch!(opts, :instruction)

    quote do
      alias AstraAutoEx.Workers.Handlers.Helpers
      alias AstraAutoEx.ShortDrama

      def execute(task) do
        payload = task.payload || %{}
        input_text = payload["input_text"] || payload["content"] || ""

        if String.trim(input_text) == "" do
          {:error, "No input text for #{unquote(step_name)}"}
        else
          Helpers.update_progress(task, 10)

          model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
          provider = model_config["provider"]

          prompt = unquote(instruction) <> "\n\n" <> String.slice(input_text, 0..8000)

          request = %{
            model: model_config["model"],
            contents: [%{"parts" => [%{"text" => prompt}]}]
          }

          Helpers.update_progress(task, 40)

          case Helpers.chat(task.user_id, provider, request) do
            {:ok, text} ->
              Helpers.update_progress(task, 90)
              {:ok, %{step: unquote(step_name), result: text}}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.SDTopicSelection do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "topic_selection",
    instruction: """
    作为短剧策划专家，分析以下内容并进行选题立项分析：
    1. 目标受众画像
    2. 题材类型（甜宠/逆袭/悬疑/穿越/都市等）
    3. 核心卖点和爆款潜力
    4. 竞品分析
    5. 建议集数和每集时长
    返回JSON: {"audience": "", "genre": "", "selling_points": [], "episodes": 0, "duration_per_episode": 0}
    """
end

defmodule AstraAutoEx.Workers.Handlers.SDStoryOutline do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "story_outline",
    instruction: """
    根据选题，创建完整的故事大纲：
    1. 核心冲突和主题
    2. 三幕结构（开端/发展/高潮/结局）
    3. 主要情节转折点
    4. 每集钩子和反转设计
    5. 付费卡点设置
    返回JSON: {"theme": "", "structure": {...}, "plot_points": [], "hooks": [], "paywall_points": []}
    """
end

defmodule AstraAutoEx.Workers.Handlers.SDCharacterDev do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "character_dev",
    instruction: """
    进行角色开发：
    1. 主角人物小传（背景/性格/动机/成长弧线）
    2. 配角设定
    3. 角色关系图
    4. 每个角色的视觉描述（供AI绘图）
    返回JSON: {"protagonists": [...], "supporting": [...], "relationships": [...]}
    """
end

defmodule AstraAutoEx.Workers.Handlers.SDEpisodeDirectory do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "episode_directory",
    instruction: """
    创建分集目录：
    每集包含：标题、时长、核心事件、钩子、反转、情绪曲线
    返回JSON数组: [{"episode": 1, "title": "", "duration": "", "events": [], "hook": "", "twist": "", "emotion_curve": ""}]
    """
end

defmodule AstraAutoEx.Workers.Handlers.SDEpisodeScript do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "episode_script",
    instruction: """
    根据分集大纲撰写完整单集剧本：
    包含：场景描述、镜头指示、对白、动作描写、转场
    格式要求：专业分镜剧本格式
    """
end

defmodule AstraAutoEx.Workers.Handlers.SDQualityReview do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "quality_review",
    instruction: """
    对剧本进行质量自检：
    1. 逻辑一致性检查
    2. 角色行为合理性
    3. 节奏和张力评估
    4. 对白自然度
    5. 爽点/钩子密度
    返回JSON: {"score": 0-100, "issues": [...], "suggestions": [...]}
    """
end

defmodule AstraAutoEx.Workers.Handlers.SDComplianceCheck do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "compliance_check",
    instruction: """
    进行合规审核：
    1. 广电总局内容规范检查
    2. 敏感词/话题排查
    3. 价值观导向审核
    4. 暴力/色情内容检测
    返回JSON: {"passed": true/false, "violations": [...], "suggestions": [...]}
    """
end

defmodule AstraAutoEx.Workers.Handlers.SDOverseasAdapt do
  use AstraAutoEx.Workers.Handlers.SDHandlerBase,
    step: "overseas_adapt",
    instruction: """
    进行出海适配：
    1. 文化差异调整建议
    2. 翻译注意事项
    3. 目标市场本地化（ReelShort/DramaBox等平台）
    4. 付费模式适配
    返回JSON: {"adaptations": [...], "translation_notes": [...], "platform_notes": {...}}
    """
end
