module tests.drules;


import reggae;
import unit_threaded;


void testDCompileNoIncludePathsNinja() {
    const build = Build(dCompile("path/to/src/foo.d"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = ",
                     "flags = ",
                     "stringImports = ",
                     "DEPFILE = path/to/src/foo.o.d"])]);
}


void testDCompileIncludePathsNinja() {
    const build = Build(dCompile("path/to/src/foo.d", "-O", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "flags = -O",
                     "stringImports = ",
                     "DEPFILE = path/to/src/foo.o.d"])]);
}

void testDCompileIncludePathsMake() {
    import std.algorithm;
    const build = Build(dCompile("path/to/src/foo.d", "-O", ["path/to/src", "other/path"]));
    const make = Makefile(build, "/tmp/myproject");
    make.command(build.targets[0]).startsWith(".reggae/dcompile --srcFile=path/to/src/foo.d --objFile=path/to/src/foo.o --depFile=path/to/src/foo.o.d dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path").shouldBeTrue;
}


void testDLinkNinja() {
    const build = Build(dLink("bin/lefoo", [Target("leobj.o")], "-lib"));
    const ninja = Ninja(build, "/dir/stuff");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build bin/lefoo: _dlink /dir/stuff/leobj.o",
                    ["flags = -lib"])]);
}
