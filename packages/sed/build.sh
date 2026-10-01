#!/bin/sh
# Build GNU sed for Quark.
#
#     packages/sed/build.sh <source> <build-dir> <dest-dir>
#
# Nothing is patched. No translations, ACLs or SELinux: Quark has none of
# them.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST \
    --disable-nls --disable-acl --without-selinux
make -j"${JOBS:-$(nproc)}"

make install-exec DESTDIR="$OBJ/install" >/dev/null
install_staged "$OBJ/install/usr/bin"
