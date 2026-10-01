#!/bin/sh
# Build GNU diffutils for Quark.
#
#     packages/diffutils/build.sh <source> <build-dir> <dest-dir>
#
# diff, cmp, diff3 and sdiff. Nothing is patched.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST --disable-nls --disable-threads
make -j"${JOBS:-$(nproc)}"

make install-exec DESTDIR="$OBJ/install" >/dev/null
install_staged "$OBJ/install/usr/bin"
