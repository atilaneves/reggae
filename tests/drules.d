module tests.drules;


import reggae;
import unit_threaded;


void testDCompileNoIncludePaths() {
    const build = Build(dCompile("path/to/src/foo.d"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = ",
                     "flags = ",
                     "stringImports = ",
                     "DEPFILE = path/to/src/foo.o.d"])]);
}


void testDCompileIncludePaths() {
    const build = Build(dCompile("path/to/src/foo.d", "-O", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "flags = -O",
                     "stringImports = ",
                     "DEPFILE = path/to/src/foo.o.d"])]);
}


void testDLink() {
    const build = Build(dLink("bin/lefoo", [Target("leobj.o")], "-lib"));
    const ninja = Ninja(build, "/dir/stuff");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build bin/lefoo: _dlink /dir/stuff/leobj.o",
                    ["flags = -lib"])]);
}
