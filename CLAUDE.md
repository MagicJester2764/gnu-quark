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
make run      # boot gnu-quark.img in QEMU: four processors, SMP=1 for one
make test     # boot it and type tests/acceptance.keys at it: one processor,
              # SMP=4 in the environment for four, and a change passes on both
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
a terminal; a console that draws UTF-8; named pipes; process groups, sessions
and jobs that stop. Each was found by a GNU program doing something
ordinary.

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
- **Pass a flag the package has for the purpose** (`--without-bash-malloc`,
  `-DNEED_EXTERN_PC`), or define a macro for a file that asks for one
  (`packages/coreutils/musl.mk`, through `MAKEFILES`, for one object).

## Adding a package

1. A line in `packages/PACKAGES`: name, set, version, SHA-256 of the
   tarball, URL. The checksum is what the build trusts from then on, so it is
   taken from a tarball whose signature has been checked — `gpgv --keyring
   gnu-keyring.gpg <tarball>.sig <tarball>`, with the keyring from
   ftp.gnu.org — and the file says who signed it. The set is `base` for what
   every image has and `optional` for what one has when it is built with the
   name in `EXTRA`: the Makefile reads the list from this file and from
   nowhere else. `base` is what a GNU system has before anybody installs
   anything — what Debian marks required, what Arch calls `base` — and a
   compiler's tools are not that.
2. `packages/<name>/build.sh <source> <build-dir> <dest-dir>`. It configures
   out of tree in `<build-dir>`, and leaves in `<dest-dir>` what the image
   carries, laid out like the root (`usr/bin/...`). An autoconf package's
   recipe begins by sourcing `tools/recipe.sh`, which leaves it three things
   to say: where `config.sub` is (`teach`), what `configure` is told
   (`configured || "$SRC/configure" $HOST ...`), and which programs go in the
   image (`install_programs`, `install_staged`).
3. Something in `rootfs/usr/share/gnu-quark/selftest`, and in
   `tests/acceptance.keys` if a person would type it. An optional package's
   checks are under `if command -v <program>`, and are run by building with
   it: `make test EXTRA="<name>"`.

`tools/recipe.sh` is what every recipe has in common, and two of the things
it does are there because nothing in a package's own Makefile can know them:

- **It starts again when the C library has changed.** Every program is
  static, so the library is inside it. `tools/libc-stamp.sh` is a checksum
  of the library, its startup file and the Linux layer; the build directory
  keeps the one it was built against and is cleaned when it differs. Without
  it a fix to the layer is in the image's `ls` only if `ls` happened to be
  rebuilt. The layer it reads is the one the compiler's specs name — the
  archive in quarkutils' own tree, which is what is linked — and not the
  copy in the cross compiler's sysroot, which nothing here installs: it read
  that one, and a layer built again and not installed was in every program
  built afterwards and in none of the ones this decides about.
- **It configures again when the recipe has changed.** What `configure` was
  told is decided once for a build directory, so an answer added to a
  `config.site`, or a flag taken out, did nothing until the directory was
  thrown away: bash went on believing there were no named pipes after the
  line that said so was changed. The checksum is of the package's directory,
  of `recipe.sh` itself, and of the two files below.

Two more files are every recipe's, and are where to look first when a new
package does not configure or compile:

- **`tools/config.site`** answers what `configure` would find out by running
  a program. gnulib has a guess for most of those when it is cross-compiling
  and uses it; where it has one and stops anyway, or the guess is wrong for
  musl, the answer goes here with the reason. An answer only one package
  asks for goes in `packages/<name>/config.site`, which is read after it.
  A guess that is wrong does not fail, it compiles: gnulib guessed that an
  unknown system's `getgroups` does not work and built in one of its own
  that only fails, so `id` showed a user in one group while `cat` read a
  file only the user's second group could. When a GNU program disagrees
  with the kernel about a fact, look in the package's `config.h` for what
  configure decided before looking anywhere else.
- **`tools/musl.mk`** is read by every `make` a recipe runs. gnulib is
  copied into each package, and one file of it has to be told which C
  library it is compiled against.

A package written before C23 may say so by not compiling: `getenv ()`
declared with no prototype is a function of no arguments now. The fix is the
flag that names the language (`CFLAGS=-std=gnu17`, as make's recipe has),
not a change to the source.

And it strips what it installs: an unstripped coreutils is three times the
size, and the root is 160 MiB.

`tools/fetch.sh` unpacks a fresh copy under `build/src` when there is none.
A recipe never writes anywhere else in it than `config.sub`.

## What goes in the root

`tools/mkroot.sh` is where the distribution is decided. It takes eleven
programs from quarkutils **by name** — `getty`, `login`, `ps`, `shutdown`,
`setfont`, which is the console's own tool, and the six that make and become
users (`su`, `passwd`, `useradd`, `userdel`, `groupadd`, `gpasswd`) — and
the console's `termcap`. A root with all of quarkutils' programs in it
is not a GNU system. Before adding a twelfth, ask whether GNU has the
program: if it does, it is a package. (GNU has `id`, `whoami` and `chown`.
It has nothing that makes a user or checks a password.)

`rootfs/` is copied over the top, and is the whole of what makes the image
this system rather than a pile of programs: `passwd`, `group`, `shadow`,
`init.conf` (the session is `getty`), `profile` and `bashrc`, `os-release`,
`mtab`.

- **Users are Unix's here.** `/etc/passwd`, `/etc/group` and `/etc/shadow`
  in the forms every C program reads; no `/etc/rights`, so the rule
  quarkutils' `auth` applies is the plain one: user 0's sessions hold
  everything and nobody else's hold anything. `mkroot.sh` makes every file
  in `/etc` 0644 and then `shadow` 0600 — in that order, or the passwords
  are everybody's to read.
- **Each login is a session**, and the terminal is that session's: `login`
  begins one and ends with it, `getty` starts the next. The acceptance
  leaves a program behind at a logout and has it try the terminal once root
  has logged in. A shell's job control is inside the session, as before.
- **`auth` is a boot service**, in `tools/mkimage.sh`'s list. `login`, `su`
  and `passwd` hold nothing and ask it; without it nobody logs in at all,
  which is how it was found to be missing from the list.

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
keyboard, the disk, input, the file server and `auth`. Not the network stack: there
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

- **A `saw` is satisfied by anything the console has ever shown.** A check
  that a second command printed what a first already had is no check: make
  the second say something of its own (`echo "its home is left: $(...)"`).
- **A password is typed at `New password:` and `Again:`**, which are prompts
  like any other to `expect`; nothing typed there is shown, so nothing of
  it can be `saw`n.

When something hangs or prints the wrong thing, the fault is almost never in
the package. Reduce it to a few lines of C, built with
`x86_64-quark-musl-gcc`, and it becomes a test in `../quarkutils/ctests`
and a fix in the layer or the kernel. The
out-of-order pipelines after a background job were bash being told the same
pid twice; `timeout` waiting for ever was a SIGCHLD nobody raised.

## Known gaps

- **`stty tostop` does nothing**: a job is stopped for reading the terminal
  from the background and never for writing to it.
- **`chroot` is installed and refused**, and `mknod` makes a named pipe
  and nothing else. A named pipe is not opened `O_RDWR`, so `exec 3<>pipe`
  fails; `<(...)` is made of `/dev/fd`, which bash prefers when it has both.
- **No utmp**: `who`, `users` and `pinky` print nothing.
- **No combining characters** on the console, and one keyboard layout.
- **A program run by the shell holds what the shell holds.** The kernel
  copies capabilities at a fork and keeps them across an exec, and nothing
  narrows them. A user's shell holds none, so there is nothing to narrow;
  root's holds all of them, and so does everything root runs.
- **No `sudo`, `usermod`, `groupdel`, `chsh` or `newgrp`.** `su` is the one
  way to be somebody else.
- `stdbuf` is not built: it works by loading a library into another program.
  For the same reason gawk has no extensions and make no `load`.
- `grep -P` wants PCRE2, and `locate` something to run `updatedb`.
- Only `x86_64-quark-musl-gcc`'s static C programs: no C++ package has been
  tried here, and nothing links a shared library.
