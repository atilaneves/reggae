module tests.dependencies;

import unit_threaded;
import reggae.dependencies;


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
