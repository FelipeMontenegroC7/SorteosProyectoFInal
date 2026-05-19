import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cliente_jugador_web, ClienteJugadorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "u7yksfg8pspDFCu4WgQI/H0YGjK5jcrEeNkn92qKHnkKModPKPO/3fODfxdHppKz",
  server: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :cliente_admin_web, ClienteAdminWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Fzr3tSjeoH9vjkU6hwKKxVKGzFXWLgnXrgIuPU7A/LSa9SsU4C4QhF0tpZZR+JOP",
  server: false
