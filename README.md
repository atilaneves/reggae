Reggae
=======
[![Build Status](https://travis-ci.org/atilaneves/reggae.png?branch=master)](https://travis-ci.org/atilaneves/reggae)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/atilaneves/reggae?branch=master&svg=true)](https://ci.appveyor.com/project/atilaneves/reggae)
[![Coverage](https://codecov.io/gh/atilaneves/reggae/branch/master/graph/badge.svg)](https://codecov.io/gh/atilaneves/reggae)

A (meta) build system with multiple front (D, Python, Ruby,
Javascript, Lua) and backends (make, ninja, tup, custom).  This is
alpha software, only tested on Linux and likely to have breaking
changes made.

Detailed API documentation can be found [here](doc/README.md).

Why?
----

Do we really need another build system? Yes.

On the frontend side, take CMake. CMake is pretty awesome. CMake's
language, on the other hand, is awful.  Many other build systems use
their own proprietary languages that you have to learn to be able to
use them. I think that using a good tried-and-true general purpose
programming language is better, with an API that is declarative as
much as possible.

On the backend, it irks me that wanting to use tup means tying myself
to it. Wouldn't it be nice to describe the build in my language of
choice and be able to choose between tup and ninja as an afterthought?

I also wanted something that makes it easy to integrate different
languages together.  Mixing D and C/C++ is usually a bit painful, for
instance. In the future it may include support for other statically
compiled languages. PRs welcome!

reggae is really a flexible DAG describing API that happens to be good
at building software.

Features
--------
* Multiple frontends: write readable and concise build descriptions in
[D](http://dlang.org/),
[Python](https://github.com/atilaneves/reggae-python),
[Ruby](https://github.com/atilaneves/reggae-ruby),
[JavaScript](https://github.com/atilaneves/reggae-js)
or [Lua](https://github.com/atilaneves/reggae-lua). Your choice!
* Multiple backends: generates build systems for make, ninja, tup, and a custom binary backend
* Like autotools, no dependency on reggae itself for people who just want to build your software.
The `--export` option generates a build system that works in the root of your project without
having to install reggae on the target system
* Flexible low-level DAG description DSL in each frontend to do anything
* High-level DSL rules for common build system tasks for C, C++ and D projects
* Automatic header/module dependency detection for C, C++ and D
* Automatically runs itself if the build description changes
* Out-of-tree builds - no need to create binaries in the source tree
* User-defined variables like CMake in order to choose features before compile-time
* [dub](http://code.dlang.org/about) integration for D projects

Not all features are available for all backends. Executable D code
commands (as opposed to shell commands) are only supported by the
binary backend, and due to tup's nature dub support and a few other
features are not available. When using the tup backend, simple is
better.

The recommended backend is ninja. If writing build descriptions in D,
the binary backend is also recommended.

Usage
-----

Pick a language to write your description in and place a file called
`reggaefile.{d,py,rb,js,lua}` at the root of your project.

In one of the scripting languages, a global variable with the type
`reggae.Build` must exist with any name. Also, the relevant
language-specific package can be installed using pip, gem, npm or
luarocks to install the reggae package (reggae-js for npm). This is
not required; the reggae binary includes the API for all scripting
languages.

In D, a function with return type `Build` must exist with any name.
Normally this function isn't written by hand but by using the
[build template mixin](payload/reggae/build.d).

From the the build directory, run `reggae -b <ninja|make|tup|binary>
/path/to/your/project`. You can now build your project using the
appropriate command (ninja, make, tup, or ./build respectively).

Quick Start
---------------------------------

The API is documented [elsewhere](doc/README.md) and the best examples
can be found in the [feature tests](features). To build a simple hello
app in C/C++ with a build description in Python:

```python
from reggae import *
app = executable(name="hello", src_dirs=["."], compiler_flags="-g -O0")
b = Build(app)
```

Or in D:

```d
import reggae;
alias app = executable!(ExeName("hello"), Sources!(["."]), Flags("-g -O"));
mixin build!app;
```

This shows how to use the `executable` high-level convenience rule. For custom behaviour
the low-level primitives can be used. In D:

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

These wouldn't usually be used for compiling as above, since the high-level rules take care of that.

D projects and dub integration
---------------

The easiest dub integration is to run reggae with a directory
containing a dub project as parameter. That will create a build system
that would do the same as "dub build" but probably faster. In all
likelihood a user needing reggae will need more than that, and reggae
provides an API to use dub build information in a `reggaefile.d` build
description file. A simple example for building production and
unittest binaries concurrently is this:

```d
import reggae;
alias main = dubDefaultTarget!(CompilerFlags("-g -debug"));
alias ut = dubConfigurationTarget!(Configuration("unittest"));
mixin build!(main, ut);
```

This is equivalent to the automatically generated reggaefile if none is present.

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

To build reggae, you will need a D compiler. The dmd reference
compiler is recommended.  Reggae can build itself. To bootstrap,
either use dub (dub build) or the
[included bootstrap script](bootstrap.sh).  Call it without arguments
for `make` or with one to choose another backend, such as
`ninja`. This will create a `reggae` binary in a `bin` directory then
call itself to generate the "real" build system with the requested
backend. The reggae-enabled build includes a unit test binary.
