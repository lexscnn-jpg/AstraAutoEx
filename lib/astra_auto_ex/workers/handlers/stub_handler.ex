defmodule AstraAutoEx.Workers.Handlers.StubHandler do
  @moduledoc "Base stub for handlers not yet implemented."

  defmacro __using__(_opts) do
    quote do
      def execute(task) do
        {:error, "handler_not_yet_implemented: #{task.type}"}
      end

      defoverridable execute: 1
    end
  end
end
