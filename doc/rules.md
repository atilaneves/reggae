Rules
======

As well as [means to define generic builds](basics.md), reggae also provides a list
of high-level convenience rules for common build tasks for C, C++ and D projects.


objectFiles
----------

This or `staticLibrary` should be a user's go-to rule. It takes a list
of source files, mostly specified by their directories, and returns an
array of `Target` structs corresponding to the object files resulting
from the compilation of those source files. The compiler to invoke for
each is used automatically as a result of the file extension.

### D

```d
Target[] objectFiles(alias sourcesFunc = Sources!(),
                     Flags flags = Flags(),
                     ImportPaths includes = ImportPaths(),
                     StringImportPaths stringImports = StringImportPaths(),
    )
```

`sourcesFunc`: A function that, at runtime, returns the source files to compile.
Generally will be "created" with `Sources`, a template function:

```d
auto Sources(Dirs = Dirs(), Files = Files(), F = Filter!(a => true))()
```

* `Dirs` and `Files` are wrapper structs around a string array.
* `Filter` can be used to filter out files that shouldn't be compiled.
* `flags`: The compiler flags to use.
* `includes`: The include/import paths
* `stringImports`: The string import paths (only relevant for D)


### Python

```python

def object_files(src_dirs=[],
                 exclude_dirs=[],
                 src_files=[],
                 exclude_files=[],
                 flags='',
                 includes=[],
                 string_imports=[])

```

* `src_dirs`: The source directories. If not specified, defaults to ".".
* `exclude_dirs`: Particular directories to exclude.
* `flags`: Compiler flags.
* `includes`: Compiler include directories.
* `string_imports`: Compiler string import directories (only relevant for D).

### Ruby

```ruby
def object_files(src_dirs: [], exclude_dirs: [],
                 src_files: [], exclude_files: [],
                 flags: '',
                 includes: [], string_imports: [])
```

Same as the Python version.

### Javascript

```javascript
function objectFiles(options)
```

`options` is an object with fields as in the Python and Ruby versions.

### Lua

```lua
function object_files(options)
```

Same as the Javascript version.


staticLibrary
-------------

The same as objectFiles but outputs a static library archive instead. Has one extra
parameter for the name of the file to generate, passed in as a string in D as the first parameter,
and by an optional argument called `name` in the scripting languages.


link
----

Generates an executable or shared object / dynamic library.

### D

```d
Target link(ExeName exeName, alias dependenciesFunc, Flags flags = Flags())
```

* `exeName`: The name of the executable.
* `dependenciesFunc`: A function that, at runtime, returns an array of `Target` structs to link to
* `flags`: Linker flags.

### Python

```d
def link(exe_name=None, flags='', dependencies=None, implicits=[]):
```

* `exe_name`: The name of the executable.
* `dependencies`: The dependencies to link to.
* `implicits`: Any implicit dependencies.

### Ruby

```ruby
def link(exe_name:, flags: '', dependencies: [], implicits: [])
```

Same as the Python version

### Javascript and Lua

`function link(options)`

* `options`: An object/table with parameters named as in the Python/Ruby versions


executable
----------

This rule creates a runnable executable. It is equivalent to calling `objectFiles`
followed by `link` with a superset of the parameters of those two rules.


scriptlike
----------

Currently only supported for D executables. Takes the name of a source file where the `main`
function is defined, automatically determines dependencies and returns a target with all
compilation and linking steps defined. Does essentially the same as `rdmd`.

### D

```d
Target scriptlike(App app,
                  Flags flags = Flags(),
                  ImportPaths importPaths = ImportPaths(),
                  StringImportPaths stringImportPaths = StringImportPaths(),
                  alias linkWithFunction = () { return cast(Target[])[];})
```

* `app`: The app to build. Takes two parameters of type `SourceFileName` and `BinaryFileName`,
both wrapper struct for strings.
* `flags`: Compiler flags to use.
* `importPaths`: A list of import paths for the compiler.
* `stringImports`: A list of string import paths for the compiler.
* `linkWithFunction`: A function that, at runtime, returns the list of `Target` structs to link to.

### Python
```python
def scriptlike(src_name=None,
               exe_name=None,
               flags='',
               includes=[],
               string_imports=[],
               link_with=[]):
```

* `src_name`: The name of the source file containing the `main` function
* `exe_name`: The name of the executable file to generate. Defaults to the name of `src_name`
* `flags`: Compiler flags.
* `includes`: Import paths.
* `string_imports`: String import paths.
* `link_with`: A list of targets to link with.

### Ruby
```ruby
def scriptlike(src_name:,
               exe_name:,
               flags: '',
               includes: [],
               string_imports: [],
               link_with: [])
```

Same as the python version.

### Javascript and Lua

A function taking an object/table with attributes as in the Python and Ruby versions.


unityBuild
----------

Only valid for pure C or pure C++ top-level source files. This rule produces an
executable binary using a technique for speeding up builds called unity build.
The binary is compiled as one translation unit by compiling a C/C++ file that
`#include`s the other source files.

### D

```d
Target unityBuild(ExeName exeName,
                  alias sourcesFunc,
                  Flags flags = Flags(),
                  IncludePaths includes = IncludePaths(),
                  alias dependenciesFunc = emptyTargets,
                  alias implicitsFunc = emptyTargets)();
```

* `exeName`: Same as in `scriptlike`
* `sourcesFunc`: Same as in `objectFiles`.
* `flags`: Compiler flags.
* `includes`: Include paths.
* `dependenciesFunc`: A function that, at runtime, returns the dependencies to link to.
* `implicitsFunc`: A function that, at runtime, returns the implicit dependencies.

`emptyTargets` is a pre-defined function that returns an tempty `Target[]` array.


dubDefaultTarget
----------------

Currently only supported for build descriptions written in D.
The target usually generated by `dub` with `dub build`.

```d
Target dubDefaultTarget(CompilerFlags compilerFlags = CompilerFlags(),
                        LinkerFlags linkerFlags = LinkerFlags(),
                        Flag!"allTogether" allTogether = No.allTogether)
```

If it is used with no compiler
flags, an empty parameter list must be added, e.g.:

    mixin build!(dubDefaultTarget!());


dubTestTarget
-------------

The target that would be built by `dub test`.

dubConfigurationTarget
----------------------

Currently only supported for build descriptions written in D.
A configuration target of dub's, for instance 'unittest'.

```d
Target dubConfigurationTarget(Configuration config = Configuration("default"),
                              CompilerFlags compilerFlags = CompilerFlags(),
                              LinkerFlags linkerFlags = LinkerFlags(),
                              Flag!"allTogether" allTogether = No.allTogether,
                              alias objsFunction = () { Target[] t; return t; },
                             )
        () if(isCallable!objsFunction)
```

* `config`: The dub configuration to use.
* `compilerFlags`: Self-explanatory.
* `LinkerFlags`: Self-explanatory.
* `allTogether`: to be done.
* `objsFunction`: Dependencies to link to.
