module tests.ut.rules.link;


import reggae;
import unit_threaded;


@("shell commands") unittest {
    import reggae.config: gDefaultOptions;
    auto objTarget = link(ExeName("myapp"), [Target("foo.o"), Target("bar.o")], Flags("-L-L"));
    objTarget.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
        "dmd -ofmyapp -L-L /path/to/foo.o /path/to/bar.o");

    auto cppTarget = link(ExeName("cppapp"), [Target("foo.o", "", Target("foo.cpp"))], Flags("--sillyflag"));
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    cppTarget.shellCommand(gDefaultOptions.withProjectPath("/foo/bar")).shouldEqual("g++ -o cppapp --sillyflag foo.o");

    auto cTarget = link(ExeName("capp"), [Target("bar.o", "", Target("bar.c"))]);
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    cTarget.shellCommand(gDefaultOptions.withProjectPath("/foo/bar")).shouldEqual("gcc -o capp  bar.o");
}


@("include flags in project dir") unittest {
    auto obj = objectFile(SourceFile("src/foo.c"),
                          Flags("-include $project/includes/header.h"));
    auto app = link(ExeName("app"), [obj]);
    auto bld = Build(app);
    import reggae.config: gDefaultOptions;
    bld.targets[0].dependencies[0].shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
        "gcc -include /path/to/includes/header.h  -MMD -MT objs/app.objs/src/foo.o -MF objs/app.objs/src/foo.o.dep -o objs/app.objs/src/foo.o -c /path/to/src/foo.c");
}

@("template link") unittest {
    string[] flags;
    link!(ExeName("app"), () => [Target("foo.o"), Target("bar.o")]).shouldEqual(
        Target("app",
               Command(CommandType.link, assocListT("flags", flags)),
               [Target("foo.o"), Target("bar.o")]));
}
