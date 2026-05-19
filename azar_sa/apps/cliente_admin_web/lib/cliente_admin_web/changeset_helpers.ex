defmodule ClienteAdminWeb.ChangesetHelpers do
  @moduledoc false

  def messages(%Ecto.Changeset{} = cs) do
    cs
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, msgs} ->
      "#{field}: #{Enum.join(msgs, ", ")}"
    end)
  end
end
