defmodule ClienteAdminWeb.SorteoHTML do
  use ClienteAdminWeb, :html

  import ClienteAdminWeb.Layouts, only: [app: 1]

  embed_templates "sorteo_html/*"
end
