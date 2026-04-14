defmodule AstraAutoExWeb.ProfileLive.BillingStats do
  @moduledoc "Billing statistics panel: by model, project, date."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.Billing.Statistics

  @impl true
  def update(assigns, socket) do
    user_id = assigns.user_id
    stats_by_model = Statistics.by_model(user_id)
    stats_by_project = Statistics.by_project(user_id)
    stats_by_date = Statistics.by_date(user_id, 30)
    recent = Statistics.recent_calls(user_id, 20)

    total_cost =
      stats_by_model
      |> Enum.map(& &1.total_cost)
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    total_calls = Enum.reduce(stats_by_model, 0, fn s, acc -> acc + s.total_calls end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:stats_by_model, stats_by_model)
     |> assign(:stats_by_project, stats_by_project)
     |> assign(:stats_by_date, stats_by_date)
     |> assign(:recent, recent)
     |> assign(:total_cost, total_cost)
     |> assign(:total_calls, total_calls)
     |> assign(:active_tab, "model")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Summary cards --%>
      <div class="grid grid-cols-3 gap-4">
        <div class="glass-card p-4 text-center">
          <div class="text-2xl font-bold text-[var(--glass-text-primary)]">{@total_calls}</div>

          <div class="text-xs text-[var(--glass-text-tertiary)]">总调用次数</div>
        </div>

        <div class="glass-card p-4 text-center">
          <div class="text-2xl font-bold text-[var(--glass-accent-from)]">
            ¥{Decimal.round(@total_cost, 2)}
          </div>

          <div class="text-xs text-[var(--glass-text-tertiary)]">预估总费用</div>
        </div>

        <div class="glass-card p-4 text-center">
          <div class="text-2xl font-bold text-[var(--glass-text-primary)]">
            {length(@stats_by_model)}
          </div>

          <div class="text-xs text-[var(--glass-text-tertiary)]">使用模型数</div>
        </div>
      </div>
      <%!-- Tab switch --%>
      <div class="flex gap-2 border-b border-[var(--glass-stroke-base)] pb-1">
        <%= for {tab, label} <- [{"model", "按模型"}, {"project", "按项目"}, {"date", "按日期"}, {"recent", "最近调用"}] do %>
          <button
            type="button"
            phx-click="switch_billing_tab"
            phx-value-tab={tab}
            phx-target={@myself}
            class={"text-sm px-3 py-1.5 rounded-t-lg transition-all " <>
              if(@active_tab == tab, do: "text-[var(--glass-accent-from)] border-b-2 border-[var(--glass-accent-from)] font-medium", else: "text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]")}
          >
            {label}
          </button>
        <% end %>
      </div>
      <%!-- Tab content --%>
      <%= case @active_tab do %>
        <% "model" -> %>
          <div class="space-y-2">
            <%= for stat <- @stats_by_model do %>
              <div class="glass-card p-3 flex items-center justify-between">
                <div>
                  <div class="text-sm font-medium text-[var(--glass-text-primary)]">
                    {stat.model_key}
                  </div>

                  <div class="text-xs text-[var(--glass-text-tertiary)]">
                    {stat.model_type} · {stat.total_calls} 次调用 · 成功率 {success_rate(stat)}%
                  </div>
                </div>

                <div class="text-sm font-medium text-[var(--glass-accent-from)]">
                  ¥{format_cost(stat.total_cost)}
                </div>
              </div>
            <% end %>

            <%= if @stats_by_model == [] do %>
              <div class="text-center py-8 text-[var(--glass-text-tertiary)]">暂无调用记录</div>
            <% end %>
          </div>
        <% "project" -> %>
          <div class="space-y-2">
            <%= for stat <- @stats_by_project do %>
              <div class="glass-card p-3 flex items-center justify-between">
                <div>
                  <div class="text-sm font-medium text-[var(--glass-text-primary)]">
                    {stat.project_name || "项目 ##{stat.project_id}"}
                  </div>

                  <div class="text-xs text-[var(--glass-text-tertiary)]">{stat.total_calls} 次调用</div>
                </div>

                <div class="text-sm font-medium text-[var(--glass-accent-from)]">
                  ¥{format_cost(stat.total_cost)}
                </div>
              </div>
            <% end %>

            <%= if @stats_by_project == [] do %>
              <div class="text-center py-8 text-[var(--glass-text-tertiary)]">暂无项目记录</div>
            <% end %>
          </div>
        <% "date" -> %>
          <div class="space-y-1">
            <%= for stat <- @stats_by_date do %>
              <div class="flex items-center gap-3 text-sm">
                <span class="w-24 text-[var(--glass-text-tertiary)]">{stat.date}</span>
                <div class="flex-1 h-4 bg-[var(--glass-bg-muted)] rounded overflow-hidden">
                  <div
                    class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] rounded"
                    style={"width: #{bar_width(stat.total_calls, @stats_by_date)}%"}
                  />
                </div>

                <span class="w-12 text-right text-[var(--glass-text-secondary)]">
                  {stat.total_calls}
                </span>
                <span class="w-16 text-right text-[var(--glass-accent-from)]">
                  ¥{format_cost(stat.total_cost)}
                </span>
              </div>
            <% end %>

            <%= if @stats_by_date == [] do %>
              <div class="text-center py-8 text-[var(--glass-text-tertiary)]">暂无日期记录</div>
            <% end %>
          </div>
        <% "recent" -> %>
          <div class="space-y-1 max-h-[400px] overflow-y-auto">
            <%= for call <- @recent do %>
              <div class="flex items-center gap-2 text-xs py-1.5 border-b border-[var(--glass-stroke-soft)]">
                <span class={"w-2 h-2 rounded-full flex-shrink-0 " <> if(call.status == "success", do: "bg-green-500", else: "bg-red-500")} />
                <span class="w-32 truncate text-[var(--glass-text-secondary)]">{call.model_key}</span>
                <span class="w-20 text-[var(--glass-text-tertiary)]">{call.pipeline_step}</span>
                <span class="w-16 text-[var(--glass-text-tertiary)]">{call.duration_ms}ms</span>
                <span class="flex-1 text-right text-[var(--glass-text-tertiary)]">
                  {Calendar.strftime(call.inserted_at, "%m-%d %H:%M")}
                </span>
              </div>
            <% end %>

            <%= if @recent == [] do %>
              <div class="text-center py-8 text-[var(--glass-text-tertiary)]">暂无记录</div>
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

  defp success_rate(%{total_calls: 0}), do: 0

  defp success_rate(%{total_calls: total, success_count: success}),
    do: round(success / total * 100)

  defp format_cost(nil), do: "0.00"
  defp format_cost(cost), do: Decimal.round(cost, 2) |> Decimal.to_string()

  defp bar_width(_calls, []), do: 0

  defp bar_width(calls, stats) do
    max_calls = stats |> Enum.map(& &1.total_calls) |> Enum.max(fn -> 1 end)
    if max_calls == 0, do: 0, else: round(calls / max_calls * 100)
  end
end
