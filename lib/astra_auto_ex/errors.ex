defmodule AstraAutoEx.Errors do
  @moduledoc "Unified error code system with bilingual messages (EN/ZH), covering 22 precise error types."

  @type error_code :: atom()
  @type error_info :: %{code: error_code(), message: String.t(), message_zh: String.t()}

  @errors %{
    unauthorized: %{
      code: :unauthorized,
      message: "Authentication required",
      message_zh: "需要登录"
    },
    forbidden: %{code: :forbidden, message: "Permission denied", message_zh: "没有权限"},
    not_found: %{code: :not_found, message: "Resource not found", message_zh: "资源未找到"},
    insufficient_balance: %{
      code: :insufficient_balance,
      message: "Insufficient balance",
      message_zh: "余额不足"
    },
    rate_limit: %{
      code: :rate_limit,
      message: "Rate limit exceeded",
      message_zh: "请求过于频繁"
    },
    model_not_open: %{
      code: :model_not_open,
      message: "Model not configured",
      message_zh: "模型未开通"
    },
    model_not_registered: %{
      code: :model_not_registered,
      message: "Model not registered",
      message_zh: "模型未注册"
    },
    quota_exceeded: %{
      code: :quota_exceeded,
      message: "API quota exceeded",
      message_zh: "API配额已用完"
    },
    generation_failed: %{
      code: :generation_failed,
      message: "Generation failed",
      message_zh: "生成失败"
    },
    generation_timeout: %{
      code: :generation_timeout,
      message: "Generation timed out",
      message_zh: "生成超时"
    },
    sensitive_content: %{
      code: :sensitive_content,
      message: "Sensitive content detected",
      message_zh: "检测到敏感内容"
    },
    invalid_params: %{
      code: :invalid_params,
      message: "Invalid parameters",
      message_zh: "参数无效"
    },
    network_error: %{
      code: :network_error,
      message: "Network error",
      message_zh: "网络错误"
    },
    empty_response: %{
      code: :empty_response,
      message: "Empty response from AI",
      message_zh: "AI返回空结果"
    },
    external_error: %{
      code: :external_error,
      message: "External service error",
      message_zh: "外部服务错误"
    },
    task_not_ready: %{
      code: :task_not_ready,
      message: "Task prerequisites not met",
      message_zh: "任务前置条件未满足"
    },
    watchdog_timeout: %{
      code: :watchdog_timeout,
      message: "Task watchdog timeout",
      message_zh: "任务看门狗超时"
    },
    worker_execution_error: %{
      code: :worker_execution_error,
      message: "Worker execution error",
      message_zh: "执行器错误"
    },
    video_format_unsupported: %{
      code: :video_format_unsupported,
      message: "Video format not supported",
      message_zh: "视频格式不支持"
    },
    fl_model_unsupported: %{
      code: :fl_model_unsupported,
      message: "Model does not support first-last frame",
      message_zh: "模型不支持首尾帧"
    },
    video_capability_unsupported: %{
      code: :video_capability_unsupported,
      message: "Video capability combination not supported",
      message_zh: "视频能力组合不支持"
    },
    json_parse_error: %{
      code: :json_parse_error,
      message: "Failed to parse AI response as JSON",
      message_zh: "AI响应JSON解析失败"
    }
  }

  @doc "Get full error info by code. Returns nil if not found."
  @spec get(error_code()) :: error_info() | nil
  def get(code), do: Map.get(@errors, code)

  @doc "Get localized error message. Defaults to English for unknown locales."
  @spec message(error_code(), locale :: String.t()) :: String.t()
  def message(code, "zh"), do: (Map.get(@errors, code) || %{})[:message_zh] || "未知错误"
  def message(code, _locale), do: (Map.get(@errors, code) || %{})[:message] || "Unknown error"

  @doc "List all registered error codes."
  @spec all_codes() :: [error_code()]
  def all_codes, do: Map.keys(@errors)
end
