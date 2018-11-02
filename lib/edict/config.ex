defmodule Edict.Config do
  def topic do
    "feature_flags"
  end

  def password do
    nil
  end

  def redis_port do
    5555
  end

  def healthcheck_port do
    8555
  end
end
