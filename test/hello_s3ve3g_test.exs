defmodule HelloS3ve3gTest do
  use ExUnit.Case

  @moduletag :tmp_dir

  test "uses the MAC address copied from efs", %{tmp_dir: dir} do
    path = Path.join(dir, "wlan0.mac")
    File.write!(path, "5C:0A:5B:12:34:56\n")
    assert HelloS3ve3g.WiFi.mac_address(path, dir) == "5c:0a:5b:12:34:56"
  end

  test "derives a locally administered MAC from the eMMC CID", %{tmp_dir: dir} do
    card = Path.join(dir, "mmc0/mmc0:0001")
    File.mkdir_p!(card)
    File.write!(Path.join(card, "type"), "MMC\n")
    File.write!(Path.join(card, "cid"), "11010030303847393201a2b3c4d5e600\n")

    assert HelloS3ve3g.WiFi.mac_address(Path.join(dir, "missing"), dir) ==
             "02:b3:c4:d5:e6:00"
  end

  test "falls back to a fixed address without efs or CID", %{tmp_dir: dir} do
    assert HelloS3ve3g.WiFi.mac_address(Path.join(dir, "missing"), dir) ==
             "02:00:00:00:00:01"
  end

  test "writes the reboot parameter before rebooting", %{tmp_dir: dir} do
    path = Path.join([dir, "missing-dir", "reboot-param"])
    assert HelloS3ve3g.reboot_to_download(path) == {:error, :enoent}
  end
end
