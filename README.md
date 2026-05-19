# HoySiCoronamos S.A. 🎰 — Plataforma de Sorteos y Loterías

**Azar S.A.** es un sistema distribuido de venta y gestión de sorteos de lotería, desarrollado con **Elixir** utilizando una arquitectura de aplicación **Umbrella** (aplicación paraguas). 

El sistema cuenta con un backend centralizado para el manejo de estados de sorteos en tiempo real mediante procesos concurrentes, y dos portales web desarrollados en **Phoenix Framework**: uno para los jugadores y otro para los administradores.

---

## 🏗️ Arquitectura del Proyecto

El proyecto está organizado como una aplicación Umbrella con las siguientes sub-aplicaciones en la carpeta `apps/`:

### 1. `servidor_central` (Núcleo & Backend)
Es el núcleo lógico del sistema. No tiene interfaz gráfica pero provee los servicios a los portales web:
* **Concurrencia con GenServer:** Cada sorteo activo corre en su propio proceso de backend (`SorteoServer`) supervisado por un `DynamicSupervisor` (`GestorSorteos`). Esto garantiza que los sorteos funcionen de manera aislada y en tiempo real.
* **Persistencia en JSON:** El estado de los sorteos, jugadores y administradores se almacena y lee en archivos de formato JSON bajo la carpeta `azar_sa/data/`.
* **Bitácora de seguridad:** Todas las acciones críticas (compra, devolución, creación y ejecución de sorteos) se registran en una bitácora centralizada en `data/bitacora.txt`.
* **Carga dinámica:** Al iniciar la aplicación, los sorteos guardados en disco se pre-cargan automáticamente en memoria.

### 2. `cliente_jugador_web` (Portal de Jugadores) — Puerto `4000`
Portal web responsivo donde los jugadores registrados pueden:
* Registrarse e iniciar sesión.
* Recargar créditos virtuales.
* Visualizar sorteos activos.
* Comprar fracciones aleatorias, fracciones específicas o el billete completo de un sorteo.
* Devolver fracciones compradas antes de que se ejecute el sorteo (con reembolso automático).
* Consultar su historial de transacciones y boletos ganadores.

### 3. `cliente_admin_web` (Portal de Administración) — Puerto `4001`
Portal web seguro e independiente para los administradores del sistema:
* Crear nuevos sorteos parametrizando: nombre, fecha y hora de ejecución, cantidad de billetes, número de fracciones por billete y costo.
* Configurar múltiples premios para cada sorteo (Premio Mayor, Secundarios, etc.).
* Eliminar sorteos activos (solo si no tienen ventas registradas).
* **Ejecutar sorteos:** Genera el número ganador al azar, calcula los ganadores proporcionales según sus fracciones y distribuye las ganancias automáticamente.
* Consultar balances financieros globales e individuales por sorteo (ingresos brutos, premios pagados y ganancia neta).
* Ver el listado detallado de clientes con sus créditos y comportamiento de compra.

---

## 🔑 Credenciales de Prueba

El sistema inicializa datos de prueba de forma automática al arrancar por primera vez (`Seeds`). Puedes utilizar las siguientes credenciales para probar la plataforma:

OJO EL PROYECTO LO SUBI A GIT HUB CON TODOS LOS DATOS HASTA EL MOMENTO. :) PERO LAS CONTRASEÑAS ESTAN HASHEADAS.

### Administrador
* **Usuario:** `admin`
* **Contraseña:** `admin123`

### Jugadores
* **Usuario:** `juandiaz` | **Contraseña:** `jugador123` *(Inicia con $500)*
* **Usuario:** `maria_lopez` | **Contraseña:** `jugador123` *(Inicia con $1000)*
* **Usuario:** `carlos_ruiz` | **Contraseña:** `jugador123` *(Inicia con $1000)*

---

## ⚡ Requisitos Previos

Asegúrate de tener instalado en tu sistema:
* **Erlang** (versión 25 o superior recomendada)
* **Elixir** (versión 1.14 o superior recomendada)
* **Node.js** (para la compilación de recursos estáticos si es necesario)

---

## 🚀 Instalación y Ejecución

Sigue estos pasos para poner a correr el proyecto en tu entorno local:

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/FelipeMontenegroC7/SorteosProyectoFInal.git
   cd SorteosProyectoFInal
   ```

2. **Ingresar a la carpeta de la aplicación:**
   ```bash
   cd azar_sa
   ```

3. **Instalar las dependencias de Elixir:**
   ```bash
   mix deps.get
   ```

4. **Levantar los servidores de desarrollo:**
   Ejecuta el siguiente comando para arrancar la aplicación umbrella. Esto iniciará el servidor central y ambos portales web de forma simultánea:
   ```bash
   mix phx.server
   ```
   *(También puedes correrlo interactivamente con la consola de Elixir usando `iex -S mix phx.server`)*

5. **Acceder a los portales:**
   * **Portal del Jugador:** [http://localhost:4000](http://localhost:4000)
   * **Portal del Administrador:** [http://localhost:4001](http://localhost:4001)

---

## 📁 Estructura de Datos y Persistencia
Todos los archivos de persistencia local se encuentran en `azar_sa/data/`:
* `usuarios.json`: Almacena información de los jugadores, hashes de contraseñas y saldo de créditos.
* `admins.json`: Almacena credenciales de administradores.
* `bitacora.txt`: Historial cronológico y descriptivo de eventos de negocio.
* `Loteria-[Nombre].json`: Archivos individuales para el estado interno e histórico de ventas de cada lotería.
