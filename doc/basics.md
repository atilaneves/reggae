Basics
=======

Import / require reggae
----------------------

    import reggae; //D
    from reggae import * # Python
    require 'reggae' # Ruby
    var reggae = require('reggae-js') // Javascript
    reggae = require('reggae') -- Lua

Convenience Rules
----------------

The rest of this document describes the low-level primitives. Most users will
want instead to use the [high-level convenience rules](rules.md).

Target
------

Reggae provides data definitions that allow the user to specify a build. This is the core of the system
and all high-level rules are built on this base. A *build* is considered to be a list of top-level *targets*.
A target has a collection of outputs (usually just one), a command to generate it, a list of explicit
dependencies and a list of implicit dependencies. A target may be defined as follows:

    //D:
    enum target = Target("foo.o", "dmd -of$out -c $in", Target("foo.d")); //implicits left out

    # Python:
    target = Target("foo.o", "dmd -of$out -c $in", Target("foo.d")); # implicits left out

    # Ruby:
    target = Target.new("foo.o", "dmd -of$out -c $in", Target.new("foo.d"))

    // Javascript:
    target = new reggae.Target("foo.o", "dmd -of$out -c $in", new reggae.Target("foo.d"))

    -- Lua
    target = reggae.Target("foo.o", "dmd -of$out -c $in", reggae.Target("foo.d"))

In general outputs and dependencies are arrays/lists, but since it's more common for both of them to only
contain one element, the constructor allows it to be called as above.

Implicit dependencies are files that, when changed, should cause the target to be rebuilt but that
are not present in the command. An example would be header files for C/C++. Any dependent file that
*does* feature in the command is an explicit dependency.

So, the general way to create a target is via this pseudo-code signature:

    Target(string[] outputs, string command, Target[] dependencies, Target[] implicits);


Build
------

`Build` is a structure whose only purpose is to define what targets are the *top-level* ones.
One and only one of these must be defined in the build description file (`reggaefile.{d,py,rb,js,lua}`).
Top-level targets are generated in the root of the build directory. Any intermediate dependencies
are built in a directory specific to each top-level target to avoid name clashes.

For D build descriptions, the reggaefile must have a function that returns a `Build` object. This
function may have any name. It is usually not written by hand, for the `build` template mixin
generates this function for the user. Usually the last line of a reggaefile will be:

```d
//topLevelTarget1, ... have been defined before using enum or alias
mixin build!(topLevelTarget1, topLevelTarget2, ...);
```

Where each target was defined before.

In scripting languages, one build object should be defined at top level.
It doesn't matter what it's called, it just has to be of the `reggae.Build` type.
In, e.g., Python:

```python
top_level_tgt1 = Target(...)
bld = Build(top_level_tgt1, top_level_tgt2, ...) # any name will do for this variable
```

Top level targets may be made optional, which means they don't get built by default but
can be built explicitly:

```d
mixin build!(target1, optional(target2)); // D
```

```python
bld = Build(target1, optional(target2))  # Python
```


Source and Build directories
----------------------------

The source or project directory is the one where the build description is (`reggaefile.{d,py,...}`).
The build directory is where reggae is run from. Reggae encourages but does not mandate the use
of separate directories for builds and source code.

Special variables
-----------------

Reggae currently has 4 special variables that get expanded when the build is generated:

* `$in` - expands to all inputs for the current target. Should be preferred instead of explicitly listing them.
* `$out` - expands to all outputs for the current target. Should be preferred instead of explicitly listing them.
* `$builddir` - The build directory. Useful for generating targets in a particular place.
* `$project` - The source directory. Useful for reading files in a specific place in the source tree.

Otherwise, referring to any source file is done from the root of the project directory.

Default Options
---------------

Some builds may always use the same command-line options, as is the case when using a special
compiler for embedded development. Since it is tedious and error-prone to require users to
always specify these options, it is possible to override defaults for a build in particular.
In D, assign to `defaultOptions`:

    defaultOptions.cCompiler = "my_weird_cc";

In Python, use kwargs with the `DefaultOptions type`:

    opts = DefaultOptions(cCompiler='my_weird_cc', ...)



Run-time and compile-time
-------------------------
This section only applies to build descriptions written in D.

As D is a compiled language, `reggaefile.d` files must be compiled and linked in order to produce builds.
This makes it challenging to use top-level (file-scope) definitions in comparison to a scripting language.

Anything that is known at compile-time is defined with the `enum` keyword:

    enum fooObj = Target("foo.o", "...", Target("foo.d"));
    enum barObj = Target("bar.o", "...", Target("bar.d"));
    enum app = Target("app", "...", [fooObj, barObj]);
    mixin build!app;


Most real-life builds, however, rely on run-time information such as "all files in a certain directory".
These are not possible to define at file-scope easily. A work-around would be to define the build
function that is usually done by the `build` mixin manually and access the filesystem from there.

Reggae usually provides template function definitions that may use the `alias` keyword to avoid this
and keep all build definitions global. A rule of thumb is that what's known at compile-time should
use `enum`, and what's run-time should use `alias`.
