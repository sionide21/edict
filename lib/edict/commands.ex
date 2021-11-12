defmodule Edict.Commands do
  use Edict.Redis.Handler
  import Edict.Config, only: [topic: 0, password: 0]

  @impl true
  def init() do
    {:ok, %{auth: is_nil(password())}}
  end

  @impl true
  def handle_command(["auth", pw], state) do
    case password() do
      nil ->
        {:reply, {:error, "ERR", "Client sent AUTH, but no password is set"}, state}

      ^pw ->
        {:reply, :OK, %{state | auth: true}}

      _ ->
        {:reply, {:error, "ERR", "invalid password"}, %{state | auth: false}}
    end
  end

  def handle_command(_, state = %{auth: false}) do
    {:reply, {:error, "NOAUTH", "Authentication required."}, state}
  end

  def handle_command(command, state = %{auth: true}) do
    handle_authenticated_command(command, state)
  end

  def handle_authenticated_command(["get", key], state) do
    value =
      topic()
      |> Codex.fetch(key)
      |> case do
        {:ok, value} ->
          value

        :error ->
          nil
      end

    {:reply, value, state}
  end

  def handle_authenticated_command(["mget" | keys], state) do
    entries = Codex.entries(topic())
    values = Enum.map(keys, &Map.get(entries, &1))

    {:reply, values, state}
  end

  def handle_authenticated_command(["set", key, value], state) do
    Codex.set(topic(), key, value)
    {:reply, :OK, state}
  end

  def handle_authenticated_command(["del" | keys], state) do
    entries = Codex.entries(topic())

    count =
      keys
      |> Enum.filter(&Map.has_key?(entries, &1))
      |> Enum.map(&Codex.set(topic(), &1, nil))
      |> Enum.count()

    {:reply, count, state}
  end

  def handle_authenticated_command(["exists" | keys], state) do
    entries = Codex.entries(topic())

    count =
      keys
      |> Enum.filter(&Map.has_key?(entries, &1))
      |> Enum.count()

    {:reply, count, state}
  end

  def handle_authenticated_command([cmd | _args], state) do
    {:reply, {:error, "ERR", "unknown command '#{cmd}'"}, state}
  end
end
