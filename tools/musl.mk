# Read by make before a package's own Makefile (through MAKEFILES), for every
# package built with tools/recipe.sh.
#
# One file in gnulib, getlocalename_l-unsafe.c, has to reach inside the C
# library for the name of a locale, and so asks which C library it has. It
# asks by asking which system it is on, has never heard of Quark, and stops:
# "#error Please port gnulib getlocalename_l-unsafe.c to your platform!".
#
# The C library here is musl, and the file knows musl's way — an ordinary
# nl_langinfo_l call — but keeps it under the heading of Linux, since that is
# the only place it has met musl. So that one object is compiled being told
# it is on Linux. Nothing else is: every other file that asks gets the truth
# and takes the path that asks nothing of a particular kernel.
#
# gnulib is copied into each package, and each builds the object under a name
# of its own — bare in a directory of tests, or with its library's name in
# front. Both shapes are named: this is read before the Makefile that says
# what an object file is called.
getlocalename_l-unsafe.o: CFLAGS += -D__linux__
%-getlocalename_l-unsafe.o: CFLAGS += -D__linux__
