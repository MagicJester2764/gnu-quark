#!/bin/sh
# Say which C library a program built now would be linked with.
#
#     tools/libc-stamp.sh
#
# Every program here is linked statically, so the C library and the layer
# under it are *in* each one: a library that has changed since a package was
# built is a package that has not been built. Nothing in a package's own
# Makefile knows that — the library is not one of its files — so a recipe
# keeps the line this prints beside what it built, and builds again from
# clean when the line is different.
#
# The layer is the one the compiler's specs name, which is the archive in
# quarkutils' own tree. It was looked for where the plain cross compiler
# would find one — the copy in its sysroot, which is installed by hand and
# by nothing here — so a layer built again and not installed was linked into
# every program built afterwards and into none of the ones this decides
# about.
set -e
CC=${CC:-x86_64-quark-musl-gcc}
specs=$(sed -n 's/.*-specs="\([^"]*\)".*/\1/p' "$(command -v "$CC")")
musl=$(dirname "$specs")
layer=$(grep -o '[^ ]*/liblinux-abi\.a' "$specs" | head -1)
[ -f "$layer" ] || { echo "libc-stamp: no liblinux-abi.a named in $specs" >&2; exit 1; }
cat "$musl/libc.a" "$musl/crt1.o" "$layer" | sha256sum | cut -d' ' -f1
