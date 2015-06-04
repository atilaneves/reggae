module tests.cpprules;


import reggae;
import unit_threaded;


void testNoIncludePaths() {
    const build = Build(cppCompile("path/to/src/foo.cpp"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = ",
                     "flags = ",
                     "DEPFILE = path/to/src/foo.o.d"]),
            ]);
}


void testIncludePaths() {
    const build = Build(cppCompile("path/to/src/foo.cpp", "", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "flags = ",
                     "DEPFILE = path/to/src/foo.o.d"]),
            ]);
}



void testNoSrcFileSelection() {
    selectSrcFiles([], [], []).shouldEqual([]);
}


void testSrcFileSelection() {
    auto dirFiles = ["src/foo.d", "src/bar.d", "weird/peculiar.d"];
    auto extraSrcs = ["extra/toto.d", "extra/choochoo.d"];
    auto excludeSrcs = ["weird/peculiar.d"];

    selectSrcFiles(dirFiles, extraSrcs, excludeSrcs).shouldEqual(
        ["src/foo.d", "src/bar.d", "extra/toto.d", "extra/choochoo.d"]);
}


void testFlagsCompileC() {
    const build = Build(cCompile("path/to/src/foo.c", "-m64 -fPIC -O3"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _ccompile /tmp/myproject/path/to/src/foo.c",
                    ["includes = ",
                     "flags = -m64 -fPIC -O3",
                     "DEPFILE = path/to/src/foo.o.d"]),
            ]);
}

void testFlagsCompileCpp() {
    const build = Build(cppCompile("path/to/src/foo.cpp", "-m64 -fPIC -O3"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = ",
                     "flags = -m64 -fPIC -O3",
                     "DEPFILE = path/to/src/foo.o.d"]),
            ]);
}
