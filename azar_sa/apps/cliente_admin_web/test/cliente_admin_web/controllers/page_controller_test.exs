defmodule ClienteAdminWeb.PageControllerTest do
  use ClienteAdminWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Panel de operaciones"
  end
end
