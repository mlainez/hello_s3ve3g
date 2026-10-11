defmodule HelloS3ve3g do
  @moduledoc """
  Minimal firmware for testing `nerves_system_s3ve3g` on a Galaxy S III Neo.
  """

  @doc """
  Reboot into Samsung download mode (Odin), for `heimdall flash --USERDATA`.

  erlinit hands the contents of `/run/reboot-param` to `reboot(2)` after the
  graceful shutdown. The kernel's syscon-reboot-mode turns "download" into
  the magic Samsung aboot looks for, and `reboot=warm` on the command line
  keeps it across the reset.
  """
  @spec reboot_to_download(Path.t()) :: no_return() | {:error, File.posix()}
  def reboot_to_download(param_path \\ "/run/reboot-param") do
    with :ok <- File.write(param_path, "download") do
      Nerves.Runtime.reboot()
    end
  end

  @doc """
  The firmware slot the bootloader will start next, with its version.
  """
  @spec slot() :: %{active: String.t(), version: String.t() | nil}
  def slot do
    active = Nerves.Runtime.KV.get("nerves_fw_active")
    %{active: active, version: Nerves.Runtime.KV.get("#{active}.nerves_fw_version")}
  end
end
