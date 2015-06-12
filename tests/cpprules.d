module tests.cpprules;


import reggae;
import unit_threaded;


void testNoIncludePaths() {
    const build = Build(objectFile("path/to/src/foo.cpp"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["DEPFILE = $out.dep"]),
            ]);
}


void testIncludePaths() {
    const build = Build(objectFile("path/to/src/foo.cpp", "", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "DEPFILE = $out.dep"]),
            ]);
}


void testFlagsCompileC() {
    const build = Build(objectFile("path/to/src/foo.c", "-m64 -fPIC -O3"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _ccompile /tmp/myproject/path/to/src/foo.c",
                    ["flags = -m64 -fPIC -O3",
                     "DEPFILE = $out.dep"]),
            ]);
}

void testFlagsCompileCpp() {
    const build = Build(objectFile("path/to/src/foo.cpp", "-m64 -fPIC -O3"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["flags = -m64 -fPIC -O3",
                     "DEPFILE = $out.dep"]),
            ]);
}

void testCppCompile() {
    const mathsObj = objectFile(`src/cpp/maths.cpp`, `-m64 -fPIC -O3`, [`headers`]);
    mathsObj.shellCommand("/path/to").shouldEqual("g++ -m64 -fPIC -O3 -I/path/to/headers -MMD -MT src/cpp/maths.o -MF src/cpp/maths.o.dep -o src/cpp/maths.o -c /path/to/src/cpp/maths.cpp");
}

void testCCompile() {
    const mathsObj = objectFile(`src/c/maths.c`, `-m64 -fPIC -O3`, [`headers`]);
    mathsObj.shellCommand("/path/to").shouldEqual("gcc -m64 -fPIC -O3 -I/path/to/headers -MMD -MT src/c/maths.o -MF src/c/maths.o.dep -o src/c/maths.o -c /path/to/src/c/maths.c");
}
