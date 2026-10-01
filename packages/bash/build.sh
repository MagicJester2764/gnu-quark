#!/bin/sh
# Build GNU bash for Quark.
#
#     packages/bash/build.sh <source> <build-dir> <dest-dir>
#
# <source> is an unpacked bash, which this writes to in one place only: its
# config.sub, to say quark is an operating system. <dest-dir> gets what an
# image carries, laid out like the root: usr/bin/bash.
#
# Nothing in bash is patched. What it needs to be told is said the way it is
# meant to be told:
#
#   - config.site answers the questions configure asks by running a program.
#   - No job control. Stopping a job and handing it the terminal needs
#     process groups, and Quark has none; a shell without it is what every
#     Unix shell is when its input is not a terminal it controls.
#   - Not bash's own malloc, which wants an sbrk that allocates.
#   - Static, as every program here is.
#   - NEED_EXTERN_PC: readline and the termcap beside it each define the
#     three variables termcap is driven by, and that is two definitions too
#     many for a linker that no longer merges them. This is the switch bash
#     has for a system whose termcap library owns them.
#   - The termcap library is bash's own, lib/termcap, reading /etc/termcap —
#     where the console's entry is installed by the console.
. "$(dirname "$0")/../../tools/recipe.sh"

teach support/config.sub
configured || CONFIG_SITE="$HERE/config.site" "$SRC/configure" $HOST \
    CPPFLAGS=-DNEED_EXTERN_PC \
    --without-bash-malloc \
    --disable-nls \
    --disable-job-control \
    --enable-static-link
make -j"${JOBS:-$(nproc)}"

install_programs bash
echo "bash: $(wc -c < "$DEST/usr/bin/bash") bytes in $DEST/usr/bin"
