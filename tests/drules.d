module tests.drules;


import reggae;
import unit_threaded;
import std.algorithm;


void testDCompileNoIncludePathsNinja() {
    const build = Build(objectFile("path/to/src/foo.d"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["DEPFILE = path/to/src/foo.o.dep"])]);
}


void testDCompileIncludePathsNinja() {
    const build = Build(objectFile("path/to/src/foo.d", "-O", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "flags = -O",
                     "DEPFILE = path/to/src/foo.o.dep"])]);
}

void testDCompileIncludePathsMake() {
    const build = Build(objectFile("path/to/src/foo.d", "-O", ["path/to/src", "other/path"]));
    build.targets[0].shellCommand("/tmp/myproject").shouldEqual(".reggae/dcompile --objFile=path/to/src/foo.o --depFile=path/to/src/foo.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d");
}


void testDLinkNinja() {
    const build = Build(link("bin/lefoo", [Target("leobj.o")], "-lib"));
    const ninja = Ninja(build, "/dir/stuff");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build bin/lefoo: _link /dir/stuff/leobj.o",
                    ["flags = -lib"])]);
}

void testDCompileWithMultipleFilesMake() {
    const build = Build(objectFilesPerPackage(["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                                              "-O", ["path/to/src", "other/path"]));
    const make = Makefile(build, "/tmp/myproject");

    build.targets[0].shellCommand("/tmp/myproject").shouldEqual(".reggae/dcompile --objFile=other.o --depFile=other.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/other/weird.d");

    build.targets[1].shellCommand("/tmp/myproject").shouldEqual(".reggae/dcompile --objFile=path/to/src.o --depFile=path/to/src.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d /tmp/myproject/path/to/src/bar.d");

}

void testDCompileWithMultipleFilesNinja() {
    const build = Build(objectFilesPerPackage(["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                                              "-O", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");

    ninja.buildEntries.shouldEqual(
        [

            NinjaEntry("build other.o: _dcompile /tmp/myproject/other/weird.d",
                       ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                        "flags = -O",
                        "DEPFILE = other.o.dep"]),

            NinjaEntry("build path/to/src.o: _dcompile /tmp/myproject/path/to/src/foo.d /tmp/myproject/path/to/src/bar.d",
                       ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                        "flags = -O",
                        "DEPFILE = path/to/src.o.dep"]),

            ]);
}


void testLink() {
    const target = link("myapp", [Target("foo.o"), Target("bar.o")], "-L-L");
    target.shellCommand("/path/to").shouldEqual("dmd -ofmyapp -L-L /path/to/foo.o /path/to/bar.o");
}
