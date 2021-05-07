Custom External Library
=======================

When a D package on posix depends on a non-system library,
specific steps have to be taking to make the D package usable with reggae.

Example for a C library
-----------------------

Assuming a makefile similar to:

```sh
libGOODNAME.a: chelper.o
	ar rcs $@ $?

chelper.o: chelper.c
	$(CC) -Wall -O0 -c $? -o $@
```

The dub.json/sdl file needs to reference this static library/archive in the
following way.

```json
	"preBuildCommands": [ "make -C $PACKAGE_DIR" ],
	"libs": [
		"GOODNAME"
	],

	"lflags-posix": [
		"-L$PACKAGE_DIR/"
	],
```

Please note the two $PACKAGE_DIR references.
This tells dub, and in turn reggae, where to execute the preBuildCommand
and from where to load the created library.
