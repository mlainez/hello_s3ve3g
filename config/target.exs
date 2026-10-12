import Config

# Use RingLogger as the logger backend and remove :console.
config :logger, backends: [RingLogger]

# Start nerves_runtime and nerves_pack (networking, ssh, mDNS) before the
# application, so a crash in the application still leaves ssh up.
config :shoehorn, init: [:nerves_runtime, :nerves_pack]

# lk2nd has no boot counter, so an unvalidated slot could not fall back
# anyway; fwup marks a slot valid when the upgrade completes. StartupGuard
# would only reboot into the same slot.
config :nerves_runtime, startup_guard_enabled: false

# The phone has no battery-backed clock that Linux can read yet; start no
# earlier than the build time.
config :nerves, :erlinit, update_clock: true

# Authorize the host's ssh keys for IEx, sftp and `mix upload`.
keys =
  System.user_home!()
  |> Path.join(".ssh/id_{rsa,ecdsa,ed25519}.pub")
  |> Path.wildcard()

if keys == [],
  do:
    Mix.raise("""
    No SSH public keys found in ~/.ssh. An ssh authorized key is needed to
    log into the Nerves device and update firmware on it using ssh.
    """)

config :nerves_ssh, authorized_keys: Enum.map(keys, &File.read!/1)

wifi_secrets_path = Path.join(__DIR__, "target.secret.exs")

wifi_networks =
  if File.exists?(wifi_secrets_path) do
    {networks, _bindings} = Code.eval_file(wifi_secrets_path)
    networks
  else
    IO.warn(
      "#{wifi_secrets_path} not found; wlan0 will have no configured network. " <>
        "Copy config/target.secret.exs.example to config/target.secret.exs."
    )

    []
  end

# usb0 is the kernel's built-in g_ether. VintageNetDirect gives the phone
# and the host a /30 derived from the hostname and runs a DHCP server, so
# `ssh nerves-XXXX.local` or the printed address works over the cable.
config :vintage_net,
  regulatory_domain: "00",
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"wlan0",
     %{
       type: VintageNetWiFi,
       mac_address: {HelloS3ve3g.WiFi, :mac_address, []},
       vintage_net_wifi: %{networks: wifi_networks},
       ipv4: %{method: :dhcp}
     }}
  ]

config :mdns_lite,
  hosts: [:hostname, "nerves"],
  ttl: 120,
  services: [
    %{protocol: "ssh", transport: "tcp", port: 22},
    %{protocol: "sftp-ssh", transport: "tcp", port: 22},
    %{protocol: "epmd", transport: "tcp", port: 4369}
  ]

# Grow the application partition (nested partition 3 of userdata) to the
# end of userdata on first boot: rewrite the nested MBR with the grow-app
# task, reload the kpartx mapping, then resize.f2fs.
#
# nerves_data_resize takes the basename of these paths as the kernel name:
# it reads /sys/class/block/<disk>/size and runs `dmsetup table <partition>`.
# /dev/rootdisk0 and /dev/nerves-app (also /root's source in /proc/mounts)
# are symlinks with no sysfs or device-mapper entry under that name, so both
# are given by kernel name: userdata is mmcblk0p26 in the GT-I9301I's fixed
# GPT, and kpartx names its third partition mmcblk0p26p3.
config :nerves_data_resize, :config,
  mount_point: "/root",
  partition: "/dev/mapper/mmcblk0p26p3",
  grow_partition: [
    disk: "/dev/mmcblk0p26",
    ops_fw: "/usr/share/fwup/ops.fw",
    task: "grow-app"
  ]
