defmodule ClienteAdminWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use ClienteAdminWeb, :html

  import ClienteAdminWeb.Layouts, only: [app: 1]

  embed_templates "page_html/*"

  def formatear_fecha_hora(fecha_str) when is_binary(fecha_str) do
    case Regex.run(~r/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}:\d{2})/, fecha_str) do
      [_, year, month, day, time] ->
        meses = %{
          "01" => "Ene", "02" => "Feb", "03" => "Mar", "04" => "Abr",
          "05" => "May", "06" => "Jun", "07" => "Jul", "08" => "Ago",
          "09" => "Sep", "10" => "Oct", "11" => "Nov", "12" => "Dic"
        }
        {"#{day} #{meses[month]} #{year}", time}
      _ -> {fecha_str, ""}
    end
  end
  def formatear_fecha_hora(fecha), do: {to_string(fecha), ""}
end
