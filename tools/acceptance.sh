#!/bin/sh
# Boot the image, type the acceptance script at it, and check what it did.
#
#     tools/acceptance.sh [gnu-quark.img]
#
# The image booted is a copy: a test writes to the disk it boots, and the
# image that was built should stay the image that was built. What the console
# showed is left in build/acceptance.txt, the coloured listing in
# build/acceptance-ls.ppm, and the root filesystem the test left behind is
# checked with e2fsck — a system that ran every command and left a broken
# filesystem has not passed.
#
# `SMP` is how many processors the machine is given (one unless said), and
# the script is told: `@SMP@` in it is that number, so that what `nproc`
# says can be held to what the machine has.
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"
IMAGE=${1:-gnu-quark.img}
mkdir -p build
cp "$IMAGE" build/acceptance.img

status=0
sed "s/@SMP@/${SMP:-1}/g" tests/acceptance.keys > build/acceptance.keys
IMG=build/acceptance.img sh tools/boot-test.sh build/acceptance.keys || status=1
if sh tools/check-rootfs.sh build/acceptance.img > build/acceptance-fsck.txt 2>&1; then
    echo "e2fsck: clean"
else
    cat build/acceptance-fsck.txt
    echo "e2fsck: the root filesystem the test left is not clean"
    status=1
fi
if [ $status -eq 0 ]; then
    echo "acceptance: passed"
else
    echo "acceptance: FAILED (what the console showed is in build/acceptance.txt)"
fi
exit $status
