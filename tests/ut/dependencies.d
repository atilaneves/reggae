module tests.ut.dependencies;

import unit_threaded;
import reggae.dependencies: dMainDepSrcs;
import reggae.backend.binary: dependenciesFromFile;
import reggae.dcompile: dMainDependencies, dependenciesToFile;
import std.array;


void testEmpty() {
    "".dMainDependencies.shouldEqual([]);
}

void testImports() {
    "import     std.stdio\t(/inst/std/stdio.d)\n".dMainDependencies.shouldEqual([]);
    "import     std.stdio\t(/int/std/stdio.d)\nimport    foo.bar\t(/foo/bar.d)".
        dMainDependencies.shouldEqual(["/foo/bar.d"]);
}


void testFiles() {
    "file      foo.d\t(/path/to/foo.d)".dMainDependencies.shouldEqual(["/path/to/foo.d"]);
}


void testSrcs() {
    "import     std.stdio\t(/inst/std/stdio.d)\n".dMainDepSrcs.shouldEqual([]);
    "import     std.stdio\t(/int/std/stdio.d)\nimport    foo.bar\t(/foo/bar.d)".
        dMainDepSrcs.shouldEqual(["/foo/bar.d"]);
    "file      foo.d\t(/path/to/foo.d)".dMainDepSrcs.shouldEqual([]);
}


void testEtcLinux() {

    ["semantic2 main",
     "semantic3 main",
     "import    etc.linux.memoryerror (/usr/include/dlang/dmd/etc/linux/memoryerror.d)",
     "import    core.sys.posix.ucontext       (/usr/include/dlang/dmd/core/sys/posix/ucontext.d)"].
        join("\n").dMainDepSrcs.shouldEqual([]);
}


void testToFile() {
    auto deps = ["/foo/bar.d", "/foo/baz.d"];
    dependenciesToFile("foo.o", deps).shouldEqual(
        ["foo.o: \\",
         "/foo/bar.d /foo/baz.d"]);
}


void testFromFile() {
    immutable depFileLines = [
        "objs/calc.objs/src/cpp/maths.o: \\",
        "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp " ~
        "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp"];
    dependenciesFromFile(depFileLines).shouldEqual(
        [ "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/src/cpp/maths.cpp",
          "/home/aalvesne/coding/d/reggae/tmp/aruba/mixproj/headers/maths.hpp"]);

    string[] noDeps;
    dependenciesFromFile(noDeps).shouldEqual([]);
}

@("multiple backslashes")
unittest {
    dependenciesFromFile(
        [`foo.o: \`,
         ` foo.c \`,
         ` foo.h \`,
         `bar.h`])
        .shouldEqual(["foo.c", "foo.h", "bar.h"]);
}
