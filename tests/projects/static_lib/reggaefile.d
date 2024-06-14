module static_lib.reggaefile;

import reggae;

alias lib = staticLibrary!(`maths` ~ libExt, Sources!([`libsrc`]));
enum mainObj = objectFile!(SourceFile(`src/main.d`), CompilerFlags(), ImportPaths(["libsrc"]));
alias app = link!(ExeName("app"), targetConcat!(mainObj, lib), LinkerFlags());
mixin build!app;
