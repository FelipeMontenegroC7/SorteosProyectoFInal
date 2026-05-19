defmodule ServidorCentral.Seeds do
  @moduledoc """
  Datos iniciales para el sistema: admin, jugadores de prueba, sorteos de ejemplo.
  Se ejecuta al arranque si no existen registros.
  """
  alias ServidorCentral.{Admins, Usuarios, GestorSorteos, Sorteo}

  def run do
    # Crear admin por defecto si no existe
    if Admins.listar() == [] do
      {:ok, _} = Admins.registrar_admin("admin", "admin123")
      IO.puts("[Seeds] Admin creado: admin / admin123")
    end

    # Crear jugadores de prueba si no existen
    if Usuarios.listar() == [] do
      {:ok, _} = Usuarios.registrar_usuario("juandiaz", "jugador123", "Juan", "Díaz", "1098345678")
      Usuarios.recargar_creditos("juandiaz", 500)
      IO.puts("[Seeds] Jugador creado: juandiaz / jugador123 con $500")

      {:ok, _} = Usuarios.registrar_usuario("maria_lopez", "jugador123", "María", "López", "1099012345")
      Usuarios.recargar_creditos("maria_lopez", 1000)
      IO.puts("[Seeds] Jugador creado: maria_lopez / jugador123 con $1000")

      {:ok, _} = Usuarios.registrar_usuario("carlos_ruiz", "jugador123", "Carlos", "Ruiz", "1098234500")
      Usuarios.recargar_creditos("carlos_ruiz", 1000)
      IO.puts("[Seeds] Jugador creado: carlos_ruiz / jugador123 con $1000")
    end

    # Crear sorteos de ejemplo si no existen
    if GestorSorteos.listar_sorteos() == [] do
      ahora = DateTime.utc_now()

      # --- Sorteo 1: Lotería Nacional (futura, +2 días) ---
      crear_sorteo_seed(%{
        nombre: "Loteria-Nacional",
        fecha: DateTime.add(ahora, 86400 * 2, :second) |> DateTime.to_iso8601(),
        valor_billete: 10000,
        fracciones: 5,
        cantidad_billetes: 20,
        premios: [
          %{nombre: "Premio Mayor", descripcion: "Gana el premio mayor de $50.000.", objeto: "Viaje", valor: 50000, orden: 1},
          %{nombre: "Segundo Premio", descripcion: "Gana $20.000 por fracción ganadora.", objeto: "", valor: 20000, orden: 2},
          %{nombre: "Tercer Premio", descripcion: "Gana $10.000 como tercer lugar.", objeto: "", valor: 10000, orden: 3}
        ],
        desc_completo: "Si posee todas las fracciones del billete ganador, recibe el 100% del premio mayor.",
        desc_fraccion: "Si posee una fracción del billete ganador, recibe la parte proporcional."
      })

      # --- Sorteo 2: Lotería Manizales (futura, +5 días) ---
      crear_sorteo_seed(%{
        nombre: "Loteria-Manizales",
        fecha: DateTime.add(ahora, 86400 * 5, :second) |> DateTime.to_iso8601(),
        valor_billete: 5000,
        fracciones: 3,
        cantidad_billetes: 15,
        premios: [
          %{nombre: "Gran Premio", descripcion: "Premio principal de $30.000.", valor: 30000, orden: 1},
          %{nombre: "Segundo Premio", descripcion: "Gana $10.000.", valor: 10000, orden: 2}
        ],
        desc_completo: "El billete completo recibe la totalidad del premio.",
        desc_fraccion: "Cada fracción ganadora recibe un tercio del premio."
      })

      # --- Sorteo 3: Lotería del Quindío (futura, +1 día) ---
      crear_sorteo_seed(%{
        nombre: "Loteria-del-Quindio",
        fecha: DateTime.add(ahora, 86400, :second) |> DateTime.to_iso8601(),
        valor_billete: 20000,
        fracciones: 10,
        cantidad_billetes: 30,
        premios: [
          %{nombre: "Mega Premio", descripcion: "El premio más grande: $100.000.", valor: 100000, orden: 1},
          %{nombre: "Segundo Premio", descripcion: "Gana $50.000.", valor: 50000, orden: 2},
          %{nombre: "Tercer Premio", descripcion: "Gana $25.000.", valor: 25000, orden: 3},
          %{nombre: "Cuarto Premio", descripcion: "Gana $10.000.", valor: 10000, orden: 4}
        ],
        desc_completo: "Billete completo: 100% del premio correspondiente.",
        desc_fraccion: "Cada fracción vale 1/10 del premio."
      })

      # --- Sorteo 4: Lotería Express (futura, +12 horas) ---
      crear_sorteo_seed(%{
        nombre: "Loteria-Express",
        fecha: DateTime.add(ahora, 43200, :second) |> DateTime.to_iso8601(),
        valor_billete: 3000,
        fracciones: 2,
        cantidad_billetes: 8,
        premios: [
          %{nombre: "Premio Único", descripcion: "El único ganador se lleva $20.000.", valor: 20000, orden: 1}
        ],
        desc_completo: "Billete completo = premio completo.",
        desc_fraccion: "Cada mitad vale $10.000."
      })

      # --- Sorteo 5: Lotería Boyacá (pasada, -3 días) - con ventas y ejecución ---
      crear_sorteo_pasado(%{
        nombre: "Loteria-Boyaca",
        fecha: DateTime.add(ahora, -86400 * 3, :second) |> DateTime.to_iso8601(),
        valor_billete: 8000,
        fracciones: 4,
        cantidad_billetes: 10,
        premios: [
          %{nombre: "Premio Mayor", descripcion: "Premio de $40.000.", valor: 40000, orden: 1},
          %{nombre: "Segundo Premio", descripcion: "Premio de $15.000.", valor: 15000, orden: 2}
        ],
        desc_completo: "Billete completo recibe el premio total.",
        desc_fraccion: "Cada fracción recibe 1/4 del premio.",
        compras: [
          {"juandiaz", 1, 1}, {"juandiaz", 1, 2},
          {"maria_lopez", 2, 1}, {"maria_lopez", 2, 2}, {"maria_lopez", 2, 3}, {"maria_lopez", 2, 4},
          {"carlos_ruiz", 3, 1}, {"carlos_ruiz", 3, 2}
        ]
      })

      # --- Sorteo 6: Lotería Santander (pasada, -1 día) - con ventas y ejecución ---
      crear_sorteo_pasado(%{
        nombre: "Loteria-Santander",
        fecha: DateTime.add(ahora, -86400, :second) |> DateTime.to_iso8601(),
        valor_billete: 15000,
        fracciones: 6,
        cantidad_billetes: 25,
        premios: [
          %{nombre: "Gran Premio", descripcion: "El gran premio de $60.000.", valor: 60000, orden: 1},
          %{nombre: "Segundo Premio", descripcion: "Gana $30.000.", valor: 30000, orden: 2},
          %{nombre: "Tercer Premio", descripcion: "Gana $15.000.", valor: 15000, orden: 3}
        ],
        desc_completo: "Billete completo = premio completo.",
        desc_fraccion: "Cada fracción vale 1/6 del premio.",
        compras: [
          {"juandiaz", 5, 1}, {"juandiaz", 5, 2}, {"juandiaz", 5, 3},
          {"maria_lopez", 10, 1}, {"maria_lopez", 10, 2},
          {"carlos_ruiz", 15, 1}, {"carlos_ruiz", 15, 2}, {"carlos_ruiz", 15, 3}, {"carlos_ruiz", 15, 4}
        ]
      })

      IO.puts("[Seeds] 6 sorteos de ejemplo creados")
    end
  end

  defp crear_sorteo_seed(attrs) do
    sorteo = %Sorteo{
      nombre: attrs.nombre,
      fecha: attrs.fecha,
      valor_billete: attrs.valor_billete,
      fracciones: attrs.fracciones,
      cantidad_billetes: attrs.cantidad_billetes,
      estado: :activo,
      premios: Enum.map(attrs.premios, fn p -> Map.put(p, :id, Ecto.UUID.generate()) end),
      ventas: [],
      numero_ganador: nil,
      inserted_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      billetes_generados: [],
      descripcion_premio_completo: Map.get(attrs, :desc_completo, ""),
      descripcion_premio_fraccion: Map.get(attrs, :desc_fraccion, "")
    }

    case GestorSorteos.crear_nuevo_sorteo(sorteo) do
      {:ok, _pid} -> IO.puts("[Seeds] Sorteo creado: #{attrs.nombre}")
      {:error, _} -> :ok
    end
  end

  defp crear_sorteo_pasado(attrs) do
    # Primero crear el sorteo como activo
    crear_sorteo_seed(Map.drop(attrs, [:compras]))

    # Dar créditos temporales para las compras
    for {jugador, _b, _f} <- attrs.compras do
      precio = div(attrs.valor_billete, max(attrs.fracciones, 1))
      Usuarios.recargar_creditos(jugador, precio)
    end

    # Realizar las compras
    for {jugador, billete, fraccion} <- attrs.compras do
      case GestorSorteos.comprar_fraccion_especifica(attrs.nombre, jugador, billete, fraccion) do
        {:ok, _} -> :ok
        {:error, razon} -> IO.puts("[Seeds] Error comprando #{attrs.nombre} B#{billete}F#{fraccion}: #{razon}")
      end
    end

    # Ejecutar el sorteo
    case GestorSorteos.ejecutar_sorteo(attrs.nombre) do
      {:ok, _} -> IO.puts("[Seeds] Sorteo ejecutado: #{attrs.nombre}")
      {:error, razon} -> IO.puts("[Seeds] Error ejecutando #{attrs.nombre}: #{razon}")
    end
  end
end
