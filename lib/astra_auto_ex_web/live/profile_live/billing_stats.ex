defmodule AstraAutoExWeb.ProfileLive.BillingStats do
  @moduledoc "Billing statistics panel: summary row + heatmap + detail tabs."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.Billing.Statistics

  @impl true
  def update(assigns, socket) do
    user_id = assigns.user_id
    stats_by_model = Statistics.by_model(user_id)
    stats_by_project = Statistics.by_project(user_id)
    stats_by_date = Statistics.by_date(user_id, 30)
    recent = Statistics.recent_calls(user_id, 20)
    summary = assigns.billing_summary

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:stats_by_model, stats_by_model)
     |> assign(:stats_by_project, stats_by_project)
     |> assign(:stats_by_date, stats_by_date)
     |> assign(:recent, recent)
     |> assign(:summary, summary)
     |> assign(:active_tab, "model")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <%!-- Compact summary row --%>
      <div class="glass-surface px-5 py-3 flex items-center justify-between">
        <div class="flex items-center gap-6">
          <div class="flex items-center gap-2">
            <span class="text-xs text-[var(--glass-text-tertiary)]">总调用</span>
            <span class="text-lg font-bold text-[var(--glass-text-primary)]">
              {@summary.total_calls}
            </span>
          </div>
          <div class="w-px h-5 bg-[var(--glass-stroke-soft)]" />
          <div class="flex items-center gap-2">
            <span class="text-xs text-[var(--glass-text-tertiary)]">总费用</span>
            <span class="text-lg font-bold text-[var(--glass-accent-from)]">
              ¥{Decimal.round(@summary.total_cost, 2)}
            </span>
          </div>
          <div class="w-px h-5 bg-[var(--glass-stroke-soft)]" />
          <div class="flex items-center gap-2">
            <span class="text-xs text-[var(--glass-text-tertiary)]">模型数</span>
            <span class="text-lg font-bold text-[var(--glass-text-primary)]">
              {length(@stats_by_model)}
            </span>
          </div>
        </div>
        <span class={"text-xs px-2 py-0.5 rounded-full font-medium " <>
          if(@summary.total_calls > 0, do: "bg-green-500/15 text-green-400", else: "bg-[var(--glass-bg-muted)] text-[var(--glass-text-tertiary)]")}>
          {if @summary.total_calls > 0, do: "活跃", else: "待使用"}
        </span>
      </div>
      <%!-- Heatmap (30-day activity) --%>
      <div class="glass-surface px-5 py-3">
        <div class="flex items-center justify-between mb-2">
          <span class="text-xs font-medium text-[var(--glass-text-secondary)]">30天调用热力图</span>
          <div class="flex items-center gap-1 text-[10px] text-[var(--glass-text-tertiary)]">
            <span>少</span>
            <span class="w-2.5 h-2.5 rounded-sm bg-[var(--glass-bg-muted)]" />
            <span class="w-2.5 h-2.5 rounded-sm bg-[var(--glass-accent-from)] opacity-30" />
            <span class="w-2.5 h-2.5 rounded-sm bg-[var(--glass-accent-from)] opacity-60" />
            <span class="w-2.5 h-2.5 rounded-sm bg-[var(--glass-accent-from)]" />
            <span>多</span>
          </div>
        </div>
        <div class="flex gap-0.5 flex-wrap">
          <%= for day <- heatmap_days(@stats_by_date) do %>
            <div
              class="w-3.5 h-3.5 rounded-sm transition-colors"
              style={"background: #{heatmap_color(day.calls, @stats_by_date)}"}
              title={"#{day.label}: #{day.calls} 次调用"}
            />
          <% end %>
        </div>
      </div>
      <%!-- Tab switch --%>
      <div class="flex gap-2 px-1">
        <%= for {tab, label} <- [{"model", "按模型"}, {"project", "按项目"}, {"recent", "最近调用"}] do %>
          <button
            type="button"
            phx-click="switch_billing_tab"
            phx-value-tab={tab}
            phx-target={@myself}
            class={"text-xs px-3 py-1.5 rounded-lg transition-all cursor-pointer " <>
              if(@active_tab == tab, do: "bg-[var(--glass-accent-from)]/15 text-[var(--glass-accent-from)] font-medium", else: "text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]")}
          >
            {label}
          </button>
        <% end %>
      </div>
      <%!-- Tab content --%>
      <%= case @active_tab do %>
        <% "model" -> %>
          <div class="space-y-1.5">
            <%= for stat <- @stats_by_model do %>
              <div class="glass-surface px-4 py-2.5 flex items-center justify-between">
                <div>
                  <span class="text-sm font-medium text-[var(--glass-text-primary)]">
                    {stat.model_key}
                  </span>
                  <span class="text-[10px] text-[var(--glass-text-tertiary)] ml-2">
                    {stat.model_type} · {stat.total_calls}次 · 成功率{success_rate(stat)}%
                  </span>
                </div>
                <span class="text-sm font-medium text-[var(--glass-accent-from)]">
                  ¥{format_cost(stat.total_cost)}
                </span>
              </div>
            <% end %>
            <%= if @stats_by_model == [] do %>
              <div class="text-center py-6 text-xs text-[var(--glass-text-tertiary)]">
                调用 AI 生成功能后，使用记录将自动出现在此处
              </div>
            <% end %>
          </div>
        <% "project" -> %>
          <div class="space-y-1.5">
            <%= for stat <- @stats_by_project do %>
              <div class="glass-surface px-4 py-2.5 flex items-center justify-between">
                <div>
                  <span class="text-sm font-medium text-[var(--glass-text-primary)]">
                    {stat.project_name || "项目 ##{stat.project_id}"}
                  </span>
                  <span class="text-[10px] text-[var(--glass-text-tertiary)] ml-2">
                    {stat.total_calls}次调用
                  </span>
                </div>
                <span class="text-sm font-medium text-[var(--glass-accent-from)]">
                  ¥{format_cost(stat.total_cost)}
                </span>
              </div>
            <% end %>
            <%= if @stats_by_project == [] do %>
              <div class="text-center py-6 text-xs text-[var(--glass-text-tertiary)]">暂无项目记录</div>
            <% end %>
          </div>
        <% "recent" -> %>
          <div class="space-y-0.5 max-h-[400px] overflow-y-auto">
            <%= for call <- @recent do %>
              <div class="flex items-center gap-2 text-xs py-1.5 px-3 rounded-lg hover:bg-[var(--glass-bg-muted)] transition-colors">
                <span class={"w-1.5 h-1.5 rounded-full flex-shrink-0 " <> if(call.status == "success", do: "bg-green-500", else: "bg-red-500")} />
                <span class="w-28 truncate text-[var(--glass-text-secondary)]">{call.model_key}</span>
                <span class="w-16 text-[var(--glass-text-tertiary)]">{call.pipeline_step}</span>
                <span class="w-14 text-[var(--glass-text-tertiary)]">{call.duration_ms}ms</span>
                <span class="flex-1 text-right text-[var(--glass-text-tertiary)]">
                  {Calendar.strftime(call.inserted_at, "%m-%d %H:%M")}
                </span>
              </div>
            <% end %>
            <%= if @recent == [] do %>
              <div class="text-center py-6 text-xs text-[var(--glass-text-tertiary)]">暂无记录</div>
            <% end %>
          </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("switch_billing_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # ── Heatmap helpers ──

  defp heatmap_days(stats_by_date) do
    today = Date.utc_today()
    date_map = Map.new(stats_by_date, fn s -> {s.date, s.total_calls} end)

    for offset <- 29..0//-1 do
      date = Date.add(today, -offset)
      calls = Map.get(date_map, date, 0)
      %{date: date, calls: calls, label: Calendar.strftime(date, "%m-%d")}
    end
  end

  defp heatmap_color(0, _stats), do: "var(--glass-bg-muted)"

  defp heatmap_color(calls, stats) do
    max_calls = stats |> Enum.map(& &1.total_calls) |> Enum.max(fn -> 1 end)
    ratio = calls / max(max_calls, 1)

    cond do
      ratio > 0.7 -> "var(--glass-accent-from)"
      ratio > 0.4 -> "color-mix(in srgb, var(--glass-accent-from) 60%, transparent)"
      true -> "color-mix(in srgb, var(--glass-accent-from) 30%, transparent)"
    end
  end

  defp success_rate(%{total_calls: 0}), do: 0

  defp success_rate(%{total_calls: total, success_count: success}),
    do: round(success / total * 100)

  defp format_cost(nil), do: "0.00"
  defp format_cost(cost), do: Decimal.round(cost, 2) |> Decimal.to_string()
end
