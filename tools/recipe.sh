# What every recipe for an autoconf package does, said once.
#
#     . "$(dirname "$0")/../../tools/recipe.sh"
#
# at the top of packages/<name>/build.sh, which is run as
#
#     build.sh <source> <build-dir> <dest-dir>
#
# It leaves the shell in <build-dir>, with SRC, OBJ and DEST as absolute
# paths, HERE the package's own directory and NAME its name, and gives the
# recipe three words to say the rest with: `teach`, `configured` and
# `install_programs`.
#
# And it starts the build again when what the build was made from has
# changed, in two ways nothing in a package's own Makefile can know about:
#
#   - The C library. Every program is linked statically, so the library and
#     the layer under it are *in* each one, and a library that has changed
#     since a package was built is a package that has not been built. `make
#     clean`, and everything is compiled again.
#   - The recipe. What `configure` was told — its flags, the answers in a
#     config.site — is decided once for a build directory. A recipe that has
#     changed since then is one whose changes are not in what it builds.
#     `make distclean`, and it is configured again.
set -e
SRC=${1:?usage: build.sh <source> <build-dir> <dest-dir>}
OBJ=${2:?usage: build.sh <source> <build-dir> <dest-dir>}
DEST=${3:?usage: build.sh <source> <build-dir> <dest-dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
NAME=$(basename "$HERE")
TOOLS=$(cd "$HERE/../../tools" && pwd)

mkdir -p "$OBJ" "$DEST/usr/bin"
SRC=$(cd "$SRC" && pwd)
OBJ=$(cd "$OBJ" && pwd)
DEST=$(cd "$DEST" && pwd)
cd "$OBJ"

LIBC=$(sh "$TOOLS/libc-stamp.sh")
RECIPE=$(cat "$HERE"/* "$TOOLS/recipe.sh" | sha256sum | cut -d' ' -f1)
if [ -f Makefile ] && [ "$(cat recipe.stamp 2>/dev/null)" != "$RECIPE" ]; then
    echo "$NAME: its recipe has changed; configuring again"
    make distclean >/dev/null 2>&1 || true
    if [ -f Makefile ]; then
        echo "$NAME: could not start again in $OBJ; remove it and build once more" >&2
        exit 1
    fi
elif [ -f Makefile ] && [ "$(cat libc.stamp 2>/dev/null)" != "$LIBC" ]; then
    echo "$NAME: the C library has changed; building again"
    make clean >/dev/null
fi
echo "$LIBC" > libc.stamp
echo "$RECIPE" > recipe.stamp

# teach <config.sub, under the source>: it learns that quark is an operating
# system. The one write a recipe makes to a source tree.
teach() {
    sh "$TOOLS/teach-config-sub.sh" "$SRC/$1"
}

# configured || "$SRC/configure" ...: whether this build directory has been.
configured() {
    [ -f Makefile ]
}

# The flags every package is configured with: built here, to run there, and
# installed under /usr.
HOST="--host=x86_64-quark --prefix=/usr CC=x86_64-quark-musl-gcc"

# install_programs <file>...: into the image's /usr/bin, stripped. An
# unstripped program is three times the size, and the root is not large.
install_programs() {
    for _program in "$@"; do
        cp "$_program" "$DEST/usr/bin/"
        x86_64-quark-strip "$DEST/usr/bin/$(basename "$_program")"
    done
}

# install_staged <dir>: every program `make install` put in a staging
# directory's bin. Says how many.
install_staged() {
    _count=0
    for _program in "$1"/*; do
        [ -f "$_program" ] && [ -x "$_program" ] || continue
        install_programs "$_program"
        _count=$((_count + 1))
    done
    echo "$NAME: $_count programs in $DEST/usr/bin"
}
