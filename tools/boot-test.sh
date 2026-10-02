#!/bin/sh
# Boot the image and drive it from a script of key presses.
#
#     tools/boot-test.sh <keys-file>
#
# `IMG` is the image to boot (gnu-quark.img) and `RUNDIR` where the emulator's
# sockets and log go. The image is booted as it is and written to: a test of
# a filesystem is a test of what was left on the disk.
# `CPU` is the processor to emulate: `max` unless said otherwise, which has the
# SMEP and SMAP the kernel turns on when it finds them.
# `SMP` is how many processors the machine has: one unless said otherwise.
# `MEM` is how much memory: a gigabyte unless said otherwise. `MEM=6G` is a
# machine with memory above four gigabytes.
#
# A program's output goes to the screen and not to the serial line, so the
# screen is the result. The console draws one bitmap font on a grid, which
# makes a screendump of it its text exactly (`tools/screentext.py`), and that
# is what a script's `expect`, `text` and `transcript` lines read: wait for a
# prompt, and keep what was printed. Serial carries the kernel's own faults.
#
# Exits 1 if an `expect` gave up or the kernel faulted.
#
# Two things worth not rediscovering:
#
#  - Never kill the emulator by matching its name. Any shell whose command
#    line mentions it matches too, including the one running this. Kill by
#    pid.
#  - No `set -e`. Half of what this does is tidying up after a previous run
#    that may not have happened.
HERE=$(cd "$(dirname "$0")" && pwd)
TOP=$(cd "$HERE/.." && pwd)
RUN=${RUNDIR:-${TMPDIR:-/tmp}/gnu-quark-boot-test}
IMG=${IMG:-gnu-quark.img}
BANG=${BANG_DIR:-$TOP/../bang}
mkdir -p "$RUN"
# The screen is read against the font it is drawn in, which is the one the
# image loads at boot.
if [ -z "$QUARK_FONT_HEX" ] && [ -f "$TOP/build/root/usr/share/consolefonts/unifont.hex" ]; then
    QUARK_FONT_HEX=$TOP/build/root/usr/share/consolefonts/unifont.hex
fi
export QUARK_FONT_HEX

[ -f "$RUN/qemu.pid" ] && kill "$(cat "$RUN/qemu.pid")" 2>/dev/null
rm -f "$RUN/qmp.sock" "$RUN/serial.log"

cd "$TOP"
# The firmware writes its variable store, and the one in bang is tracked. Boot
# from a copy, so a test run does not leave the bootloader's tree dirty.
cp "$BANG/firmware-redist/ovmf/OVMF_VARS.fd" "$RUN/OVMF_VARS.fd"
qemu-system-x86_64 $(test -w /dev/kvm && echo -enable-kvm) -cpu "${CPU:-max}" -smp "${SMP:-1}" -m "${MEM:-1G}" \
  -L "$BANG/firmware-redist/ovmf/" \
  -pflash "$BANG/firmware-redist/ovmf/OVMF_CODE.fd" \
  -pflash "$RUN/OVMF_VARS.fd" \
  -hda "$IMG" -display none \
  -qmp unix:"$RUN/qmp.sock",server,nowait \
  -serial file:"$RUN/serial.log" 2>/dev/null &
echo $! > "$RUN/qemu.pid"

status=0
python3 "$HERE/drive-qemu.py" "$RUN/qmp.sock" "$1" || status=1
kill "$(cat "$RUN/qemu.pid")" 2>/dev/null || true
rm -f "$RUN/qemu.pid"

if grep -aq "KFAULT\|PANIC" "$RUN/serial.log" 2>/dev/null; then
    echo "KERNEL FAULT:"
    grep -a "KFAULT\|PANIC" "$RUN/serial.log"
    status=1
fi
echo "serial: $RUN/serial.log"
exit $status
