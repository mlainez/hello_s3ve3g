defmodule HelloS3ve3g.WiFi do
  @moduledoc false

  require Logger

  @doc """
  The Wi-Fi MAC address for VintageNetWiFi's `mac_address` callback.

  s3ve3g-bringup copies the address Samsung stored on the `efs` partition to
  `/run/s3ve3g/wlan0.mac`. Without it, the address is derived from the eMMC
  CID, so it is still stable across boots and unique per phone.
  """
  @spec mac_address(Path.t(), Path.t()) :: String.t()
  def mac_address(efs_copy \\ "/run/s3ve3g/wlan0.mac", sysfs_root \\ "/sys/class/mmc_host") do
    with {:ok, text} <- File.read(efs_copy),
         mac = text |> String.trim() |> String.downcase(),
         true <- Regex.match?(~r/\A([0-9a-f]{2}:){5}[0-9a-f]{2}\z/, mac) do
      mac
    else
      _ -> from_cid(sysfs_root)
    end
  end

  defp from_cid(sysfs_root) do
    cid_path =
      sysfs_root
      |> Path.join("mmc*/mmc*:*/cid")
      |> Path.wildcard()
      |> Enum.find(fn path ->
        case File.read(Path.join(Path.dirname(path), "type")) do
          {:ok, type} -> String.trim(type) == "MMC"
          _ -> false
        end
      end)

    with cid_path when is_binary(cid_path) <- cid_path,
         {:ok, cid} <- File.read(cid_path),
         cid = String.trim(cid),
         true <- Regex.match?(~r/\A[0-9a-fA-F]{32}\z/, cid) do
      suffix = cid |> String.slice(-10, 10) |> String.downcase()
      octets = for <<octet::binary-size(2) <- suffix>>, do: octet
      # Locally administered, unicast.
      Enum.join(["02" | octets], ":")
    else
      reason ->
        Logger.warning("No Wi-Fi MAC from efs or the eMMC CID: #{inspect(reason)}")
        "02:00:00:00:00:01"
    end
  end
end
