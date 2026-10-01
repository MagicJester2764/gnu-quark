#!/bin/sh
# Build GNU grep for Quark.
#
#     packages/grep/build.sh <source> <build-dir> <dest-dir>
#
# grep, and egrep and fgrep, which are two lines of shell each. Nothing is
# patched.
#
#   - No translations.
#   - No Perl regular expressions (`grep -P`): they are a library, PCRE2, and
#     that is a package nobody has made yet. grep says so if it is asked.
#   - No threads: grep searches one file at a time either way.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST \
    --disable-nls --disable-perl-regexp --disable-threads
make -j"${JOBS:-$(nproc)}"

make install-exec DESTDIR="$OBJ/install" >/dev/null
install_staged "$OBJ/install/usr/bin"
