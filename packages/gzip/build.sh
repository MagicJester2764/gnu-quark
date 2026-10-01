#!/bin/sh
# Build GNU gzip for Quark.
#
#     packages/gzip/build.sh <source> <build-dir> <dest-dir>
#
# gzip, and the shell scripts that come with it: gunzip and zcat, which are
# gzip under another name, and zgrep, zdiff and the rest, which run another
# program on what gzip unpacks. Nothing is patched and nothing needs saying:
# configure asks the compiler and believes it.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST
make -j"${JOBS:-$(nproc)}"

make install-exec DESTDIR="$OBJ/install" >/dev/null
install_staged "$OBJ/install/usr/bin"
