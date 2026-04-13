defmodule AstraAutoExWeb.Plugs.LocalePlug do
  @moduledoc """
  Detects and sets the locale from cookie or Accept-Language header.
  """
  import Plug.Conn

  @cookie_key "locale"
  @supported_locales ~w(en zh)
  @default_locale "en"

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      conn
      |> get_locale_from_params()
      |> or_try(fn -> get_locale_from_cookie(conn) end)
      |> or_try(fn -> get_locale_from_header(conn) end)
      |> validate_locale()

    Gettext.put_locale(AstraAutoExWeb.Gettext, locale)

    conn
    |> put_session("locale", locale)
    |> put_resp_cookie(@cookie_key, locale, max_age: 365 * 24 * 60 * 60)
  end

  defp get_locale_from_params(conn) do
    conn.params["locale"]
  end

  defp get_locale_from_cookie(conn) do
    conn.cookies[@cookie_key]
  end

  defp get_locale_from_header(conn) do
    case get_req_header(conn, "accept-language") do
      [value | _] -> parse_accept_language(value)
      _ -> nil
    end
  end

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(fn part ->
      part
      |> String.trim()
      |> String.split(";")
      |> List.first()
      |> String.split("-")
      |> List.first()
    end)
    |> Enum.find(&(&1 in @supported_locales))
  end

  defp or_try(nil, func), do: func.()
  defp or_try(value, _func), do: value

  defp validate_locale(locale) when locale in @supported_locales, do: locale
  defp validate_locale(_), do: @default_locale
end
