# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :kafka_ex,
  brokers: [
    {"localhost", 9092}
  ],
  sync_timeout: 10_000,
  kafka_version: "0.11.0"

# config :logger,
#   level: :info,
#
#   compile_time_purge_matching: [
#     [level_lower_than: :info]
#   ]

config :logger, :console, metadata: [:pid]
