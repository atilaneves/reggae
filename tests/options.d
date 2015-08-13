module tests.options;


import reggae;
import reggae.options;
import unit_threaded;


void testRerunArgsOldNinja() {
    auto options = Options();
    options.ranFromPath = "/foo/bar/reggae";
    options.oldNinja = true;
    options.backend = Backend.ninja;
    options.projectPath = "proj";
    options.rerunArgs.shouldEqual(["/foo/bar/reggae", "-b", "ninja", "--old_ninja", "proj"]);
}


void testRerunArgsOldNinjaAndCompilers() {
    auto options = Options();
    options.ranFromPath = "/usr/bin/reggae";
    options.oldNinja = true;
    options.backend = Backend.ninja;
    options.cCompiler = "icc";
    options.cppCompiler = "clang++";
    options.dCompiler = "gdc";
    options.projectPath = "leproject";
    options.rerunArgs.shouldEqual(
        ["/usr/bin/reggae", "-b", "ninja", "--old_ninja",
         "--cc", "icc", "--cxx", "clang++", "--dc", "gdc", "leproject"]);
}

void testRerunArgsMakeAndDflags() {
    auto options = Options();
    options.ranFromPath = "/bin/reggae";
    options.backend = Backend.make;
    options.dflags = "-g -debug";
    options.projectPath = "makeProject";
    options.rerunArgs.shouldEqual(
        ["/bin/reggae", "-b", "make", "--dflags='-g -debug'", "makeProject"]);
}
