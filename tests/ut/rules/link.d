module tests.ut.rules.link;


import reggae;
import reggae.path: buildPath;
import unit_threaded;


@("shell commands") unittest {
    import reggae.config: gDefaultOptions, dCompiler;

    auto objTarget = link(ExeName("myapp"), [Target("foo.o"), Target("bar.o")], Flags("-L-L"));
    objTarget.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
        dCompiler ~ " -ofmyapp -L-L " ~ buildPath("/path/to/foo.o") ~ " " ~ buildPath("/path/to/bar.o"));

    auto cppTarget = link(ExeName("cppapp"), [Target("foo.o", "", Target("foo.cpp"))], Flags("--sillyflag"));
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    version(Windows)
        enum expectedCpp = "cl.exe /nologo /Fecppapp --sillyflag foo.o";
    else
        enum expectedCpp = "g++ --sillyflag foo.o -o cppapp";
    cppTarget.shellCommand(gDefaultOptions.withProjectPath("/foo/bar")).shouldEqual(expectedCpp);

    auto cTarget = link(ExeName("capp"), [Target("bar.o", "", Target("bar.c"))]);
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    version(Windows)
        enum expectedC = "cl.exe /nologo /Fecapp bar.o";
    else
        enum expectedC = "gcc bar.o -o capp";
    cTarget.shellCommand(gDefaultOptions.withProjectPath("/foo/bar")).shouldEqual(expectedC);
}


@("include flags in project dir") unittest {
    auto obj = objectFile(Options(), SourceFile("src/foo.c"),
                          Flags("-include $project/includes/header.h"));
    auto app = link(ExeName("app"), [obj]);
    auto bld = Build(app);
    import reggae.config: gDefaultOptions;
    enum objPath = buildPath(".reggae/objs/app.objs/src/foo" ~ objExt);
    version(Windows) {
        enum expected = `cl.exe /nologo -include \path\to/includes/header.h /showIncludes ` ~
                        `/Fo` ~ objPath ~ ` -c \path\to\src\foo.c`;
    } else {
        enum expected = "gcc -include /path/to/includes/header.h -MMD -MT " ~ objPath ~ " -MF " ~ objPath ~ ".dep " ~
                        "-o " ~ objPath ~ " -c /path/to/src/foo.c";
    }
    bld.targets[0].dependencyTargets[0].shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(expected);
}

@("template link") unittest {
    string[] flags;
    link!(ExeName("app"), () => [Target("foo.o"), Target("bar.o")]).shouldEqual(
        Target("app",
               Command(CommandType.link, assocListT("flags", flags, "link_libraries", flags)),
               [Target("foo.o"), Target("bar.o")]));
}
