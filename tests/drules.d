module tests.drules;


import reggae;
import unit_threaded;


void testDCompileNoIncludePaths() {
    const build = Build(dcompile("path/to/src/foo.d"));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = ",
                     "DEPFILE = foo.o.d"])]);
}


void testDCompileIncludePaths() {
    const build = Build(dcompile("path/to/src/foo.d", "", ["path/to/src", "other/path"]));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "DEPFILE = foo.o.d"])]);
}


void testDLinkOnlyName() {
    const build = Build(dlink("my/src/foo.d"));
    const ninja = Ninja(build, "/projs/lefoo");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo: _dlink /projs/lefoo/my/src/foo.d",
                    ["DEPFILE = foo.d"])]);
}


void testDLinkAllOptions() {
    const build = Build(dlink("my/src/foo.d", "", ["my/src"], [], [Target("boo.o")]));
    const ninja = Ninja(build, "/projs/lefoo");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo: _dlink /projs/lefoo/my/src/foo.d /projs/lefoo/my/src/boo.o",
                    ["DEPFILE = foo.d"])]);

}
