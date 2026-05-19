alias ServidorCentral.{Usuarios, GestorSorteos, Sorteo}

IO.puts("=== Seeding Azar S.A. ===")

# === Registrar jugadores adicionales ===
jugadores = [
  {"maria_lopez", "jugador123"},
  {"carlos_garcia", "jugador123"},
  {"ana_martinez", "jugador123"},
  {"pedro_sanchez", "jugador123"},
  {"luisa_ramirez", "jugador123"}
]

for {usuario, pass} <- jugadores do
  case Usuarios.registrar_usuario(usuario, pass) do
    {:ok, _} -> IO.puts("  ✅ Jugador #{usuario} creado")
    {:error, :ya_existe} -> IO.puts("  ⏭️  Jugador #{usuario} ya existe")
    {:error, razon} -> IO.puts("  ❌ Error creando #{usuario}: #{inspect(razon)}")
  end
end

# === Recargar créditos a todos ===
todos_jugadores = ["juandiaz" | Enum.map(jugadores, &elem(&1, 0))]

for jugador <- todos_jugadores do
  case Usuarios.saldo(jugador) do
    {:ok, saldo} when saldo < 100_000 ->
      monto = 500_000 - saldo
      Usuarios.recargar_creditos(jugador, monto)
      IO.puts("  💰 #{jugador}: recargado $#{monto} (saldo: $#{saldo + monto})")
    {:ok, saldo} ->
      IO.puts("  💰 #{jugador}: ya tiene $#{saldo}")
    _ ->
      IO.puts("  ⚠️  #{jugador}: no encontrado")
  end
end

# === Crear sorteos nuevos ===
ahora = DateTime.utc_now()

sorteos_nuevos = [
  %{
    nombre: "Loteria de Navidad",
    fecha: DateTime.add(ahora, 3 * 24 * 3600) |> DateTime.to_iso8601() |> String.slice(0, 16),
    valor_billete: 100_000,
    fracciones: 10,
    cantidad_billetes: 50,
    descripcion_premio_completo: "Casa valorada en 200 millones",
    descripcion_premio_fraccion: "20 millones por fracción",
    premios: [
      %{nombre: "Premio Mayor", descripcion: "Casa + Carro", valor: 200_000_000, orden: 1},
      %{nombre: "Segundo Premio", descripcion: "Viaje al Caribe", valor: 50_000_000, orden: 2},
      %{nombre: "Tercer Premio", descripcion: "Moto nueva", valor: 10_000_000, orden: 3}
    ]
  },
  %{
    nombre: "Sorteo Relámpago",
    fecha: DateTime.add(ahora, 1 * 24 * 3600) |> DateTime.to_iso8601() |> String.slice(0, 16),
    valor_billete: 20_000,
    fracciones: 4,
    cantidad_billetes: 200,
    descripcion_premio_completo: "5 millones de pesos",
    descripcion_premio_fraccion: "1.25 millones por fracción",
    premios: [
      %{nombre: "Premio Único", descripcion: "Efectivo", valor: 5_000_000, orden: 1}
    ]
  },
  %{
    nombre: "Gran Sorteo del Quindío",
    fecha: DateTime.add(ahora, 7 * 24 * 3600) |> DateTime.to_iso8601() |> String.slice(0, 16),
    valor_billete: 75_000,
    fracciones: 5,
    cantidad_billetes: 150,
    descripcion_premio_completo: "Apartamento en Armenia",
    descripcion_premio_fraccion: "30 millones por fracción",
    premios: [
      %{nombre: "Premio Mayor", descripcion: "Apartamento", valor: 150_000_000, orden: 1},
      %{nombre: "Segundo Premio", descripcion: "Electrodomésticos", valor: 15_000_000, orden: 2}
    ]
  }
]

for s <- sorteos_nuevos do
  case GestorSorteos.consultar_estado(s.nombre) do
    %Sorteo{} ->
      IO.puts("  ⏭️  Sorteo '#{s.nombre}' ya existe")

    nil ->
      sorteo_struct = %Sorteo{
        nombre: s.nombre,
        fecha: s.fecha,
        valor_billete: s.valor_billete,
        fracciones: s.fracciones,
        cantidad_billetes: s.cantidad_billetes,
        descripcion_premio_completo: s.descripcion_premio_completo,
        descripcion_premio_fraccion: s.descripcion_premio_fraccion,
        inserted_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      case GestorSorteos.crear_nuevo_sorteo(sorteo_struct) do
        {:ok, _} ->
          IO.puts("  🎰 Sorteo '#{s.nombre}' creado")
          # Agregar premios
          for p <- s.premios do
            premio = %{
              id: Ecto.UUID.generate(),
              nombre: p.nombre,
              descripcion: p.descripcion,
              valor: p.valor,
              orden: p.orden
            }
            GestorSorteos.agregar_premio(s.nombre, premio)
            IO.puts("    🏆 Premio '#{p.nombre}' ($#{p.valor}) agregado")
          end
        {:error, razon} ->
          IO.puts("  ❌ Error creando sorteo '#{s.nombre}': #{inspect(razon)}")
      end
  end
end

# === Simular compras de fracciones ===
IO.puts("\n=== Simulando compras ===")

compras = [
  {"Loteria de Navidad", "juandiaz", 3},
  {"Loteria de Navidad", "maria_lopez", 5},
  {"Loteria de Navidad", "carlos_garcia", 2},
  {"Loteria de Navidad", "ana_martinez", 4},
  {"Sorteo Relámpago", "juandiaz", 2},
  {"Sorteo Relámpago", "pedro_sanchez", 3},
  {"Sorteo Relámpago", "luisa_ramirez", 4},
  {"Sorteo Relámpago", "maria_lopez", 2},
  {"Gran Sorteo del Quindío", "carlos_garcia", 3},
  {"Gran Sorteo del Quindío", "ana_martinez", 2},
  {"Gran Sorteo del Quindío", "juandiaz", 1},
  {"Loteria Uniquindio", "juandiaz", 2},
  {"Loteria Uniquindio", "maria_lopez", 3},
  {"Loteria Uniquindio", "pedro_sanchez", 1},
  {"Loteria-Nacional", "ana_martinez", 2},
  {"Loteria-Nacional", "luisa_ramirez", 3},
  {"Loteria-Nacional", "carlos_garcia", 2},
  {"Loteria Armenia", "maria_lopez", 2},
  {"Loteria Armenia", "juandiaz", 1}
]

for {sorteo, jugador, cantidad} <- compras do
  case GestorSorteos.consultar_estado(sorteo) do
    %Sorteo{estado: :activo} ->
      Enum.each(1..cantidad, fn _ ->
        case GestorSorteos.comprar_fraccion(sorteo, jugador) do
          {:ok, v} -> IO.puts("  🎟️  #{jugador} compró fracción de '#{sorteo}' (B#{v.billete}/F#{v.fraccion})")
          {:error, razon} -> IO.puts("  ⚠️  #{jugador} no pudo comprar en '#{sorteo}': #{inspect(razon)}")
        end
      end)
    %Sorteo{estado: :finalizado} ->
      IO.puts("  ⏭️  '#{sorteo}' ya finalizado, omitiendo compras de #{jugador}")
    nil ->
      IO.puts("  ⚠️  Sorteo '#{sorteo}' no encontrado")
  end
end

IO.puts("\n=== Seed completado ===")
