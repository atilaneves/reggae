module tests.it.rules.d_cmake_interop;

import tests.it.runtime;
import tests.utils;
import reggae.reggae;

string binaryPath(in string binary) {
    import std.path : buildNormalizedPath;
    return buildNormalizedPath(ReggaeSandbox.currentTestPath, ".reggae", binary);
}

@("D and CMake rules interop - shared library")
unittest {
    import std.process : executeShell;
    import std.format : format;
    import std.path : buildNormalizedPath;

    with(immutable ReggaeSandbox("d_cmake_shared")) {
        runReggae("-b", "ninja");

        ninja.shouldExecuteOk;

        version(Windows) {
            executeShell("copy " ~ binaryPath("CalculatorShared.dll") ~ " " ~ currentTestPath);
            shouldExist("CalculatorShared.dll");
        } else {
            shouldExist(binaryPath("libCalculatorShared.so"));
        }

        [buildNormalizedPath(currentTestPath, "dcpp"), "3", "4"].shouldExecuteOk.shouldEqual(["7", "-1", "12"]);
    }
}

@("D and CMake rules interop - static library")
unittest {
    import std.process : executeShell;
    import std.format : format;
    import std.path : buildNormalizedPath;

    with(immutable ReggaeSandbox("d_cmake_static")) {
        runReggae("-b", "ninja");

        ninja.shouldExecuteOk;

        version(Windows) {
            shouldExist(binaryPath("CalculatorStatic.lib"));
        } else {
            shouldExist(binaryPath("libCalculatorStatic.a"));
        }

        [buildNormalizedPath(currentTestPath, "dcpp"), "3", "4"].shouldExecuteOk.shouldEqual(["7", "-1", "12"]);
    }
}
