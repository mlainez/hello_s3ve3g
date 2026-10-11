defmodule HelloS3ve3g.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    grow_data_partition()

    children = []

    opts = [strategy: :one_for_one, name: HelloS3ve3g.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.target() == :host do
    defp grow_data_partition, do: :ok
  else
    # The image is flashed raw into userdata, so /root starts at its
    # build-time 256 MiB. NervesDataResize rewrites the nested MBR with the
    # system's grow-app task and grows the f2fs filesystem to the end of
    # userdata; afterwards it returns :already_grown. It logs and never
    # raises, so a failure here leaves a working, smaller /root.
    defp grow_data_partition do
      _ = NervesDataResize.run()
      :ok
    end
  end
end
