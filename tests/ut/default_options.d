module tests.ut.default_options;

import reggae.path: buildPath;
import unit_threaded;


@("Default backend") unittest {
    import reggae;
    auto args = ["progname", "/path/to/proj"]; //fake main function args
    auto options = getOptions(args);
    options.backend.shouldEqual(Backend.ninja);
}

@("Default C compiler") unittest {
    import reggae;
    Options defaultOptions;
    defaultOptions.cCompiler = "weirdcc";
    enum target = objectFile!(SourceFile("foo.c"), Flags("-g -O0"), IncludePaths(["includey", "headers"]));
    mixin build!(target);
    auto build = buildFunc();

    version(Windows)
        enum projectPath = "C:/path/to/proj";
    else
        enum projectPath = "/path/to/proj";

    auto args = ["progname", "-b", "ninja", projectPath]; //fake main function args
    auto options = getOptions(defaultOptions, args);
    version(Windows) {
        enum expected = `weirdcc /nologo -g -O0 -IC:\path\to\proj\includey -IC:\path\to\proj\headers /showIncludes ` ~
                        `/Fofoo.obj -c C:\path\to\proj\foo.c`;
    } else {
        enum expected = "weirdcc -g -O0 -I/path/to/proj/includey -I/path/to/proj/headers -MMD -MT foo.o -MF foo.o.dep " ~
                        "-o foo.o -c /path/to/proj/foo.c";
    }
    build.targets[0].shellCommand(options).shouldEqual(expected);
}


@("Old Ninja") unittest {
    import reggae;
    Options defaultOptions;
    defaultOptions.oldNinja = true;
    auto args = ["progname", "-b", "ninja", "/path/to/proj"]; //fake main function args
    auto options = getOptions(defaultOptions, args);
}
