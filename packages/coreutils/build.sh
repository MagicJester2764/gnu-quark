#!/bin/sh
# Build GNU coreutils for Quark.
#
#     packages/coreutils/build.sh <source> <build-dir> <dest-dir>
#
# <source> is an unpacked coreutils, which this writes to in one place only:
# its config.sub, to say quark is an operating system. <dest-dir> gets the
# programs, laid out like the root: usr/bin/ls and a hundred others.
#
# Nothing in coreutils is patched. `configure` runs the compiler and believes
# what happens, which is the point of having a cross toolchain: nothing here
# says where a Quark program loads or what its C library is called.
#
#   - No translations, ACLs, extended attributes, capabilities or SELinux:
#     Quark has none of them.
#   - No threads. `sort` would use them, and sorts as well without.
#   - Not stdbuf, which works by loading a shared library into another
#     program, and there are none.
#   - musl.mk, for the one file that cannot compile without being told which
#     C library it has. It says why.
. "$(dirname "$0")/../../tools/recipe.sh"

teach build-aux/config.sub
configured || "$SRC/configure" $HOST \
    --disable-nls --disable-acl --disable-xattr --disable-libcap \
    --disable-threads --without-selinux --without-openssl \
    --enable-no-install-program=stdbuf
MAKEFILES="$HERE/musl.mk" make -j"${JOBS:-$(nproc)}"

# The programs, and only the programs: an install also brings manuals, and a
# build tree also holds helpers built for the machine it was built on. What
# `make install` would put in bin is what is wanted, so it is asked. It
# installs over what the last build installed; which programs there are is
# decided by `configure`.
make install-exec DESTDIR="$OBJ/install" >/dev/null
install_staged "$OBJ/install/usr/bin"
