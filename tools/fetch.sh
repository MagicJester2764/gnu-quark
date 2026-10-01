#!/bin/sh
# Fetch a package's source, check it, and unpack a copy to build from.
#
#     tools/fetch.sh <name> <build-dir>
#
# The tarball is kept in $GNU_QUARK_SRC (default ~/opt/src) and is fetched only
# if it is not there. Either way it is checked against the SHA-256 in
# packages/PACKAGES before anything is unpacked from it. The copy to build
# from goes in <build-dir>/src/<name>-<version>, fresh if it is not there
# already: a build never writes into the tree it was unpacked from anywhere
# else, so what is in <build-dir> is the tarball's contents and whatever the
# recipe did to them, and nothing left by an earlier build of something else.
#
# Prints the directory.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
NAME=${1:?usage: fetch.sh <name> <build-dir>}
BUILD=${2:?usage: fetch.sh <name> <build-dir>}
SRC=${GNU_QUARK_SRC:-$HOME/opt/src}

line=$(grep -v '^#' "$HERE/packages/PACKAGES" | awk -v n="$NAME" '$1 == n')
if [ -z "$line" ]; then
    echo "fetch: no package called $NAME in packages/PACKAGES" >&2
    exit 1
fi
set -- $line
version=$2
sum=$3
url=$4
tarball=$SRC/$(basename "$url")
dir=$BUILD/src/$NAME-$version

mkdir -p "$SRC" "$BUILD/src"
if [ ! -f "$tarball" ]; then
    echo "==> fetching $(basename "$url")" >&2
    curl -fsSL -o "$tarball.part" "$url"
    mv "$tarball.part" "$tarball"
fi
if ! echo "$sum  $tarball" | sha256sum -c --status -; then
    echo "fetch: $tarball is not the file this was tested with" >&2
    echo "       (sha256 should be $sum)" >&2
    exit 1
fi
if [ ! -d "$dir" ]; then
    echo "==> unpacking $NAME $version" >&2
    tar -C "$BUILD/src" -xf "$tarball"
    # A tarball unpacks as name-version, by convention and in both of these.
    [ -d "$dir" ] || { echo "fetch: $tarball did not unpack as $dir" >&2; exit 1; }
fi
echo "$dir"
