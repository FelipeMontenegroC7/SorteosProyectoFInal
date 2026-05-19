defmodule ServidorCentral.Sorteo.Changesets do
  import Ecto.Changeset

  @sorteo_fields ~w(nombre fecha valor_billete fracciones cantidad_billetes descripcion_premio_completo descripcion_premio_fraccion)a
  @premio_fields ~w(nombre descripcion objeto valor orden)a
  @compra_fields ~w(jugador)a
  @compra_especifica_fields ~w(jugador billete fraccion)a
  @edicion_fields ~w(fecha valor_billete fracciones cantidad_billetes descripcion_premio_completo descripcion_premio_fraccion estado)a

  def crear_sorteo(params) do
    {%{}, %{
      nombre: :string,
      fecha: :string,
      valor_billete: :integer,
      fracciones: :integer,
      cantidad_billetes: :integer,
      descripcion_premio_completo: :string,
      descripcion_premio_fraccion: :string
    }}
    |> cast(params, @sorteo_fields)
    |> validate_required(~w(nombre fecha valor_billete fracciones cantidad_billetes)a)
    |> validate_length(:nombre, min: 2, max: 120)
    |> validate_number(:valor_billete, greater_than: 0)
    |> validate_number(:fracciones, greater_than: 0)
    |> validate_number(:cantidad_billetes, greater_than: 0)
  end

  def editar_sorteo(params) do
    {%{}, %{
      fecha: :string,
      valor_billete: :integer,
      fracciones: :integer,
      cantidad_billetes: :integer,
      descripcion_premio_completo: :string,
      descripcion_premio_fraccion: :string,
      estado: :string
    }}
    |> cast(params, @edicion_fields)
    |> validate_required(~w(fecha valor_billete fracciones cantidad_billetes)a)
    |> validate_number(:valor_billete, greater_than: 0)
    |> validate_number(:fracciones, greater_than: 0)
    |> validate_number(:cantidad_billetes, greater_than: 0)
  end

  def premio(params) do
    {%{}, %{nombre: :string, descripcion: :string, objeto: :string, valor: :integer, orden: :integer}}
    |> cast(params, @premio_fields)
    |> validate_required([:nombre, :valor])
    |> validate_length(:nombre, min: 1, max: 80)
    |> validate_number(:valor, greater_than: 0)
    |> validate_number(:orden, greater_than_or_equal_to: 1)
  end

  def compra_fraccion(params) do
    {%{}, %{jugador: :string}}
    |> cast(params, @compra_fields)
    |> validate_required([:jugador])
    |> validate_length(:jugador, min: 1, max: 80)
  end

  def compra_especifica(params) do
    {%{}, %{jugador: :string, billete: :integer, fraccion: :integer}}
    |> cast(params, @compra_especifica_fields)
    |> validate_required([:jugador, :billete, :fraccion])
    |> validate_number(:billete, greater_than: 0)
    |> validate_number(:fraccion, greater_than: 0)
  end
end
