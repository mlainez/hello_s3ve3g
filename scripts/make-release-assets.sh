#!/bin/sh
#
# Build the assets of a GitHub release of this firmware, as install.sh in
# nerves_system_s3ve3g consumes them:
#
#   hello_s3ve3g.img.xz    raw image of the whole userdata layout (heimdall
#                          --USERDATA, after unxz)
#   hello_s3ve3g.fw        the same firmware for `mix upload` / fwup
#   lk2nd-s3ve3g.img       lk2nd for BOOT
#   lk2nd-LICENSE.txt      lk2nd's license notices and the commit it was built from
#   SHA256SUMS             all of the above, plus the decompressed image
#
# Usage: scripts/make-release-assets.sh [--no-build] [--lk2nd-src DIR] [--lk2nd-img FILE] [--out DIR]
#
# Publishing stays manual; the script prints the `gh release create` line.

set -eu

cd "$(dirname "$0")/.."

PORT=${S3VE3G_PORT:-../galaxy_s3_neo/ports/samsung-s3ve3g}
LK2ND_SRC=$PORT/lk2nd
LK2ND_IMG=$PORT/output/lk2nd/lk2nd-s3ve3g.img
BUILD=1
OUT=""
APP=hello_s3ve3g
MIX_TARGET=${MIX_TARGET:-s3ve3g}
export MIX_TARGET
MIX_ENV=${MIX_ENV:-dev}

while [ $# -gt 0 ]; do
  case "$1" in
    --no-build) BUILD=0; shift ;;
    --lk2nd-src) LK2ND_SRC=$2; shift 2 ;;
    --lk2nd-img) LK2ND_IMG=$2; shift 2 ;;
    --out) OUT=$2; shift 2 ;;
    -h|--help) sed -n '3,19p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

VERSION=$(sed -n 's/^ *@version "\(.*\)"/\1/p' mix.exs)
[ -n "$VERSION" ] || die "no @version in mix.exs"
OUT=${OUT:-dist/v$VERSION}
FW=_build/${MIX_TARGET}_${MIX_ENV}/nerves/images/$APP.fw

[ -f "$LK2ND_IMG" ] || die "no lk2nd image at $LK2ND_IMG"
[ "$(head -c 8 "$LK2ND_IMG")" = "ANDROID!" ] || die "$LK2ND_IMG is not an Android boot image"
if [ ! -f "$LK2ND_SRC/LICENSE" ] || [ ! -f "$LK2ND_SRC/lk2nd/LICENSE" ]; then
  die "no lk2nd source tree at $LK2ND_SRC"
fi
LK2ND_REV=$(git -C "$LK2ND_SRC" describe --tags --always)
LK2ND_SHA=$(git -C "$LK2ND_SRC" rev-parse HEAD)
[ -z "$(git -C "$LK2ND_SRC" status --porcelain --untracked-files=no)" ] ||
  die "$LK2ND_SRC has uncommitted changes: the image could not be traced to a commit"

if [ "$BUILD" = 1 ]; then
  mix deps.get
  mix firmware
fi
[ -f "$FW" ] || die "no firmware at $FW (build it, or drop --no-build)"

mkdir -p "$OUT"
[ -z "$(ls -A "$OUT")" ] || die "$OUT is not empty"

# The raw image is only needed to compress it and to record its hash.
fwup -a -d "$OUT/$APP.img" -t complete -i "$FW"
cp "$FW" "$OUT/$APP.fw"
cp "$LK2ND_IMG" "$OUT/lk2nd-s3ve3g.img"
{
  echo "lk2nd-s3ve3g.img: lk2nd $LK2ND_REV ($LK2ND_SHA), based on"
  echo "https://github.com/msm8916-mainline/lk2nd, built with"
  echo "\`make TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8226\`."
  echo
  echo "===== LICENSE ====="
  cat "$LK2ND_SRC/LICENSE"
  echo
  echo "===== lk2nd/LICENSE ====="
  cat "$LK2ND_SRC/lk2nd/LICENSE"
} > "$OUT/lk2nd-LICENSE.txt"

(cd "$OUT" && sha256sum "$APP.img" > SHA256SUMS.raw)
xz -T0 -9 "$OUT/$APP.img"
(cd "$OUT" &&
  sha256sum "$APP.img.xz" "$APP.fw" lk2nd-s3ve3g.img lk2nd-LICENSE.txt > SHA256SUMS &&
  cat SHA256SUMS.raw >> SHA256SUMS && rm SHA256SUMS.raw &&
  sha256sum -c --quiet --ignore-missing SHA256SUMS)

echo
echo "Assets in $OUT:"
ls -l "$OUT"
echo
echo "To publish (after review):"
echo "  git tag v$VERSION && git push origin v$VERSION"
echo "  gh release create v$VERSION --repo <owner>/$APP --title v$VERSION --notes-file <notes.md> \\"
echo "    $OUT/$APP.img.xz $OUT/$APP.fw $OUT/lk2nd-s3ve3g.img $OUT/lk2nd-LICENSE.txt $OUT/SHA256SUMS"
