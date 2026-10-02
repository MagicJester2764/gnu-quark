#!/bin/sh
# Lay out the root filesystem as a directory.
#
#     tools/mkroot.sh <stage> <root> <package-dir>...
#
# <stage> is where Quark and quarkutils were installed. <root> must not exist:
# it is made here, so that nothing in it is left over from another build.
# Each <package-dir> is laid out like the root already, by its recipe.
#
# This is where the distribution is decided. A few things are taken from
# quarkutils by name and nothing else is: a root with every one of its
# programs in it would not be a GNU system. What is taken is what a machine
# needs in order to have a session at all, and the things GNU has no program
# for.
#
#   getty, login   a terminal for a session, and somebody to be on it
#   shutdown       turning the machine off is the system's business
#   ps             what is running is the kernel's to say, and there is no /proc
#   setfont        the console draws what it is given a font for, and this
#                  gives it one
#   su, passwd, useradd, userdel, groupadd, gpasswd
#                  who the users are. GNU has `id`, `whoami` and `chown`, and
#                  nothing that makes a user or checks a password: on a Linux
#                  system those are shadow's and util-linux's. These have
#                  Unix's names and Unix's arguments, and write Unix's files.
#
# /usr is the whole system: /bin and /sbin are links into it, and /bin/sh is
# bash.
set -e
if [ $# -lt 2 ]; then
    echo "usage: mkroot.sh <stage> <root> <package-dir>..." >&2
    exit 2
fi
HERE=$(cd "$(dirname "$0")/.." && pwd)
STAGE=$1
ROOT=$2
shift 2

if [ -e "$ROOT" ]; then
    echo "mkroot: $ROOT is already there; it is made fresh each time" >&2
    exit 1
fi
mkdir -p "$ROOT/usr/bin" "$ROOT/usr/sbin" "$ROOT/etc" "$ROOT/root" "$ROOT/home" \
         "$ROOT/tmp" "$ROOT/var" "$ROOT/dev"
ln -s usr/bin "$ROOT/bin"
ln -s usr/sbin "$ROOT/sbin"

# From quarkutils: installed under the names its own FAT root wants, and
# wanted here under the names people type.
take() {
    cp "$STAGE/usr/bin/$1.ELF" "$ROOT/$2"
    chmod 755 "$ROOT/$2"
}
take GETTY    usr/bin/getty
take LOGIN    usr/bin/login
take PS       usr/bin/ps
take SHUTDOWN usr/sbin/shutdown
take SU       usr/bin/su
take PASSWD   usr/bin/passwd
take GPASSWD  usr/bin/gpasswd
take USERADD  usr/sbin/useradd
take USERDEL  usr/sbin/userdel
take GROUPADD usr/sbin/groupadd
# What the console says it is, which is the console's to say, and the program
# that gives it a font, which is the console's too.
cp "$STAGE/etc/termcap" "$ROOT/etc/termcap"
take SETFONT  usr/bin/setfont

# The packages.
for pkg in "$@"; do
    cp -a "$pkg/." "$ROOT/"
done
ln -s bash "$ROOT/usr/bin/sh"

# And what makes it this system: the files under rootfs/.
cp -a "$HERE/rootfs/." "$ROOT/"

chmod 700 "$ROOT/root"
chmod 1777 "$ROOT/tmp"
find "$ROOT/etc" -type f -exec chmod 644 {} +
# The passwords are root's to read and nobody else's.
chmod 600 "$ROOT/etc/shadow"
echo "root: $(find "$ROOT" -type f | wc -l) files, $(du -sh "$ROOT" | cut -f1)"
