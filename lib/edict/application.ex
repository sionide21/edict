defmodule Edict.Application do
  @moduledoc false
  use Application
  alias Edict.HealthCheck
  alias Edict.Redis.Connection

  def start(_type, _args) do
    children = [
      {Codex, Edict.Config.topic()},
      :ranch.child_spec(Connection, :ranch_tcp, [port: Edict.Config.redis_port()], Connection,
        handler: Edict.Commands
      ),
      :ranch.child_spec(
        HealthCheck,
        :ranch_tcp,
        [port: Edict.Config.healthcheck_port()],
        HealthCheck,
        []
      )
    ]

    opts = [strategy: :one_for_one, name: Edict.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
