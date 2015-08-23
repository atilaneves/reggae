Basics
=======

Target
------

Reggae provides data definitions that allow the user to specify a build. This is the core of the system
and all high-level rules are built on this base. A *build* is considered to be a list of top-level *targets*.
A target has a collection of outputs (usually just one), a command to generate it, a list of explicit
dependencies and a list of implicit dependencies. In D, a target may be defined as follows:

    enum target = Target("foo.o", "dmd -of$out -c $in", Target("foo.d")); //implicits left out

In general outputs and dependencies are arrays, but since it's more common for both of them to only
contain one element, the constructor allows it to be called as above.

Implicit dependencies are files that, when changed, should cause the target to be rebuilt but that
are not present in the command. An example would be header files for C/C++. Any dependent file that
*does* feature in the command is an explicit dependency.

So, the general way to create a target is via this pseudo-code signature:

    Target(string[] outputs, string command, Target[] dependencies, Target[] implicits);


Build
------

`Build` is a structure whose only purpose is to define what targets are the *top-level* ones.
One and only one of these must be defined in the build description file (typically `reggaefile.d`).
Top-level targets are generated in the root of the build directory. Any intermediate dependencies
are built in a directory specific to each top-level target to avoid name clashes.

For D build descriptions, the reggaefile must have a function that returns a Build object. This
function may have any name. It is usually not written by hand, for the `build` template mixin
generates this function for the user. Usually the last line of a reggaefile will be:

    mixin build!(topLevel1, topLevel2, ...);

Where each target was defined before.

In scripting languages such as Python, one build object should be defined at top level.


Source and Build directories
----------------------------

The source or project directory is the one where the build description is (`reggaefile.{d,py,...}`).
The build directory is where reggae is run from. Reggae encourages but does not mandate the use
of separate directories for builds and source code.

Special variables
-----------------

Reggae currently has 4 special variables that get expanded when the build is generated:

. $in - expands to all inputs for the current target. Should be preferred instead of explicitly listing them.
. $out - expands to all outputs for the current target. Should be preferred instead of explicitly listing them.
. $builddir - The build directory. Useful for generating targets in a particular place.
. $project - The source directory. Useful for reading files in a specific place in the source tree.

Otherwise, referring to any source file is done from the root of the project directory.


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
