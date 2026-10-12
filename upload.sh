#!/bin/sh
#
# Upload firmware to the phone over the ssh fwup subsystem.
#
# Usage: ./upload.sh [host] [firmware.fw]
#
# ssh runs with an emptied environment, keeping only PATH, HOME and the
# agent socket. OpenSSH sends LANG/LC_*/COLORTERM as "env" channel requests
# (SendEnv in the system ssh_config), and Erlang/OTP 29.0.6 (ssh 6.0.5)
# rejects a subsystem request that follows an "env" request (OTP-20371).
# `mix upload` from ssh_subsystem_fwup 0.6.9 empties the environment too, but
# also drops SSH_AUTH_SOCK, so keys held by an agent are not offered.

set -e

HOST=${1:-nerves.local}
FW=$2

if [ -z "$FW" ]; then
  FW="_build/${MIX_TARGET:-s3ve3g}_${MIX_ENV:-dev}/nerves/images/hello_s3ve3g.fw"
fi

if [ ! -f "$FW" ]; then
  echo "Firmware not found: $FW (run 'MIX_TARGET=s3ve3g mix firmware' first)" >&2
  exit 1
fi

fwup -m -i "$FW" | grep -E '^meta-(product|version|uuid)=' || true
echo "Uploading $FW to $HOST..."

exec env -i PATH="$PATH" HOME="$HOME" ${SSH_AUTH_SOCK:+SSH_AUTH_SOCK="$SSH_AUTH_SOCK"} \
  sh -c 'cat "$1" | ssh -s -- "$2" fwup' sh "$FW" "$HOST"
