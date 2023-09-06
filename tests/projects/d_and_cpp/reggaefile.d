module d_and_cpp.reggaefile;
import reggae;
enum mainObj  = objectFile!(SourceFile(`src/main.d`), Flags(), ImportPaths(["src"]));
enum mathsObj = objectFile!(SourceFile(`src/maths.cpp`),
                            Flags(``),
                            IncludePaths([`src`]));

version(Windows) version(DigitalMars) version = Windows_DMD;

version(Windows_DMD)
    enum model = " -m32mscoff";
else
    enum string model = null;

mixin build!(Target(`calc`, `dmd` ~ model ~ ` -of$out $in`, [mainObj, mathsObj]));
