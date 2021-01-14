module tests.ut.cpprules;


import reggae;
import reggae.options;
import reggae.path: buildPath;
import reggae.backend.ninja;
import unit_threaded;


void testNoIncludePaths() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.cpp")));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _cppcompile " ~ buildPath("/tmp/myproject/path/to/src/foo.cpp"),
                    ["DEPFILE = " ~ objPath ~ ".dep"]),
            ]);
}


void testIncludePaths() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.cpp"), Flags(""),
                                   IncludePaths(["path/to/src", "other/path"])));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _cppcompile " ~ buildPath("/tmp/myproject/path/to/src/foo.cpp"),
                    ["includes = -I" ~buildPath("/tmp/myproject/path/to/src") ~ " -I" ~ buildPath("/tmp/myproject/other/path"),
                     "DEPFILE = " ~ objPath ~ ".dep"]),
            ]);
}


void testFlagsCompileC() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.c"), Flags("-m64 -fPIC -O3")));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _ccompile " ~ buildPath("/tmp/myproject/path/to/src/foo.c"),
                    ["flags = -m64 -fPIC -O3",
                     "DEPFILE = " ~ objPath ~ ".dep"]),
            ]);
}

void testFlagsCompileCpp() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.cpp"), Flags("-m64 -fPIC -O3")));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _cppcompile " ~ buildPath("/tmp/myproject/path/to/src/foo.cpp"),
                    ["flags = -m64 -fPIC -O3",
                     "DEPFILE = " ~ objPath ~ ".dep"]),
            ]);
}

void testCppCompile() {
    auto mathsObj = objectFile(SourceFile("src/cpp/maths.cpp"),
                                Flags("-m64 -fPIC -O3"),
                                IncludePaths(["headers"]));

    version(Windows) {
        enum expected = `cl.exe /nologo -m64 -fPIC -O3 -I\path\to\headers /showIncludes ` ~
                        `/Fosrc\cpp\maths.obj -c \path\to\src\cpp\maths.cpp`;
    } else {
        enum expected = "g++ -m64 -fPIC -O3 -I/path/to/headers -MMD -MT src/cpp/maths.o -MF src/cpp/maths.o.dep " ~
                        "-o src/cpp/maths.o -c /path/to/src/cpp/maths.cpp";
    }

    import reggae.config: gDefaultOptions;
    mathsObj.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(expected);
}

void testCCompile() {
    auto mathsObj = objectFile(SourceFile("src/c/maths.c"),
                                Flags("-m64 -fPIC -O3"),
                                IncludePaths(["headers"]));

    version(Windows) {
        enum expected = `cl.exe /nologo -m64 -fPIC -O3 -I\path\to\headers /showIncludes ` ~
                        `/Fosrc\c\maths.obj -c \path\to\src\c\maths.c`;
    } else {
        enum expected = "gcc -m64 -fPIC -O3 -I/path/to/headers -MMD -MT src/c/maths.o -MF src/c/maths.o.dep " ~
                        "-o src/c/maths.o -c /path/to/src/c/maths.c";
    }

    enum objPath = buildPath("src/c/maths" ~ objExt);
    mathsObj.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(expected);
}


void testUnityNoFiles() {
    string[] files;
    immutable projectPath = "";
    unityFileContents(projectPath, files).shouldThrow;
}


private void shouldEqualLines(string actual, string[] expected,
                              in string file = __FILE__, in size_t line = __LINE__) {
    import std.string;
    actual.split("\n").shouldEqual(expected, file, line);
}

void testUnityCppFiles() {
    auto files = ["src/foo.cpp", "src/bar.cpp"];
    unityFileContents("/path/to/proj/", files).shouldEqualLines(
        [`#include "/path/to/proj/src/foo.cpp"`,
         `#include "/path/to/proj/src/bar.cpp"`]);
}


void testUnityCFiles() {
    auto files = ["src/foo.c", "src/bar.c"];
    unityFileContents("/foo/bar/", files).shouldEqualLines(
        [`#include "/foo/bar/src/foo.c"`,
         `#include "/foo/bar/src/bar.c"`]);
}

void testUnityMixedLanguages() {
    auto files = ["src/foo.cpp", "src/bar.c"];
    unityFileContents("/project", files).shouldThrow;
}

void testUnityDFiles() {
    auto files = ["src/foo.d", "src/bar.d"];
    unityFileContents("/project", files).shouldThrow;
}


void testUnityTargetCpp() @trusted {
    import reggae.config: gDefaultOptions;

    enum files = ["src/foo.cpp", "src/bar.cpp", "src/baz.cpp"];
    Target[] dependencies() @safe pure nothrow {
        return [Target("$builddir/mylib.a")];
    }

    immutable projectPath = "/path/to/proj";
    auto target = unityTarget!(ExeName("leapp"),
                                projectPath,
                                files,
                                Flags("-g -O0"),
                                IncludePaths(["headers"]),
                                dependencies);
    target.rawOutputs.shouldEqual(["leapp"]);
    version(Windows) {
        enum expected = `cl.exe /nologo -g -O0 -I\path\to\proj\headers /showIncludes ` ~
                        `/Foleapp .reggae\objs\leapp.objs\unity.cpp mylib.a`;
    } else {
        enum expected = "g++ -g -O0 -I/path/to/proj/headers -MMD -MT leapp -MF leapp.dep " ~
                        "-o leapp .reggae/objs/leapp.objs/unity.cpp mylib.a";
    }
    target.shellCommand(gDefaultOptions.withProjectPath(projectPath)).shouldEqual(expected);
    target.dependencyTargets.shouldEqual([Target.phony(buildPath("$builddir/.reggae/objs/leapp.objs/unity.cpp"),
                                                       "",
                                                       [],
                                                       [Target("src/foo.cpp"),
                                                        Target("src/bar.cpp"),
                                                        Target("src/baz.cpp")]),
                                          Target("$builddir/mylib.a")]);
}

void testUnityTargetC() @trusted {
    import reggae.config: gDefaultOptions;

    enum files = ["src/foo.c", "src/bar.c", "src/baz.c"];
    Target[] dependencies() @safe pure nothrow {
        return [Target("$builddir/mylib.a")];
    }

    immutable projectPath = "/path/to/proj";
    auto target = unityTarget!(ExeName("leapp"),
                                projectPath,
                                files,
                                Flags("-g -O0"),
                                IncludePaths(["headers"]),
                                dependencies);
    target.rawOutputs.shouldEqual(["leapp"]);
    version(Windows) {
        enum expected = `cl.exe /nologo -g -O0 -I\path\to\proj\headers /showIncludes ` ~
                        `/Foleapp .reggae\objs\leapp.objs\unity.c mylib.a`;
    } else {
        enum expected = "gcc -g -O0 -I/path/to/proj/headers -MMD -MT leapp -MF leapp.dep " ~
                        "-o leapp .reggae/objs/leapp.objs/unity.c mylib.a";
    }
    target.shellCommand(gDefaultOptions.withProjectPath(projectPath)).shouldEqual(expected);
    target.dependencyTargets.shouldEqual([Target.phony(buildPath("$builddir/.reggae/objs/leapp.objs/unity.c"),
                                                       "",
                                                       [],
                                                       [Target("src/foo.c"),
                                                        Target("src/bar.c"),
                                                        Target("src/baz.c")]),
                                          Target("$builddir/mylib.a")]);
}
