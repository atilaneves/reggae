module d_and_cpp.reggaefile;
import reggae;
enum mainObj  = objectFile!(SourceFile(`src/main.d`), CompilerFlags(), ImportPaths(["src"]));
enum mathsObj = objectFile!(SourceFile(`src/maths.cpp`),
                            CompilerFlags(``),
                            IncludePaths([`src`]));

mixin build!(Target(`calc`, `dmd -of$out $in`, [mainObj, mathsObj]));
