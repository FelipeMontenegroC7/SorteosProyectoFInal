defmodule ServidorCentral.SorteoServer do
  @moduledoc """
  GenServer por sorteo: estado en memoria, persistencia y bitácora en cada mutación.
  Estados válidos: :pendiente → :activo → :finalizado (flujo unidireccional).
  """
  use GenServer

  alias ServidorCentral.{Bitacora, Persistencia, Sorteo, Usuarios}

  def start_link(%Sorteo{} = inicial) do
    GenServer.start_link(__MODULE__, inicial, name: via(inicial.nombre))
  end

  def via(nombre), do: {:global, {:sorteo, nombre}}

  def obtener_estado(nombre), do: call_or_error(nombre, :obtener_estado)

  def actualizar_sorteo(nombre, attrs), do: call_or_error(nombre, {:actualizar, attrs})

  def agregar_premio(nombre, premio_map), do: call_or_error(nombre, {:agregar_premio, premio_map})

  def eliminar_premio(nombre, premio_id), do: call_or_error(nombre, {:eliminar_premio, premio_id})

  def editar_premio(nombre, premio_id, nuevos_datos), do: call_or_error(nombre, {:editar_premio, premio_id, nuevos_datos})

  def comprar_fraccion(nombre, jugador), do: call_or_error(nombre, {:comprar, jugador})

  def comprar_fraccion_especifica(nombre, jugador, billete, fraccion),
    do: call_or_error(nombre, {:comprar_especifica, jugador, billete, fraccion})

  def comprar_billete_completo(nombre, jugador, billete),
    do: call_or_error(nombre, {:comprar_completo, jugador, billete})

  def devolver_compra(nombre, venta_id), do: call_or_error(nombre, {:devolver, venta_id})

  def ejecutar_sorteo(nombre), do: call_or_error(nombre, :ejecutar_sorteo)

  def listar_billetes_disponibles(nombre), do: call_or_error(nombre, :listar_disponibles)

  def eliminar_sorteo(nombre) do
    case GenServer.whereis(via(nombre)) do
      nil -> {:error, :no_encontrado}
      pid ->
        GenServer.call(pid, :eliminar_sorteo)
    end
  end

  defp call_or_error(nombre, msg) do
    case GenServer.whereis(via(nombre)) do
      nil -> {:error, :no_encontrado}
      pid -> GenServer.call(pid, msg)
    end
  end

  @impl true
  def init(%Sorteo{} = datos) do
    estado =
      case Persistencia.cargar_sorteo(datos.nombre) do
        {:ok, map} ->
          Bitacora.registrar("inicio_sorteo", :ok, %{sorteo_id: datos.nombre})
          Sorteo.from_map(map)

        {:error, _} ->
          inicial = %{datos | inserted_at: datos.inserted_at || DateTime.utc_now() |> DateTime.to_iso8601()}
          _ = persistir(inicial)
          Bitacora.registrar("inicio_sorteo", :ok, %{sorteo_id: datos.nombre})
          inicial
      end

    {:ok, estado}
  end

  @impl true
  def handle_call(:obtener_estado, _from, estado), do: {:reply, estado, estado}

  def handle_call(:listar_disponibles, _from, estado) do
    disponibles = calcular_disponibles(estado)
    {:reply, {:ok, disponibles}, estado}
  end

  def handle_call(:eliminar_sorteo, _from, estado) do
    if length(estado.ventas) > 0 do
      {:reply, {:error, :tiene_ventas}, estado}
    else
      Bitacora.registrar("eliminar_sorteo", :ok, %{sorteo_id: estado.nombre})
      {:reply, {:ok, estado.nombre}, estado}
    end
  end

  # === ACTUALIZAR ===
  # Permite actualizar si está :pendiente o :activo.
  # No permite volver a :pendiente si ya hay ventas.
  def handle_call({:actualizar, attrs}, _from, estado) do
    reply_and_persist(estado, fn e ->
      case e.estado do
        :finalizado ->
          {{:error, :cerrado}, e}

        estado_actual when estado_actual in [:pendiente, :activo] ->
          nuevo_estado_str = Map.get(attrs, :estado)
          nuevo_estado = if nuevo_estado_str, do: normalizar_estado_atom(nuevo_estado_str), else: e.estado

          # Validar: no se puede volver a pendiente si hay ventas
          if nuevo_estado == :pendiente and e.estado == :activo and length(e.ventas) > 0 do
            {{:error, :tiene_ventas}, e}
          else
            e =
              e
              |> Map.put(:fecha, Map.get(attrs, :fecha, e.fecha))
              |> Map.put(:valor_billete, Map.get(attrs, :valor_billete, e.valor_billete))
              |> Map.put(:fracciones, Map.get(attrs, :fracciones, e.fracciones))
              |> Map.put(:descripcion_premio_completo, Map.get(attrs, :descripcion_premio_completo, e.descripcion_premio_completo))
              |> Map.put(:descripcion_premio_fraccion, Map.get(attrs, :descripcion_premio_fraccion, e.descripcion_premio_fraccion))
              |> Map.put(:estado, nuevo_estado)

            nueva_cantidad = Map.get(attrs, :cantidad_billetes, e.cantidad_billetes)
            billetes_actuales = length(e.billetes_generados)

            nuevos_billetes =
              if nueva_cantidad > billetes_actuales do
                for b <- (billetes_actuales + 1)..nueva_cantidad do
                  %{
                    billete: b,
                    numero: :rand.uniform(10000) - 1 |> Integer.to_string() |> String.pad_leading(4, "0")
                  }
                end
              else
                []
              end

            e = Map.put(e, :cantidad_billetes, nueva_cantidad)
            e = Map.put(e, :billetes_generados, e.billetes_generados ++ nuevos_billetes)

            Bitacora.registrar("actualizar_sorteo", :ok, %{sorteo_id: e.nombre, cambios: Map.keys(attrs)})
            {{:ok, e}, e}
          end
      end
    end)
  end

  # === AGREGAR PREMIO ===
  # Funciona en :pendiente y :activo
  def handle_call({:agregar_premio, premio}, _from, estado) do
    reply_and_persist(estado, fn e ->
      if e.estado == :finalizado do
        {{:error, :cerrado}, e}
      else
        premios = e.premios ++ [premio]
        e = %{e | premios: premios |> Enum.sort_by(& &1.orden)}
        Bitacora.registrar("agregar_premio", :ok, %{sorteo_id: e.nombre, premio: premio.nombre, valor: premio.valor})
        {{:ok, e}, e}
      end
    end)
  end

  # === ELIMINAR PREMIO ===
  # Funciona en :pendiente y :activo
  def handle_call({:eliminar_premio, premio_id}, _from, estado) do
    reply_and_persist(estado, fn e ->
      if e.estado == :finalizado do
        {{:error, :cerrado}, e}
      else
        nuevos_premios = Enum.reject(e.premios, &(&1.id == premio_id))
        if length(nuevos_premios) == length(e.premios) do
          {{:error, :no_encontrado}, e}
        else
          e = %{e | premios: nuevos_premios}
          Bitacora.registrar("eliminar_premio", :ok, %{sorteo_id: e.nombre, premio_id: premio_id})
          {{:ok, e}, e}
        end
      end
    end)
  end

  # === EDITAR PREMIO ===
  # Funciona en :pendiente y :activo
  def handle_call({:editar_premio, premio_id, nuevos_datos}, _from, estado) do
    reply_and_persist(estado, fn e ->
      if e.estado == :finalizado do
        {{:error, :cerrado}, e}
      else
        premio_index = Enum.find_index(e.premios, &(&1.id == premio_id))
        if is_nil(premio_index) do
          {{:error, :no_encontrado}, e}
        else
          premio_actual = Enum.at(e.premios, premio_index)
          
          premio_actualizado = Map.merge(premio_actual, %{
            nombre: Map.get(nuevos_datos, :nombre, premio_actual.nombre),
            objeto: Map.get(nuevos_datos, :objeto, premio_actual.objeto),
            descripcion: Map.get(nuevos_datos, :descripcion, premio_actual.descripcion),
            valor: Map.get(nuevos_datos, :valor, premio_actual.valor)
          })

          nuevos_premios = List.replace_at(e.premios, premio_index, premio_actualizado)
          e = %{e | premios: nuevos_premios}
          Bitacora.registrar("editar_premio", :ok, %{sorteo_id: e.nombre, premio_id: premio_id})
          {{:ok, e}, e}
        end
      end
    end)
  end

  # === COMPRA ALEATORIA ===
  # Solo permite comprar si estado es :activo
  def handle_call({:comprar, jugador}, _from, estado) do
    reply_and_persist(estado, fn e ->
      cond do
        e.estado != :activo ->
          {{:error, :cerrado}, e}

        true ->
          with {:ok, {b, f}} <- cupo_libre(e),
               :ok <- debitar_creditos(jugador, div(e.valor_billete, max(e.fracciones, 1))) do
            venta = %{
              id: Ecto.UUID.generate(),
              jugador: jugador,
              billete: b,
              fraccion: f,
              inserted_at: DateTime.utc_now() |> DateTime.to_iso8601()
            }

            e = %{e | ventas: [venta | e.ventas]}
            Bitacora.registrar("compra", :ok, %{sorteo_id: e.nombre, jugador: jugador, billete: b, fraccion: f, precio: div(e.valor_billete, max(e.fracciones, 1))})
            {{:ok, venta}, e}
          else
            {:error, razon} ->
              Bitacora.registrar("compra", :negado, %{sorteo_id: e.nombre, jugador: jugador, razon: razon})
              {{:error, razon}, e}
          end
      end
    end)
  end

  # === COMPRA ESPECÍFICA ===
  def handle_call({:comprar_especifica, jugador, billete, fraccion}, _from, estado) do
    reply_and_persist(estado, fn e ->
      cond do
        e.estado != :activo ->
          {{:error, :cerrado}, e}

        billete < 1 or billete > e.cantidad_billetes ->
          Bitacora.registrar("compra_especifica", :negado, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, razon: :billete_invalido})
          {{:error, :billete_invalido}, e}

        fraccion < 1 or fraccion > e.fracciones ->
          Bitacora.registrar("compra_especifica", :negado, %{sorteo_id: e.nombre, jugador: jugador, fraccion: fraccion, razon: :fraccion_invalida})
          {{:error, :fraccion_invalida}, e}

        fraccion_ocupada?(e, billete, fraccion) ->
          Bitacora.registrar("compra_especifica", :negado, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, fraccion: fraccion, razon: :fraccion_ocupada})
          {{:error, :fraccion_ocupada}, e}

        true ->
          precio = div(e.valor_billete, max(e.fracciones, 1))
          case debitar_creditos(jugador, precio) do
            :ok ->
              venta = %{
                id: Ecto.UUID.generate(),
                jugador: jugador,
                billete: billete,
                fraccion: fraccion,
                inserted_at: DateTime.utc_now() |> DateTime.to_iso8601()
              }
              e = %{e | ventas: [venta | e.ventas]}
              Bitacora.registrar("compra_especifica", :ok, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, fraccion: fraccion, precio: precio})
              {{:ok, venta}, e}

            {:error, razon} ->
              Bitacora.registrar("compra_especifica", :negado, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, fraccion: fraccion, razon: razon})
              {{:error, razon}, e}
          end
      end
    end)
  end

  # === COMPRA COMPLETA ===
  def handle_call({:comprar_completo, jugador, billete}, _from, estado) do
    reply_and_persist(estado, fn e ->
      cond do
        e.estado != :activo ->
          {{:error, :cerrado}, e}

        billete < 1 or billete > e.cantidad_billetes ->
          Bitacora.registrar("compra_completo", :negado, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, razon: :billete_invalido})
          {{:error, :billete_invalido}, e}

        true ->
          ocupadas = e.ventas
            |> Enum.filter(&(&1.billete == billete))
            |> Enum.map(& &1.fraccion)
            |> MapSet.new()

          libres = for f <- 1..e.fracciones, not MapSet.member?(ocupadas, f), do: f

          cond do
            libres == [] ->
              Bitacora.registrar("compra_completo", :negado, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, razon: :billete_agotado})
              {{:error, :billete_agotado}, e}

            true ->
              precio_total = div(e.valor_billete, max(e.fracciones, 1)) * length(libres)
              case debitar_creditos(jugador, precio_total) do
                :ok ->
                  nuevas_ventas = Enum.map(libres, fn f ->
                    %{
                      id: Ecto.UUID.generate(),
                      jugador: jugador,
                      billete: billete,
                      fraccion: f,
                      inserted_at: DateTime.utc_now() |> DateTime.to_iso8601()
                    }
                  end)

                  e = %{e | ventas: nuevas_ventas ++ e.ventas}
                  Bitacora.registrar("compra_completo", :ok, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, fracciones: length(libres), precio: precio_total})
                  {{:ok, nuevas_ventas}, e}

                {:error, razon} ->
                  Bitacora.registrar("compra_completo", :negado, %{sorteo_id: e.nombre, jugador: jugador, billete: billete, razon: razon})
                  {{:error, razon}, e}
              end
          end
      end
    end)
  end

  # === DEVOLVER ===
  def handle_call({:devolver, venta_id}, _from, estado) do
    reply_and_persist(estado, fn e ->
      if e.estado != :activo do
        Bitacora.registrar("devolucion", :negado, %{sorteo_id: e.nombre, razon: :cerrado})
        {{:error, :cerrado}, e}
      else
        case Enum.find_index(e.ventas, &(&1.id == venta_id)) do
          nil ->
            Bitacora.registrar("devolucion", :negado, %{sorteo_id: e.nombre, venta_id: venta_id, razon: :no_encontrado})
            {{:error, :no_encontrado}, e}

          idx ->
            {venta, resto} = List.pop_at(e.ventas, idx)
            %{jugador: jugador} = venta

            precio = div(e.valor_billete, max(e.fracciones, 1))
            case Usuarios.recargar_creditos(jugador, precio) do
              :ok ->
                e = %{e | ventas: resto}
                Bitacora.registrar("devolucion", :ok, %{sorteo_id: e.nombre, jugador: jugador, venta_id: venta_id, monto: precio})
                {{:ok, venta}, e}

              {:error, _} ->
                Bitacora.registrar("devolucion", :negado, %{sorteo_id: e.nombre, jugador: jugador, venta_id: venta_id, razon: :no_pudo_devolver})
                {{:error, :no_pudo_devolver}, e}
            end
        end
      end
    end)
  end

  # === EJECUTAR SORTEO ===
  # Solo se ejecuta si estado es :activo
  def handle_call(:ejecutar_sorteo, _from, estado) do
    reply_and_persist(estado, fn e ->
      cond do
        e.estado != :activo ->
          {{:error, :ya_finalizado}, e}

        e.premios == [] ->
          {{:error, :sin_premios}, e}

        e.ventas == [] ->
          Bitacora.registrar("ejecutar_sorteo", :negado, %{sorteo_id: e.nombre, razon: :sin_ventas})
          {{:error, :sin_ventas}, e}

        true ->
          {numero_4digitos, premios} = asignar_ganadores(e)
          e = %{e | estado: :finalizado, numero_ganador: numero_4digitos, premios: premios}
          Bitacora.registrar("ejecutar_sorteo", :ok, %{sorteo_id: e.nombre, numero_ganador: numero_4digitos})
          {{:ok, e}, e}
      end
    end)
  end

  defp reply_and_persist(estado, fun) do
    {reply, nuevo} = fun.(estado)

    nuevo =
      case reply do
        {:ok, _} -> persistir(nuevo)
        _ -> nuevo
      end

    {:reply, reply, nuevo}
  end

  defp debitar_creditos(jugador, monto) do
    case Usuarios.debitar(jugador, monto) do
      :ok -> :ok
      {:error, _} -> {:error, :sin_fondos}
    end
  end

  defp persistir(%Sorteo{} = e) do
    datos = Sorteo.to_serializable(e)
    _ = Persistencia.guardar_sorteo(e.nombre, datos)
    e
  end

  defp fraccion_ocupada?(%Sorteo{} = e, billete, fraccion) do
    Enum.any?(e.ventas, &(&1.billete == billete and &1.fraccion == fraccion))
  end

  defp cupo_libre(%Sorteo{} = e) do
    ocupados =
      e.ventas
      |> Enum.map(&{&1.billete, &1.fraccion})
      |> MapSet.new()

    cupos =
      for b <- 1..e.cantidad_billetes,
          f <- 1..e.fracciones,
          not MapSet.member?(ocupados, {b, f}),
          do: {b, f}

    case cupos do
      [] -> {:error, :agotado}
      xs -> {:ok, Enum.random(xs)}
    end
  end

  defp calcular_disponibles(%Sorteo{} = e) do
    ocupados =
      e.ventas
      |> Enum.map(&{&1.billete, &1.fraccion})
      |> MapSet.new()

    for b <- 1..e.cantidad_billetes do
      fracciones_libres =
        for f <- 1..e.fracciones,
            not MapSet.member?(ocupados, {b, f}),
            do: f

      billete_info = Enum.find(e.billetes_generados, &(&1.billete == b || &1[:billete] == b))
      numero = if billete_info, do: billete_info.numero || billete_info[:numero], else: "????"

      %{
        billete: b,
        numero: numero,
        fracciones_libres: fracciones_libres,
        total_fracciones: e.fracciones,
        completo_disponible: length(fracciones_libres) == e.fracciones
      }
    end
    |> Enum.filter(&(&1.fracciones_libres != []))
  end

  defp asignar_ganadores(%Sorteo{} = e) do
    # Usar TODOS los billetes generados, no solo los vendidos
    todos_los_billetes =
      e.billetes_generados
      |> Enum.map(& &1.billete)

    if todos_los_billetes == [] do
      {"????", e.premios}
    else
      {premios_asignados, _restantes} =
        e.premios
        |> Enum.sort_by(& &1.orden)
        |> Enum.map_reduce(todos_los_billetes, fn p, disponibles ->
          if disponibles == [] do
            # Si hay más premios que billetes, los premios extra quedan vacantes
            {Map.merge(p, %{ganador_billete: nil, ganador_numero: "????", ganadores: []}), disponibles}
          else
            billete_ganador = Enum.random(disponibles)
            nuevos_disponibles = List.delete(disponibles, billete_ganador)
            
            billete_info = Enum.find(e.billetes_generados, &(&1.billete == billete_ganador || &1[:billete] == billete_ganador))
            numero_4digitos = if billete_info, do: billete_info.numero || billete_info[:numero], else: "????"

            # Buscar si alguien compró fracciones de este billete
            ventas_ganadoras = Enum.filter(e.ventas, &(&1.billete == billete_ganador))

            premio_por_fraccion = div(p.valor, max(e.fracciones, 1))

            ganadores =
              Enum.map(ventas_ganadoras, fn v ->
                Usuarios.recargar_creditos(v.jugador, premio_por_fraccion)
                %{
                  jugador: v.jugador,
                  fraccion: v.fraccion,
                  premio_ganado: premio_por_fraccion
                }
              end)

            premio_asignado = Map.merge(p, %{
              ganador_billete: billete_ganador, 
              ganador_numero: numero_4digitos,
              ganadores: ganadores,
              ganador_fraccion: "Varias",
              jugador: "Varios"
            })
            
            {premio_asignado, nuevos_disponibles}
          end
        end)

      premio_mayor = Enum.max_by(premios_asignados, &(&1.valor), fn -> hd(premios_asignados) end)

      {premio_mayor.ganador_numero, premios_asignados}
    end
  end

  defp normalizar_estado_atom("activo"), do: :activo
  defp normalizar_estado_atom("pendiente"), do: :pendiente
  defp normalizar_estado_atom("finalizado"), do: :finalizado
  defp normalizar_estado_atom(a) when is_atom(a), do: a
  defp normalizar_estado_atom(_), do: :pendiente
end
