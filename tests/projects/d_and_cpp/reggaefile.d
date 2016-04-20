module d_and_cpp.reggaefile;
import reggae;
enum mainObj  = objectFile(SourceFile(`src/main.d`));
enum mathsObj = objectFile(SourceFile(`src/maths.cpp`),
                           Flags(``),
                           IncludePaths([`headers`]));
mixin build!(Target(`calc`, `dmd -of$out $in`, [mainObj, mathsObj]));
