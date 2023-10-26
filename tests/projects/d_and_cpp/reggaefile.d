module d_and_cpp.reggaefile;
import reggae;
enum mainObj  = objectFile!(SourceFile(`src/main.d`), Flags(), ImportPaths(["src"]));
enum mathsObj = objectFile!(SourceFile(`src/maths.cpp`),
                            Flags(``),
                            IncludePaths([`src`]));

version(Windows) version(DigitalMars) version = Windows_DMD;

mixin build!(Target(`calc`, `dmd -of$out $in`, [mainObj, mathsObj]));
