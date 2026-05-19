defmodule ClienteJugadorWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use ClienteJugadorWeb, :html

  import ClienteJugadorWeb.Layouts, only: [app: 1]

  embed_templates "page_html/*"

  def formatear_fecha(fecha_str) when is_binary(fecha_str) do
    case Regex.run(~r/^(\d{4})-(\d{2})-(\d{2})/, fecha_str) do
      [_, year, month, day] ->
        meses = %{
          "01" => "Enero", "02" => "Febrero", "03" => "Marzo", "04" => "Abril",
          "05" => "Mayo", "06" => "Junio", "07" => "Julio", "08" => "Agosto",
          "09" => "Septiembre", "10" => "Octubre", "11" => "Noviembre", "12" => "Diciembre"
        }
        "#{day} #{meses[month]} #{year}"
      _ -> fecha_str
    end
  end
  def formatear_fecha(fecha), do: to_string(fecha)
end
