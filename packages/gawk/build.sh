#!/bin/sh
# Build GNU awk for Quark.
#
#     packages/gawk/build.sh <source> <build-dir> <dest-dir>
#
# gawk, and awk as a name for it. Nothing is patched.
#
#   - No translations.
#   - No extensions: they are shared libraries gawk loads when a program
#     asks for one, and nothing here loads a library.
#   - No readline for its debugger, and no MPFR: neither is a package yet.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST \
    --disable-nls --disable-extensions --without-readline --without-mpfr
make -j"${JOBS:-$(nproc)}"

install_programs gawk
ln -sf gawk "$DEST/usr/bin/awk"
echo "gawk: gawk, and awk, in $DEST/usr/bin"
