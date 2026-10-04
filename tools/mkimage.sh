#!/bin/sh
# Turn a stage and a root into a disk image that boots.
#
#     tools/mkimage.sh <stage> <root> <work-dir> <image>
#
# A GPT disk with two partitions. The first is the EFI system partition: Bang,
# the kernel it loads, and the modules it hands the kernel — init, the kernel's
# two own, and boot.img, a small FAT image of the services init starts before
# there is a root filesystem to read. The second is the root, ext2.
#
# ext2 and not ext4: Quark's ext4 cannot yet shorten a file whose extent tree
# has grown past the inode, and `> file` on a file that is there is exactly
# that.
#
# Everything in the root is root's. It is built by somebody who is not, so
# the owner of every file is set afterwards, and what ended up in the image is
# checked with e2fsck before anything tries to boot it.
set -e
if [ $# -ne 4 ]; then
    echo "usage: mkimage.sh <stage> <root> <work-dir> <image>" >&2
    exit 2
fi
HERE=$(cd "$(dirname "$0")/.." && pwd)
STAGE=$1
ROOT=$2
WORK=$3
IMAGE=$4

# Megabytes. The root has room to work in: `cp -a /usr` should not be the
# thing that fills it.
ESP_MB=${ESP_MB:-16}
ROOT_MB=${ROOT_MB:-160}

# The services init starts from the boot image, by the names it looks for —
# and DEVMGR, which holds the machine's devices and starts the disk's driver
# for the IDE controller it finds, and LOGD, the log every service prints to.
# Not NET: there is nothing here to talk to a network with.
BOOT_SERVICES="NAMESRVR FB QTTY LOGD KEYBOARD DEVMGR DISK INPUT VFS AUTH"

mkdir -p "$WORK"

# --- boot.img -------------------------------------------------------------
# FAT32, which is the one FAT init reads; -F says so, since a megabyte would
# otherwise be FAT12.
BOOT=$WORK/boot.img
dd if=/dev/zero of="$BOOT" bs=1k count=1024 status=none
mformat -i "$BOOT" -F ::
for s in $BOOT_SERVICES; do
    mcopy -i "$BOOT" "$STAGE/boot/$s.ELF" "::$s.ELF"
done

# --- the EFI system partition ----------------------------------------------
ESP=$WORK/esp.img
dd if=/dev/zero of="$ESP" bs=1M count="$ESP_MB" status=none
mformat -i "$ESP" ::
mmd -i "$ESP" ::/EFI ::/EFI/BOOT ::/drivers
mcopy -i "$ESP" "$STAGE/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$ESP" "$STAGE/kernel.bin" ::/kernel.bin
mcopy -i "$ESP" "$HERE/bang.cfg" ::/bang.cfg
for f in "$STAGE"/drivers/*; do
    mcopy -i "$ESP" "$f" ::/drivers/
done
mcopy -i "$ESP" "$BOOT" ::/drivers/boot.img

# --- the root -----------------------------------------------------------------
# One-kilobyte blocks, as Quark's ext2 has always been given.
FS=$WORK/root.img
dd if=/dev/zero of="$FS" bs=1M count="$ROOT_MB" status=none
mkfs.ext2 -q -F -b 1024 -L gnu-quark -d "$ROOT" "$FS"
# mkfs copied each file's owner along with it, and the owner is whoever built
# this. Every inode is root's.
CMDS=$WORK/owners.debugfs
( cd "$ROOT" && find . -mindepth 1 | sed 's|^\./||' | sort ) | while read -r p; do
    printf 'sif "%s" uid 0\nsif "%s" gid 0\n' "$p" "$p"
done > "$CMDS"
printf 'sif / uid 0\nsif / gid 0\n' >> "$CMDS"
debugfs -w -f "$CMDS" "$FS" > "$WORK/owners.out" 2> "$WORK/owners.err"
# After its banner, a run where everything worked says nothing on stderr.
if grep -v '^debugfs [0-9]' "$WORK/owners.err" >&2; then
    echo "mkimage: debugfs could not set every owner" >&2
    exit 1
fi
e2fsck -fn "$FS" > "$WORK/fsck.out" 2>&1 || {
    cat "$WORK/fsck.out" >&2
    echo "mkimage: the root filesystem is not clean before it has been booted" >&2
    exit 1
}

# --- the disk -----------------------------------------------------------------
# Sectors: both partitions, and a megabyte each end for the tables.
SECTORS=$(( (ESP_MB + ROOT_MB + 2) * 2048 ))
mkgpt -o "$IMAGE" --image-size "$SECTORS" \
    --part "$ESP" --type system \
    --part "$FS" --type linux
echo "image: $IMAGE, $(( SECTORS / 2048 )) MiB"
