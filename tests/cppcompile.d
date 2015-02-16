module tests.cppcompile;


import reggae;
import unit_threaded;


void testStuff() {
    const build = Build(cppcompile("path/to/src/foo.cpp"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _cppcompile /tmp/myproject/path/to/src/foo.cpp",
                    ["includes = "])]);
}
