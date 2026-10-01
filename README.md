# GNU/Quark

The [Quark](https://github.com/MagicJester2764/quark) kernel with GNU on top
of it. It boots to a login prompt on a terminal, the shell is GNU bash, and
`ls`, `cp`, `sort` and the rest are GNU coreutils — the programs GNU ships,
built from the tarballs GNU publishes, with nothing in them changed.

```
login: root
root@quark:~# ls -l --color /
total 18
lrwxrwxrwx 1 root root     7 Oct  1 17:15 bin -> usr/bin
drwxr-xr-x 2 root root     0 Oct  1 17:16 dev
drwxr-xr-x 2 root root  1024 Oct  1 17:13 etc
drwxr-xr-x 2 root root  1024 Oct  1 17:15 home
drwx------ 2 root root 12288 Oct  1 17:15 lost+found
drwx------ 2 root root  1024 Oct  1 15:27 root
lrwxrwxrwx 1 root root     8 Oct  1 17:15 sbin -> usr/sbin
drwxrwxrwt 2 root root  1024 Oct  1 17:15 tmp
drwxr-xr-x 5 root root  1024 Oct  1 15:57 usr
drwxr-xr-x 2 root root  1024 Oct  1 17:15 var
root@quark:~# sort /etc/passwd /etc/passwd | uniq -c
      2 root:x:0:0:root:/root:/usr/bin/bash
root@quark:~# du -sh /usr
21M     /usr
root@quark:~# timeout 1 sleep 5; echo $?
124
```

It is a first cut: a shell and the coreutils, on a kernel that is its own.
The rest of a GNU userland — grep, sed, gawk, findutils, diffutils, tar,
gzip, make — is a package each, and none of them is here yet.

## What is in it

| | |
|---|---|
| The kernel | Quark, and the two modules it loads itself |
| The bootloader | [Bang](https://github.com/MagicJester2764/bang), UEFI |
| What makes a kernel a system | from [quarkutils](https://github.com/MagicJester2764/quarkutils): `init`, the name server, the console, the keyboard and disk drivers, the input server, the file server — and four programs: `getty`, `login`, `ps`, `shutdown` |
| The shell | GNU bash 5.3, also `/bin/sh` |
| The programs | GNU coreutils 9.11: 101 of them |

Quark is a microkernel, so the filesystem, the console and the drivers are
programs, and those come from quarkutils because there is nobody else to get
them from. Everything a person types a command to is GNU's, except `ps` —
what is running is the kernel's to say, and there is no `/proc` to read it
from — and `shutdown`.

Four of quarkutils' programs are taken by name, and nothing else is: its
own shell and its own `ls` are not what this is a distribution of.

## Building it

Five repositories, checked out side by side:

```
quark/             the kernel
quarkutils/        the programs that run on it
bang/              the bootloader
quark-toolchain/   the cross compilers
gnu-quark/         this
```

GNU's programs are built with `x86_64-quark-musl-gcc`, which
[quark-toolchain](https://github.com/MagicJester2764/quark-toolchain) builds
and its README says how; it has to be on `PATH`. The trees beside this one
say what they need to build; this one adds `mtools`, `mkgpt`, `e2fsprogs`
and `qemu-system-x86_64`.

```bash
export PATH="$HOME/.local/bin:$HOME/opt/cross/bin:$PATH"

make          # build everything and assemble gnu-quark.img
make run      # boot it in QEMU
make test     # boot it, type the acceptance test at it, check what it said
```

The first `make` fetches bash and coreutils from ftp.gnu.org into
`~/opt/src` (or `$GNU_QUARK_SRC`) and checks each against the SHA-256 in
`packages/PACKAGES` before unpacking it; the checksums there are of tarballs
whose signatures were checked against the GNU keyring. Nothing is built as root, and
nothing is mounted: the root filesystem is made with `mkfs.ext2 -d`, and its
files are given to user 0 afterwards with `debugfs`.

Log in as `root`. There is no password to ask for.

## How GNU's programs are built

`packages/PACKAGES` names each one, its version, where it comes from and
what its tarball's checksum is. `packages/<name>/build.sh` is its recipe.

Nothing is patched. A recipe may write to one file of an unpacked source,
its `config.sub`, to say that `quark` is the name of an operating system —
upstream's list has not got it. Everything else is said the way the package
means to be told:

- `packages/bash/config.site` answers the questions bash's `configure` asks
  by running a program, which it cannot do when the program is for another
  machine. Each answer is a fact about Quark's C library, with what goes
  wrong if it is left to the default.
- `packages/coreutils/musl.mk` gives one file of gnulib the one macro it
  needs to compile, through `MAKEFILES`. It says which and why.

When a package needed something Quark had not got, Quark grew it. bash and
coreutils between them asked for files that are kernel descriptors, so that
`fork` copies them and `exec` keeps them; signals a program can handle; a
terminal with a line discipline; process ids that are not handed to the next
program the moment one ends; an alarm; and to be told when a child ends.
Those are in the kernel and its C library now, each with a test.

Every program is static. There is no dynamic loader and no shared library,
so a C library that changes means every program built again, and the recipes
see to that themselves.

## The image

A GPT disk: an EFI system partition with Bang, the kernel and what the
kernel is handed at boot, and an ext2 root of 160 MiB with `/usr` as the
whole system — `/bin` and `/sbin` are links into it.

`init` reads `/etc/init.conf`, which says the session is `getty`. `getty`
opens the console's terminal and runs `login` on it; `login` starts the
user's shell as a login shell, at home, with `HOME`, `USER`, `PATH` and
`TERM=linux`. The console is a terminal of the Linux console's kind — its
`/etc/termcap` entry is `linux` — so colours, the arrow keys and a cursor
that moves are what programs expect them to be.

## Testing

`make test` boots the image under QEMU and types `tests/acceptance.keys` at
it, reading the screen back as text: a login, `ls -l --color`, `cp -a`,
`du -sh`, a pipeline, redirection, Ctrl-C, a background job, a timeout,
Ctrl-D and a second login, and `shutdown`. Each command has to have printed
what it should. Then it runs `e2fsck` on the root the test left behind.

In the middle it runs `/usr/share/gnu-quark/selftest`, which is also there
to be run by hand: ninety-odd small things whose answers are known, each
done by bash or by one of the coreutils.

## What does not work

- **No job control.** Stopping a job and handing it the terminal needs
  process groups, and Quark has none. bash is built without it: there is no
  `jobs`, `fg` or `bg`, and Ctrl-Z does nothing. `&` and `wait` work.
  Ctrl-C goes to every program that has the terminal open, and the shell
  survives it the way a shell without job control does on any Unix.
- **No named pipes, and no `chroot`.** `mkfifo` and `mknod` are refused by
  the filesystem. `<(command)` works, through `/dev/fd`.
- **Nobody is logged in**, as far as `who` and `users` can tell: there is no
  record of sessions for them to read.
- **The console is not UTF-8.** It draws code page 437, so the curly quotes
  in a GNU error message are two wrong characters each.
- **A signal handler runs when the program next asks the kernel for
  something**, not in the middle of computing. Almost nothing notices.
- **One user.** `/etc/passwd` has root in it. Users, and a program that
  cannot do everything the shell that started it can, are not here yet.
- **No network programs**, and no network service in the image.

The kernel's own list is in Quark's `MISSING.md`, and the C library's under
"Known gaps" in quarkutils' `CLAUDE.md`.

bash and coreutils are GNU's, under the GNU General Public License, version
3 or later. This repository has the recipes that build them and none of
their source.
