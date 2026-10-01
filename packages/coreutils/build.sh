#!/bin/sh
# Build GNU coreutils for Quark.
#
#     packages/coreutils/build.sh <source> <build-dir> <dest-dir>
#
# <source> is an unpacked coreutils, which this writes to in one place only:
# its config.sub, to say quark is an operating system. <dest-dir> gets the
# programs, laid out like the root: usr/bin/ls and a hundred others.
#
# Nothing in coreutils is patched. `configure` runs the compiler and believes
# what happens, which is the point of having a cross toolchain: nothing here
# says where a Quark program loads or what its C library is called.
#
#   - No translations, ACLs, extended attributes, capabilities or SELinux:
#     Quark has none of them.
#   - No threads. `sort` would use them, and sorts as well without.
#   - Not stdbuf, which works by loading a shared library into another
#     program, and there are none.
#   - musl.mk, for the one file that cannot compile without being told which
#     C library it has. It says why.
set -e
SRC=${1:?usage: build.sh <source> <build-dir> <dest-dir>}
OBJ=${2:?usage: build.sh <source> <build-dir> <dest-dir>}
DEST=${3:?usage: build.sh <source> <build-dir> <dest-dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
TOOLS=$HERE/../../tools

sh "$TOOLS/teach-config-sub.sh" "$SRC/build-aux/config.sub"

mkdir -p "$OBJ" "$DEST/usr/bin"
SRC=$(cd "$SRC" && pwd)
OBJ=$(cd "$OBJ" && pwd)
DEST=$(cd "$DEST" && pwd)
cd "$OBJ"
# Built against a C library that has since changed is not built: the library
# is inside every program. Start again from clean.
STAMP=$(sh "$TOOLS/libc-stamp.sh")
if [ -f Makefile ] && [ "$(cat libc.stamp 2>/dev/null)" != "$STAMP" ]; then
    echo "coreutils: the C library has changed; building again"
    make clean >/dev/null
fi
echo "$STAMP" > libc.stamp
if [ ! -f Makefile ]; then
    "$SRC/configure" \
        --host=x86_64-quark \
        --prefix=/usr \
        CC=x86_64-quark-musl-gcc \
        --disable-nls --disable-acl --disable-xattr --disable-libcap \
        --disable-threads --without-selinux --without-openssl \
        --enable-no-install-program=stdbuf
fi
MAKEFILES="$HERE/musl.mk" make -j"${JOBS:-$(nproc)}"

# The programs, and only the programs: an install also brings manuals, and a
# build tree also holds helpers built for the machine it was built on. What
# `make install` would put in bin is what is wanted, so it is asked. It
# installs over what the last build installed; which programs there are is
# decided by `configure`, and that runs once for a build directory.
STAGING=$OBJ/install
make install-exec DESTDIR="$STAGING" >/dev/null
n=0
for f in "$STAGING"/usr/bin/*; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    cp "$f" "$DEST/usr/bin/"
    x86_64-quark-strip "$DEST/usr/bin/$(basename "$f")"
    n=$((n + 1))
done
echo "coreutils: $n programs in $DEST/usr/bin"
