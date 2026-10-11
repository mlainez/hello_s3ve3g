# hello_s3ve3g

Minimal firmware for testing
[`nerves_system_s3ve3g`](../nerves_system_s3ve3g) on a Samsung Galaxy S III
Neo: IEx on the screen, ssh over USB (`usb0`, VintageNetDirect) and Wi-Fi
(`wlan0`, VintageNetWiFi), and the application partition grown to fill
`userdata` on first boot.

```bash
cp config/target.secret.exs.example config/target.secret.exs   # optional Wi-Fi
export MIX_TARGET=s3ve3g
mix deps.get
mix firmware
mix firmware.image hello_s3ve3g.img     # first install: heimdall flash --USERDATA
mix upload nerves.local                 # later updates, over ssh
```

On the phone:

- `HelloS3ve3g.slot()`: the slot that boots next and its version.
- `Nerves.Runtime.revert()`: go back to the other slot and reboot.
- `HelloS3ve3g.reboot_to_download()`: reboot into Samsung download mode.
