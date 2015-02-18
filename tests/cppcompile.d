module tests.cppcompile;


import reggae;
import unit_threaded;


void testNoIncludePaths() {
    const build = Build(cppCompile("path/to/src/foo.cpp"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = ",
                     "DEPFILE = foo.o.d"])]);
}


void testIncludePaths() {
    const build = Build(cppCompile("path/to/src/foo.cpp", "", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "DEPFILE = foo.o.d"])]);
}
