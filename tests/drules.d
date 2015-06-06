module tests.drules;


import reggae;
import unit_threaded;
import std.algorithm;


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
    const build = Build(dCompile("path/to/src/foo.d", "-O", ["path/to/src", "other/path"]));
    build.targets[0].shellCommand("/tmp/myproject").shouldEqual(".reggae/reggaebin --objFile=path/to/src/foo.o --depFile=path/to/src/foo.o.d dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d");
}


void testDLinkNinja() {
    const build = Build(dLink("bin/lefoo", [Target("leobj.o")], "-lib"));
    const ninja = Ninja(build, "/dir/stuff");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build bin/lefoo: _dlink /dir/stuff/leobj.o",
                    ["flags = -lib"])]);
}

void testDCompileWithMultipleFilesMake() {
    const build = Build(dCompilePerPackage(["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                                      "-O", ["path/to/src", "other/path"]));
    const make = Makefile(build, "/tmp/myproject");

    build.targets[0].shellCommand("/tmp/myproject").shouldEqual(".reggae/reggaebin --objFile=other.o --depFile=other.o.d dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/other/weird.d");

    build.targets[1].shellCommand("/tmp/myproject").shouldEqual(".reggae/reggaebin --objFile=path/to/src.o --depFile=path/to/src.o.d dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d /tmp/myproject/path/to/src/bar.d");

}

void testDCompileWithMultipleFilesNinja() {
    const build = Build(dCompilePerPackage(["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                                 "-O", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");

    ninja.buildEntries.shouldEqual(
        [

            NinjaEntry("build other.o: _dcompile /tmp/myproject/other/weird.d",
                       ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                        "flags = -O",
                        "stringImports = ",
                        "DEPFILE = other.o.d"]),

            NinjaEntry("build path/to/src.o: _dcompile /tmp/myproject/path/to/src/foo.d /tmp/myproject/path/to/src/bar.d",
                       ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                        "flags = -O",
                        "stringImports = ",
                        "DEPFILE = path/to/src.o.d"]),

            ]);
}
