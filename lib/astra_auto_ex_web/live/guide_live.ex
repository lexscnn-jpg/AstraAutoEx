defmodule AstraAutoExWeb.GuideLive do
  use AstraAutoExWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, dgettext("default", "User Guide"))
     |> assign(:active_step, 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="glass-page min-h-screen">
      <div class="max-w-4xl mx-auto px-6 py-12">
        <div class="text-center mb-12">
          <h1 class="text-3xl font-bold text-[var(--glass-text-primary)] mb-3">5 分钟出片指南</h1>
          
          <p class="text-[var(--glass-text-secondary)]">从灵感到成片，只需 5 个步骤</p>
        </div>
        
        <div class="space-y-6">
          <%= for step <- steps() do %>
            <div
              class={"glass-card p-6 cursor-pointer transition-all " <>
                if(step.number == @active_step, do: "ring-2 ring-[var(--glass-accent-from)]", else: "opacity-80 hover:opacity-100")}
              phx-click="select_step"
              phx-value-step={step.number}
            >
              <div class="flex items-start gap-4">
                <div class={"flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center text-lg font-bold " <>
                  if(step.number == @active_step,
                    do: "bg-gradient-to-br from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white",
                    else: "bg-[var(--glass-bg-muted)] text-[var(--glass-text-tertiary)]")}>
                  {step.number}
                </div>
                
                <div class="flex-1">
                  <h3 class="text-lg font-semibold text-[var(--glass-text-primary)] mb-1">
                    {step.title}
                  </h3>
                  
                  <p class="text-sm text-[var(--glass-text-secondary)] mb-3">{step.description}</p>
                  
                  <%= if step.number == @active_step do %>
                    <div class="mt-3 space-y-2">
                      <%= for tip <- step.tips do %>
                        <div class="flex items-start gap-2 text-sm text-[var(--glass-text-secondary)]">
                          <span class="text-[var(--glass-accent-from)] mt-0.5">
                            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                              <path
                                fill-rule="evenodd"
                                d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                                clip-rule="evenodd"
                              />
                            </svg>
                          </span> <span>{tip}</span>
                        </div>
                      <% end %>
                    </div>
                    
                    <%= if step.time do %>
                      <div class="mt-3 text-xs text-[var(--glass-text-tertiary)]">
                        预计用时：{step.time}
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
        
        <div class="mt-12 glass-card p-6">
          <h3 class="text-lg font-semibold text-[var(--glass-text-primary)] mb-3">快捷操作</h3>
          
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div class="text-center p-4 rounded-lg bg-[var(--glass-bg-muted)]">
              <div class="text-2xl mb-2">🔗</div>
              
              <div class="text-sm font-medium text-[var(--glass-text-primary)]">自动链模式</div>
              
              <div class="text-xs text-[var(--glass-text-tertiary)] mt-1">每步完成后自动执行下一步</div>
            </div>
            
            <div class="text-center p-4 rounded-lg bg-[var(--glass-bg-muted)]">
              <div class="text-2xl mb-2">🚀</div>
              
              <div class="text-sm font-medium text-[var(--glass-text-primary)]">全自动模式</div>
              
              <div class="text-xs text-[var(--glass-text-tertiary)] mt-1">一键从故事到成片</div>
            </div>
            
            <div class="text-center p-4 rounded-lg bg-[var(--glass-bg-muted)]">
              <div class="text-2xl mb-2">✍️</div>
              
              <div class="text-sm font-medium text-[var(--glass-text-primary)]">AI 帮我写</div>
              
              <div class="text-xs text-[var(--glass-text-tertiary)] mt-1">输入灵感，AI 生成完整大纲</div>
            </div>
          </div>
        </div>
        
        <div class="mt-8 text-center">
          <a
            href={~p"/home"}
            class="glass-btn glass-btn-primary px-8 py-3 text-base"
          >
            开始创作
          </a>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_step", %{"step" => step}, socket) do
    {:noreply, assign(socket, :active_step, String.to_integer(step))}
  end

  defp steps do
    [
      %{
        number: 1,
        title: "第一步：故事输入",
        description: "输入你的故事创意，或使用 AI 帮你写",
        time: "约 30 秒",
        tips: [
          "直接粘贴故事文本、小说片段或剧本大纲",
          "也可拖入 .txt / .md 文件自动导入",
          "点击「AI 帮我写」输入灵感，AI 自动生成故事大纲",
          "选择画面比例（16:9 横屏 / 9:16 竖屏短剧）和画风"
        ]
      },
      %{
        number: 2,
        title: "第二步：剧本拆解",
        description: "AI 自动分析故事，提取角色、场景、道具",
        time: "约 1 分钟",
        tips: [
          "点击「生成剧本」，AI 将故事拆分为剧集片段",
          "自动提取角色、场景和道具列表",
          "为每个角色生成参考图（三视图），保持一致性",
          "为角色配置语音音色（可选跳过，后期配音）"
        ]
      },
      %{
        number: 3,
        title: "第三步：分镜绘制",
        description: "根据剧本自动生成分镜图，支持精调",
        time: "约 1-2 分钟",
        tips: [
          "点击「生成所有图片」批量生成分镜图",
          "每个分镜自动关联出场角色和场景，确保一致性",
          "点击单个分镜可编辑：修改描述、重新生成、精调",
          "支持抽卡模式：生成多张候选，择优选择"
        ]
      },
      %{
        number: 4,
        title: "第四步：成片制作",
        description: "生成视频、配音和首尾帧过渡",
        time: "约 2-3 分钟",
        tips: [
          "点击「生成所有视频」将分镜图转为动态视频",
          "开启首尾帧功能，自动生成相邻面板间的过渡视频",
          "点击「生成所有配音」为每个台词生成语音",
          "检查字幕与画面是否同步"
        ]
      },
      %{
        number: 5,
        title: "第五步：AI 剪辑合成",
        description: "选择面板、设置转场，一键合成最终视频",
        time: "约 1 分钟",
        tips: [
          "勾选要包含的面板（默认全选）",
          "设置转场效果（交叉淡入淡出 / 黑场过渡 / 无）",
          "选择字幕模式（烧录 / 外挂 / 双轨）",
          "点击「合成视频」，等待最终成片输出"
        ]
      }
    ]
  end
end
