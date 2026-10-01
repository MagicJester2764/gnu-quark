#!/bin/sh
# Build GNU make for Quark.
#
#     packages/make/build.sh <source> <build-dir> <dest-dir>
#
# Nothing is patched.
#
#   - No translations.
#   - No Guile, and no loading of objects into make: both are libraries
#     loaded at run time.
#   - The C of 2017. make 4.4.1 carries a file that declares `getenv ()`
#     the way C was written before prototypes, and the compiler's default
#     is now the C of 2023, where that means it takes no arguments. The
#     source says which language it is in by being in it; the flag says so
#     to the compiler.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST CFLAGS="-g -O2 -std=gnu17" \
    --disable-nls --without-guile --disable-load
make -j"${JOBS:-$(nproc)}"

install_programs make
echo "make: make in $DEST/usr/bin"
