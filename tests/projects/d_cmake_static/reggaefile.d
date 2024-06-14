module reggaefile;

import reggae;
import std.path : buildNormalizedPath;

Build reggaeBuild() {
    auto cmakeTargets = cmakeBuild!(ProjectPath("cmake"),
                                    Configuration("Release"), [],
                                    CMakeFlags("-G Ninja -D CMAKE_BUILD_TYPE=Release"));

    version(Windows) {
        enum flags = LinkerFlags(`-L/LIBPATH:.reggae -LCalculatorStatic.lib`);
    } else {
        enum flags = LinkerFlags(`-L-L.reggae -L-lCalculatorStatic`);
    }

    auto dlangExeTarget = link(TargetName("dcpp"), dlangObjects!(Sources!"source"),
                               flags, cmakeTargets);

    return Build(dlangExeTarget);
}

mixin BuildgenMain;
