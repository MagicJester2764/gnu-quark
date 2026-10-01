# Working on GNU/Quark

GNU/Quark is a distribution: the Quark kernel, the least of quarkutils that
makes a kernel a system, and GNU's programs on top. It is one of the
repositories that must be checked out as siblings:

```
repos/
  quark/            the kernel
  quarkutils/       everything Quark's own that runs on it
  bang/             the UEFI bootloader
  quark-toolchain/  the cross compilers
  gnu-quark/        this repo — recipes for GNU's programs, and the image
```

The dependency runs one way: this tree reaches down to `quark`, `quarkutils`
and `bang`, asks each to install, and none of them knows it exists. From
`quark-toolchain` it needs what that installs — the compilers, on `PATH` —
and nothing in its checkout.

Rules about the kernel are in `../quark/CLAUDE.md`, and rules about programs,
the C library and the console in `../quarkutils/CLAUDE.md`. Read those before
changing what a program here *does*. This file is about building other
people's software for Quark, and making an image of it.

## Before anything else

```bash
export PATH="$HOME/.local/bin:$HOME/opt/cross/bin:$PATH"
```

`x86_64-quark-musl-gcc` and `x86_64-quark-strip` are the cross toolchain,
which `../quark-toolchain` installs under `~/opt/cross`; `mkgpt` is wherever
it was put, here `~/.local/bin`. Without the first two nothing configures.

## Build and run

```bash
make          # stage the three trees, build the packages, assemble the image
make run      # boot gnu-quark.img in QEMU
make test     # boot it and type tests/acceptance.keys at it
make check    # e2fsck the root filesystem in the image
```

Everything a build makes is under `build/`, and the image is
`gnu-quark.img`; both are named from where the Makefile is, so `make clean`
removes those two whatever directory it was started in.

`make` runs `make install` in `../quark` and then `../quarkutils`, in that
order and with `REQUIRE_ABI=1`: the userland checks its copy of the system
call numbers against the header the kernel has just installed, and here that
check is not allowed to be skipped.

## The rule: nothing is patched

A package is built from the tarball its project publishes, checked against
the SHA-256 in `packages/PACKAGES`, and nothing in it is changed. When a
program needs something Quark has not got, **Quark grows it** — in the
kernel, or in the C library's Linux layer (`../quarkutils/linux-abi`) — and
gets a test there. A recipe that works around a missing piece is how the
piece stays missing for the next program.

That is what this repository has been for. Getting bash and coreutils to run
unmodified put into Quark: files as kernel descriptors (so `fork` copies
them and `exec` keeps them, and `> file` is something a shell can do to a
child); a console that is a terminal, with a line discipline; signals; process
ids that are not reused at once; `getresuid`; an alarm and SIGCHLD; a name for
a terminal. Each was found by a GNU program doing something ordinary.

What a recipe *may* do:

- **Teach `config.sub` the word `quark`** (`tools/teach-config-sub.sh`), in
  the unpacked copy. It is the one write to a source tree, it is the same
  one line for every package, and it is there because upstream's list of
  operating systems is upstream's.
- **Answer what `configure` asks by running a program.** It cannot run a
  Quark program on the build machine, so it takes a default, and the default
  is for a system it knows nothing about. `packages/bash/config.site` has
  the ones that are wrong, each with what breaks if it is left: bash thought
  the exit status was in the low byte of a wait status, and every command
  had succeeded.
- **Pass a flag the package has for the purpose** (`--disable-job-control`,
  `-DNEED_EXTERN_PC`), or define a macro for a file that asks for one
  (`packages/coreutils/musl.mk`, through `MAKEFILES`, for one object).

## Adding a package

1. A line in `packages/PACKAGES`: name, version, SHA-256 of the tarball,
   URL. The checksum is what the build trusts from then on, so it is taken
   from a tarball whose signature has been checked — `gpgv --keyring
   gnu-keyring.gpg <tarball>.sig <tarball>`, with the keyring from
   ftp.gnu.org — and the file says who signed it.
2. `packages/<name>/build.sh <source> <build-dir> <dest-dir>`. It configures
   out of tree in `<build-dir>`, and leaves in `<dest-dir>` what the image
   carries, laid out like the root (`usr/bin/...`). An autoconf package's
   recipe begins by sourcing `tools/recipe.sh`, which leaves it three things
   to say: where `config.sub` is (`teach`), what `configure` is told
   (`configured || "$SRC/configure" $HOST ...`), and which programs go in the
   image (`install_programs`, `install_staged`).
3. The name in `PACKAGES :=` in the Makefile.
4. Something in `rootfs/usr/share/gnu-quark/selftest`, and in
   `tests/acceptance.keys` if a person would type it.

`tools/recipe.sh` is what every recipe has in common, and two of the things
it does are there because nothing in a package's own Makefile can know them:

- **It starts again when the C library has changed.** Every program is
  static, so the library is inside it. `tools/libc-stamp.sh` is a checksum
  of the library, its startup file and the Linux layer; the build directory
  keeps the one it was built against and is cleaned when it differs. Without
  it a fix to the layer is in the image's `ls` only if `ls` happened to be
  rebuilt.
- **It configures again when the recipe has changed.** What `configure` was
  told is decided once for a build directory, so an answer added to a
  `config.site`, or a flag taken out, did nothing until the directory was
  thrown away: bash went on believing there were no named pipes after the
  line that said so was changed. The checksum is of the package's directory
  and of `recipe.sh` itself.

And it strips what it installs: an unstripped coreutils is three times the
size, and the root is 160 MiB.

`tools/fetch.sh` unpacks a fresh copy under `build/src` when there is none.
A recipe never writes anywhere else in it than `config.sub`.

## What goes in the root

`tools/mkroot.sh` is where the distribution is decided. It takes five
programs from quarkutils **by name** — `getty`, `login`, `ps`, `shutdown`,
and `setfont`, which is the console's own tool — and the console's
`termcap`. A root with all of quarkutils' programs in it
is not a GNU system. Before adding a fifth, ask whether GNU has the program:
if it does, it is a package.

`rootfs/` is copied over the top, and is the whole of what makes the image
this system rather than a pile of programs: `passwd`, `group`, `init.conf`
(the session is `getty`), `profile` and `bashrc`, `os-release`, `mtab`.

- `/usr` is the system; `/bin` and `/sbin` are links into it, and `/bin/sh`
  is bash.
- `login` starts any shell that is not Quark's own the way a Unix `login`
  does: as `-bash`, at home, with `HOME`, `USER`, `LOGNAME`, `SHELL`, `PATH`
  and `TERM`. That dash is the only way a shell is told to read
  `/etc/profile`.
- `TERM=linux`, and bash's line editor reads `/etc/termcap` — there is no
  terminfo and no curses. The entry is the console's, installed by
  quarkutils; a key or a sequence the console gains is added there.
- `/etc/mtab` is a file, written here: one line, the root, named by its
  label. `df` reads it. There is no `/proc` for it to be a link into.
- The console is UTF-8 and was built with ASCII. `init.conf` has a `run`
  line that loads GNU Unifont with `setfont` before the session, and
  `/etc/profile` sets `LANG=C.UTF-8`. The font is a package like any other
  (`packages/unifont`), installed as GNU publishes it.

`tools/mkimage.sh` makes the disk without being root and without mounting
anything: `mkfs.ext2 -d` populates the filesystem from the directory, a
`debugfs` pass gives every file to user 0 (they were the builder's), and
`e2fsck` has to pass before the image is put together. The root is ext2
because Quark's ext4 cannot yet shorten a file whose extents have outgrown
the inode, and `> file` does exactly that.

`boot.img` on the EFI partition holds the services `init` starts before
there is a root to read: the name server, the framebuffer, the console, the
keyboard, the disk, input and the file server. Not the network stack: there
is nothing in the root to use it.

## Testing

A change is verified by booting the image. `tools/boot-test.sh <keys>`
drives QEMU from a script (`tools/drive-qemu.py` lists the operations), and
reads the console back as text, because a program's output goes to the
screen and serial carries only the kernel's own faults. It reads it by
matching each cell against the font the image loads, so a character Unifont
has can be tested for like any other:

- `expect <seconds> <regex>` waits for the last line of the screen to match:
  a prompt.
- `saw <regex>` says some line shown so far matches: what a command printed.
- `off <seconds>` waits for the machine to turn itself off.
- `transcript <path>` writes everything the console showed.

`make test` runs `tests/acceptance.keys` on a *copy* of the image and then
`e2fsck` on what the test left. A run that typed every command and left a
broken filesystem has not passed.

`/usr/share/gnu-quark/selftest` is the cheap half: a bash script, in the
image, of small commands with known answers. It runs on any GNU system — try
a new check on the host first, where a wrong expectation is the test's fault
and takes a second to find.

When something hangs or prints the wrong thing, the fault is almost never in
the package. Reduce it to a few lines of C, built with
`x86_64-quark-musl-gcc`, and it becomes a test in `../quarkutils/ctests`
and a fix in the layer or the kernel. The
out-of-order pipelines after a background job were bash being told the same
pid twice; `timeout` waiting for ever was a SIGCHLD nobody raised.

## Known gaps

- **No job control**, and bash is built without it (`--disable-job-control`):
  no `jobs`, `fg`, `bg`, no Ctrl-Z, and `PIPESTATUS` holds one status.
  Process groups are the kernel's to grow first.
- **No named pipes**; bash is told so (`bash_cv_sys_named_pipes=missing`)
  and makes `<(...)` out of `/dev/fd` instead. `mkfifo`, `mknod` and
  `chroot` are installed and refused.
- **No utmp**: `who`, `users` and `pinky` print nothing.
- **No combining characters** on the console, and one keyboard layout.
- **A program run by the shell holds what the shell holds.** The kernel
  copies capabilities at a fork and keeps them across an exec, and nothing
  narrows them. With one user that is root it changes nothing yet.
- `stdbuf` is not built: it works by loading a library into another program.
- Only `x86_64-quark-musl-gcc`'s static C programs: no C++ package has been
  tried here, and nothing links a shared library.
