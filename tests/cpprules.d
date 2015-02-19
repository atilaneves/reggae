module tests.cpprules;


import reggae;
import unit_threaded;


void testNoIncludePaths() {
    const build = Build(cppCompile("path/to/src/foo.cpp"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = ",
                     "flags = ",
                     "DEPFILE = foo.o.d"])]);
}


void testIncludePaths() {
    const build = Build(cppCompile("path/to/src/foo.cpp", "", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "flags = ",
                     "DEPFILE = foo.o.d"])]);
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
