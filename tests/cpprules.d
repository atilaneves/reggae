module tests.cpprules;


import reggae;
import unit_threaded;


void testNoIncludePaths() {
    const build = Build(objectFile(SourceFile("path/to/src/foo.cpp")));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["DEPFILE = path/to/src/foo.o.dep"]),
            ]);
}


void testIncludePaths() {
    const build = Build(objectFile(SourceFile("path/to/src/foo.cpp"), Flags(""),
                                   IncludePaths(["path/to/src", "other/path"])));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "DEPFILE = path/to/src/foo.o.dep"]),
            ]);
}


void testFlagsCompileC() {
    const build = Build(objectFile(SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3")));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _ccompile /tmp/myproject/path/to/src/foo.c",
                    ["flags = -m64 -fPIC -O3",
                     "DEPFILE = path/to/src/foo.o.dep"]),
            ]);
}

void testFlagsCompileCpp() {
    const build = Build(objectFile(SourceFile("path/to/src/foo.cpp"), Flags("-m64 -fPIC -O3")));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["flags = -m64 -fPIC -O3",
                     "DEPFILE = path/to/src/foo.o.dep"]),
            ]);
}

void testCppCompile() {
    const mathsObj = objectFile(SourceFile("src/cpp/maths.cpp"),
                                Flags("-m64 -fPIC -O3"),
                                IncludePaths(["headers"]));

    mathsObj.shellCommand("/path/to").shouldEqual(
        "g++ -m64 -fPIC -O3 -I/path/to/headers -MMD -MT src/cpp/maths.o -MF src/cpp/maths.o.dep "
        "-o src/cpp/maths.o -c /path/to/src/cpp/maths.cpp");
}

void testCCompile() {
    const mathsObj = objectFile(SourceFile("src/c/maths.c"),
                                Flags("-m64 -fPIC -O3"),
                                IncludePaths(["headers"]));

    mathsObj.shellCommand("/path/to").shouldEqual(
        "gcc -m64 -fPIC -O3 -I/path/to/headers -MMD -MT src/c/maths.o -MF src/c/maths.o.dep "
        "-o src/c/maths.o -c /path/to/src/c/maths.c");
}


void testUnityNoFiles() {
    string[] files;
    immutable projectPath = "";
    unityFileContents(projectPath, files).shouldThrow;
}


private void shouldEqualLines(string actual, string[] expected,
                              in string file = __FILE__, in ulong line = __LINE__) {
    import std.string;
    actual.split("\n").shouldEqual(expected, file, line);
}

void testUnityCppFiles() {
    const files = ["src/foo.cpp", "src/bar.cpp"];
    unityFileContents("/path/to/proj/", files).shouldEqualLines(
        [`#include "/path/to/proj/src/foo.cpp"`,
         `#include "/path/to/proj/src/bar.cpp"`]);
}


void testUnityCFiles() {
    const files = ["src/foo.c", "src/bar.c"];
    unityFileContents("/foo/bar/", files).shouldEqualLines(
        [`#include "/foo/bar/src/foo.c"`,
         `#include "/foo/bar/src/bar.c"`]);
}
