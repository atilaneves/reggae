module tests.drules;


import reggae;
import unit_threaded;


void testDCompileNoIncludePaths() {
    const build = Build(dCompile("path/to/src/foo.d"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = ",
                     "DEPFILE = foo.o.d"])]);
}


void testDCompileIncludePaths() {
    const build = Build(dCompile("path/to/src/foo.d", "", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "DEPFILE = foo.o.d"])]);
}
