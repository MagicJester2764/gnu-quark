#!/bin/sh
# Build GNU tar for Quark.
#
#     packages/tar/build.sh <source> <build-dir> <dest-dir>
#
# Nothing is patched.
#
#   - No translations, ACLs, extended attributes or SELinux: Quark has none
#     of them, and an archive made here records none.
#   - Not rmt, the program at the far end of a tape drive on another
#     machine.
#   - FORCE_UNSAFE_CONFIGURE: configure refuses to run as root because one of
#     its checks is meaningless then. It is not run as root; a recipe may be.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || FORCE_UNSAFE_CONFIGURE=1 "$SRC/configure" $HOST \
    --disable-nls --disable-acl --without-xattrs --without-selinux \
    --without-posix-acls
make -j"${JOBS:-$(nproc)}"

install_programs src/tar
echo "tar: tar in $DEST/usr/bin"
