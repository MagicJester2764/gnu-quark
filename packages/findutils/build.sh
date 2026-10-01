#!/bin/sh
# Build GNU findutils for Quark.
#
#     packages/findutils/build.sh <source> <build-dir> <dest-dir>
#
# find and xargs. Nothing is patched.
#
# Not locate and updatedb. They are a database of every name on the disk and
# the job that rebuilds it each night, and there is nothing here that runs a
# job each night; a database made once at build time would describe the
# build. `find` answers the same question by looking.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST \
    --disable-nls --disable-threads --without-selinux
make -j"${JOBS:-$(nproc)}"

install_programs find/find xargs/xargs
echo "findutils: find and xargs in $DEST/usr/bin"
