/**
 This package implements a meta-build system in D, with the build
 descriptions in D.  At its core is a set of data definitions that
 allow a user to specify arbitrary build descriptions at compile-time,
 including the usage of functions that only run at run-time (so a
 build can, for example, automatically include every file in a
 directory).

 The build is contained in a $(D reggaefile.d) file, which must define
 one and only one function returning an object of type $(D
 Build). This function is usually generated from the provided $(D
 build) template mixin for maximum convenience.

 A $(D Build) struct only serves as a top-level container for
 $(Target) structs. Each one of these can include other dependent
 $(Target) structs recursively and form the basis of the build
 descripton. The $(D build) module contains these data definitions,
 please refer to the documentation therein for more information.

 As well as these low-level data definitions, reggae provides built-in
 high-level rules to automate common build system tasks for D, C, and
 C++. These can be found in the reggae.rules package and its
 subpackages. There is also a $(D reggae.rules.dub) package for accessing
 targets defined in/by dub.

 Reggae works by using backends. Currently, there are three: the
 ninja, make and binary backends. The first two generate files for
 those two build systems in the same manner as CMake and Premake
 do. The latter produces a binary executable that when run will check
 dependencies and execute build commands as appropriate.
 */


module reggae;

public import reggae.build;
public import reggae.reflect;
public import reggae.range;
public import reggae.backend.make;
public import reggae.backend.ninja;
public import reggae.backend.binary;
public import reggae.rules;
public import reggae.types;
public import reggae.dub_info;
public import reggae.config;
public import reggae.ctaa;
