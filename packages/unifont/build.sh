#!/bin/sh
# GNU Unifont, as the console's font.
#
#     packages/unifont/build.sh <source> <build-dir> <dest-dir>
#
# Nothing is built. Unifont is published in the format Quark's console reads
# — a code point, a colon and sixteen rows of pixels, one character a line —
# so the file goes into the image as it came, and `setfont` loads it at boot
# (`/etc/init.conf` says so).
#
# It is the whole of what the console can draw past ASCII: every character of
# the basic plane and most of the rest, eight pixels wide or sixteen.
set -e
SRC=${1:?usage: build.sh <source> <build-dir> <dest-dir>}
DEST=${3:?usage: build.sh <source> <build-dir> <dest-dir>}

font=$(ls "$SRC"/unifont_all-*.hex)
mkdir -p "$DEST/usr/share/consolefonts"
cp "$font" "$DEST/usr/share/consolefonts/unifont.hex"
echo "unifont: $(wc -l < "$font") characters in $DEST/usr/share/consolefonts"
