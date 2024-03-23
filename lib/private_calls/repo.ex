defmodule PrivateCalls.Repo do
  use Ecto.Repo,
    otp_app: :private_calls,
    adapter: Ecto.Adapters.Postgres
end
