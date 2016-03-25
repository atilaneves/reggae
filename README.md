Reggae
=======
[![Build Status](https://travis-ci.org/atilaneves/reggae.png?branch=master)](https://travis-ci.org/atilaneves/reggae)

A (meta) build system written in [the D programming language](http://dlang.org). This
is alpha software, only tested on Linux and likely to have breaking
changes made.

More information is available in the [documentation](doc/index.md).

Features
--------
* Write readable build descriptions in [D](http://dlang.org/),
[Python](https://github.com/atilaneves/reggae-python),
[Ruby](https://github.com/atilaneves/reggae-ruby),
[JavaScript](https://github.com/atilaneves/reggae-js)
or [Lua](https://github.com/atilaneves/reggae-lua)
* Low-level DAG build descriptions + high-level convenience rules to build C, C++ and D
* Automatic header/module dependency detection for C, C++ and D
* Automatically runs itself if the build description changes
* Out-of-tree builds
* Backends for GNU make, ninja, tup and a custom binary executable.
* User-defined variables like CMake in order to choose features before compile-time
* For D projects, rules for using [dub](http://code.dlang.org/about) build targets
in your own build decription - use dub with ninja, add to the dub description, ...

Not all features are available on all backends. Executable D code commands (as opposed to shell commands)
are only supported by the binary backend, and due to tup's nature dub support and a few other features
are not available. When using the tup backend, simple is better.

The recommended backends are ninja and binary.

Usage
-----

Reggae is actually a meta build system and works similarly to
[CMake](http://www.cmake.org/) or
[Premake](http://premake.github.io/). CMake requires writing
configuration files in their own proprietary language. The
configuration files for Reggae are written in [D](http://dlang.org),
[Python](https://github.com/atilaneves/reggae-python), [Ruby](https://github.com/atilaneves/reggae-ruby),
[JavaScript](https://github.com/atilaneves/reggae-js) or [Lua](https://github.com/atilaneves/reggae-lua)

From a build directory (usually not the same as the source one), type
`reggae -b <ninja|make|tup|binary> </path/to/project>`. This will create
the actual build system depending on the backend chosen, for
[Ninja](http://martine.github.io/ninja/),
[GNU Make](https://www.gnu.org/software/make/),
[tup](http://gittup.org/tup/), or a runnable
executable, respectively.  The project path passed must either:

1. Contain a a file named `reggaefile.{d,py,rb,js,lua}` with the build configuration
2. Be a [dub](http://code.dlang.org/about) project

Dub projects with no reggaefile will have one generated for them in the build directory.

How to write build configurations
---------------------------------
The best examples can be found in the [features directory](features).
The examples below are mostly in D, but the only real difference to writing build
descriptions in the other supported languages is the syntax. Please consult the
[documentation](doc/index.md).

Each `reggaefile.d` must contain one and only one function with a return value of type
[Build](payload/reggae/build.d). This function can be generated automatically with the
[build template mixin](payload/reggae/build.d). The `Build` struct is a container for
`Target` structs, which themselves may depend on other targets.

Arbitrary build rules can be used. Here is an example of a simple D build `reggaefile.d`:

```d
import reggae;
enum mainObj  = Target("main.o",  "gcc -I$project/src -c $in -o $out", Target("src/main.c"));
enum mathsObj = Target("maths.o", "gcc -c $in -o $out", Target("src/maths.c"));
enum app = Target("myapp", "gcc -o $out $in", [mainObj, mathsObj]);
mixin build!(app);
```

Or in Python:

```python
from reggae import *
main_obj = Target("main.o",  "gcc -I$project/src -c $in -o $out", Target("src/main.c"))
maths_obj = Target("maths.o", "gcc -c $in -o $out", Target("src/maths.c"))
app = Target("myapp", "gcc -o $out $in", [mainObj, mathsObj])
bld = Build(app)
```

That was just an example to illustrate the low-level primitives. There
are high-level [convenience rules](doc/rules.md) for common tasks such
as compiling and linking. The low-level primitives are there for
flexibility. For instance, to build D apps with no external
dependencies, this will suffice and is similar to using rdmd:

```d
import reggae;
alias app = scriptlike!(App(SourceFileName("src/main.d"), BinaryFileName("myapp")),
                        Flags("-g -debug"),
                        ImportPaths(["/path/to/imports"])
                        );
mixin build!(app);
```

There are also other functions and pre-built rules for C and C++ objects. There is no
HTML documentation yet but the [package file](payload/reggae/package.d) contains the
relevant DDoc with details. Other subpackages might contain DDoc of their own. There is
also [detailed documentation](doc/index.md) in markdown format.

For C and C++, the main high-level rules to use are `targetsFromSourceFiles` and
`link`, but of course they can also be hand-assembled from `Target` structs. Here is an
example C++ build written in D:

```d
import reggae;
alias objs = objectFiles!(Sources!(["."]), // a list of directories
                          Flags("-g -O0"),
                          IncludePaths(["inc1", "inc2"]));
alias app = link!(ExeName("app"), objs);
mixin build!(app);
```

Or in Python:

```python
from reggae import *
objs = object_files(src_dirs=".", flags="-g -O0", includes=["inc1", "inc2"])
app = link(exe_name="app", dependencies=objs)
b = Build(app)
```

In the D version, `Sources` can also be used like so:

```d
Sources!(Dirs([/*directories to look for sources*/],
         Files([/*list of extra files to add*/]),
         Filter!(a => a != "foo.d"))); //get rid of unwanted files
```

`objectFiles` isn't specific to C++, it'll create object file targets
for all supported languages (currently C, C++ and D).


Dub integration
---------------

The easiest dub integration is to run reggae with a directory containing a dub project as
parameter. That will create a build system that would do the same as "dub build" but probably
faster. In all likelihood a user needing reggae will need more than that, and reggae provides
an API to use dub build information in a `reggaefile.d` build description file. A simple
example for building production and unittest binaries concurrently is this:

```d
import reggae;
alias main = dubDefaultTarget!("-g -debug");
alias ut = dubConfigurationTarget!(ExeName("ut"), Configuration("unittest"));
mixin build!(main, ut);
```

This is equivalent to the automatically generated reggaefile if none is present.

Depending on whether or not the dub project in questions uses configurations, reggae's dub
support might not work before [this pull request](https://github.com/D-Programming-Language/dub/pull/577)
is merged.


Scripting language limitations
------------------------------
Build written in one of the scripting languages currently:

* Can only detect changes to the main build description file (e.g. `reggaefile.py`),
but not any other files that were imported/required
* Cannot use the binary backend
* Do not have access to the dub high-level rules

These limitations are solely due to the features not having been implemented yet.


Building Reggae
---------------

Reggae can build itself. To bootstrap, either use dub or the [included bootstrap script](bootstrap.sh).
Call it without arguments for `make` or with one to choose another backend, such as `ninja`. This
will create a `reggae` binary in a `bin` directory then call itself to generate the "real" build
system with the requested backend. The reggae-enabled build includes a unit test binary.

Goals
-----
1. No external dependencies, including on dub
2. Minimal boilerplate for writing build configurations
3. Flexibility for low-level tasks with built-in common tasks
