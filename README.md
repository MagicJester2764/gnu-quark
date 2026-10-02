# GNU/Quark

The [Quark](https://github.com/MagicJester2764/quark) kernel with GNU on top
of it. It boots to a login prompt on a terminal, the shell is GNU bash, and
`ls`, `grep`, `sed`, `awk`, `find`, `tar` and the rest are GNU's — the
programs GNU ships, built from the tarballs GNU publishes, with nothing in
them changed.

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
root@quark:~# awk -F: '{ print $1 " logs in to " $7 }' /etc/passwd
root logs in to /usr/bin/bash
root@quark:~# du -sh /usr
34M     /usr
root@quark:~# sleep 100
^Z
[1]+  Stopped                    sleep 100
root@quark:~# bg; sleep 1; jobs
[1]+ sleep 100 &
[1]+  Running                    sleep 100 &
```

It is what a GNU system has before anybody has installed anything: a shell,
the coreutils, grep, sed, awk, find, diff, tar and gzip, on a kernel that is
its own. What comes after that is a package an image is built with when it
is asked for, and so far there is one: make.

## What is in it

| | |
|---|---|
| The kernel | Quark, and the two modules it loads itself |
| The bootloader | [Bang](https://github.com/MagicJester2764/bang), UEFI |
| What makes a kernel a system | from [quarkutils](https://github.com/MagicJester2764/quarkutils): `init`, the name server, the console, the keyboard and disk drivers, the input server, the file server, the server that says who somebody is — and eleven programs: `getty`, `login`, `ps`, `shutdown`, `setfont`, and `su`, `passwd`, `useradd`, `userdel`, `groupadd`, `gpasswd` |
| The shell | GNU bash 5.3, also `/bin/sh` |
| The programs | GNU coreutils 9.11, 101 of them; grep 3.12; sed 4.10; gawk 5.4.1, also `awk`; findutils 4.11.0, which is `find` and `xargs`; diffutils 3.12; tar 1.35; gzip 1.15 |
| If asked for | GNU make 4.4.1: `make EXTRA="make"` |
| The console's font | GNU Unifont 18.0.01 |

Quark is a microkernel, so the filesystem, the console and the drivers are
programs, and those come from quarkutils because there is nobody else to get
them from. Everything a person types a command to is GNU's, except `ps` —
what is running is the kernel's to say, and there is no `/proc` to read it
from — `shutdown`, `setfont`, which is how the console is given its font,
and the six that make and become users, which GNU has never had: on a Linux
system they are shadow's and util-linux's.

Those eleven of quarkutils' programs are taken by name, and nothing else is:
its own shell and its own `ls` are not what this is a distribution of.

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
make run      # boot it in QEMU, with four processors (SMP=1 for one)
make test     # boot it, type the acceptance test at it, check what it said
SMP=4 make test   # the same, on four processors: it is run on both

make EXTRA="make"    # the same image, with GNU make in it
```

`packages/PACKAGES` says what an image is made of. A package marked `base`
there is in every image. One marked `optional` is in an image built with
its name in `EXTRA`, which is as near as this comes to installing something:
there is no package manager, and what an image has is decided when it is
built.

The first `make` fetches each package from ftp.gnu.org into
`~/opt/src` (or `$GNU_QUARK_SRC`) and checks each against the SHA-256 in
`packages/PACKAGES` before unpacking it; the checksums there are of tarballs
whose signatures were checked against the GNU keyring. Nothing is built as root, and
nothing is mounted: the root filesystem is made with `mkfs.ext2 -d`, and its
files are given to user 0 afterwards with `debugfs`.

Log in as `root`. There is no password to ask for until `passwd` gives it
one, and no other user until `useradd` makes one.

## Users

Unix's, with Unix's commands and Unix's files:

```
root@quark:~# useradd -m ada
root@quark:~# passwd ada
root@quark:~# groupadd staff && gpasswd -a ada staff
root@quark:~# su ada -c id
uid=1000(ada) gid=1000(ada) groups=1000(ada),1001(staff)
```

`/etc/passwd`, `/etc/group`, and `/etc/shadow`, which only root reads and
which holds each password as a SHA-512 `crypt` hash — the same a GNU/Linux
system writes, and the one the C library's own `crypt` checks. A file is its
owner's, a home is made 0700, `/tmp` is sticky, and the file server holds
everybody to all of it. `su` asks for the other user's password, and root
is asked for none.

Root is root: its shell holds every capability the system gives a session,
and a user's holds none. So a user cannot turn the machine off, end
somebody else's program or read a disk — not because a program checked a
user id, but because the shell that started it had nothing of the kind to
hand on.

What somebody types is theirs as well. Each login is a session, the
terminal is that session's, and a program left running by somebody who then
logged out is refused it: the descriptor it kept answers `EIO`, and
`/dev/pts/0` does not open.

One thing is not Unix's, and cannot be seen from the prompt: **nothing is
setuid**. `su` and `passwd` are ordinary programs that hold nothing; a
program on Quark is loaded by whoever starts it, so there is no file whose
mode could make it run as somebody else. They ask a server, `auth`, which is
the only thing on the system that may say who a process is and the only
reader of `/etc/shadow`. It checks the password and makes the *new* shell
the user — before that shell has run a single instruction.

## How GNU's programs are built

`packages/PACKAGES` names each one, its version, where it comes from and
what its tarball's checksum is. `packages/<name>/build.sh` is its recipe.

Nothing is patched. A recipe may write to one file of an unpacked source,
its `config.sub`, to say that `quark` is the name of an operating system —
upstream's list has not got it. Everything else is said the way the package
means to be told:

- `tools/config.site` answers the questions a `configure` asks by running
  a program, which it cannot do when the program is for another machine.
  Each answer is a fact about Quark's C library, with what goes wrong if it
  is left to the default. `packages/bash/config.site` has the ones only
  bash asks.
- `tools/musl.mk` gives one file of gnulib, which most of these packages
  carry a copy of, the one macro it needs to compile, through `MAKEFILES`.
  It says which and why.
- A recipe passes `configure` the flags the package has for what Quark has
  not got — no translations, no ACLs, no shared libraries to load — and for
  make, which is written in the C of before 2023, the flag that says so.

When a package needed something Quark had not got, Quark grew it. Between
them these programs asked for files that are kernel descriptors, so that
`fork` copies them and `exec` keeps them; signals a program can handle; a
terminal with a line discipline; process ids that are not handed to the next
program the moment one ends; an alarm, and to be told when a child ends; a
console that draws UTF-8; named pipes; process groups, sessions and jobs
that stop; and `posix_spawn`, which is how make starts everything it runs.
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

The shell has job control. `getty` begins a session and takes the console
as its terminal, and bash puts each pipeline in a process group of its own:
Ctrl-C and Ctrl-Z are for whatever is in front, `jobs`, `fg` and `bg` say
and change which that is, and a job that reads the terminal from the
background is stopped until it is brought forward.

It is UTF-8. Before the session, `init` runs `setfont`, which gives the
console GNU Unifont — the console itself was built with ASCII and nothing
else — and `/etc/profile` sets `LANG=C.UTF-8`, so that `ls` prints a name
with an accent in it as the name and `wc -m` counts its characters.

## Testing

`make test` boots the image under QEMU and types `tests/acceptance.keys` at
it, reading the screen back as text: a login, `ls -l --color`, `cp -a`,
`du -sh`, a pipeline, redirection, Ctrl-C, a background job, a timeout; a
user made, given a password, logged in as — not with a wrong one — refused
root's files, another user's and the machine's power, and become root with
`su`; a program left behind at logout, refused the terminal when root logs
in; and `shutdown`. Each command has to have printed what it should. Then it runs `e2fsck` on the root the test left behind.

In the middle it runs `/usr/share/gnu-quark/selftest`, which is also there
to be run by hand: a hundred and fifty small things whose answers are known,
each done by bash or by one of the programs in the image — and by make, in
an image that has it.

## What does not work

- **`stty tostop` does nothing.** There is job control — Ctrl-Z, `jobs`,
  `fg`, `bg`, and a job that reads the terminal from the background is
  stopped until it is brought forward — but one that *writes* from the
  background is never stopped for it.
- **No `chroot`**, and `mknod` makes a named pipe and nothing else: there
  are no device files to make. A named pipe cannot be opened for reading
  and writing at once (`exec 3<>pipe`).
- **Nobody is logged in**, as far as `who` and `users` can tell: there is no
  record of sessions for them to read.
- **A combining character is not drawn.** The console is UTF-8 and draws
  what GNU Unifont has, in one cell or two; a mark that sits on the
  character before it has no cell of its own and is dropped. The keyboard
  types ASCII: there is one layout, and it is US.
- **A signal handler runs when the program next asks the kernel for
  something**, not in the middle of computing. Almost nothing notices.
- **No `sudo`**, and nothing like it: a user becomes root with root's
  password (`su`) or not at all. Nor `usermod`, `groupdel`, `chsh`, `newgrp`
  or password ageing: an account is changed by removing it and making it
  again, or by editing the files, which are Unix's.
- **A program root runs can do anything root's shell can.** The kernel
  copies capabilities at a fork and keeps them across an exec, and nothing
  narrows them for one command.
- **`grep -P` is not there**: Perl's regular expressions are a library,
  PCRE2, that nobody has made a package of. Nor are `locate` and `updatedb`,
  which want something to run them each night.
- **No network programs**, and no network service in the image.

The kernel's own list is in Quark's `MISSING.md`, and the C library's under
"Known gaps" in quarkutils' `CLAUDE.md`.

bash and coreutils are GNU's, under the GNU General Public License, version
3 or later. This repository has the recipes that build them and none of
their source.
