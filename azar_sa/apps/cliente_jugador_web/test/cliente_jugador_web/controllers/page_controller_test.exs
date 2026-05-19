defmodule ClienteJugadorWeb.PageControllerTest do
  use ClienteJugadorWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Lotería premium"
  end
end
