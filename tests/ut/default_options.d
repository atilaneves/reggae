module tests.ut.default_options;

import reggae.path: buildPath;
import unit_threaded;


void testDefaultCCompiler() {
    import reggae;
    Options defaultOptions;
    defaultOptions.cCompiler = "weirdcc";
    enum target = objectFile(SourceFile("foo.c"), Flags("-g -O0"), IncludePaths(["includey", "headers"]));
    mixin build!(target);
    auto build = buildFunc();

    version(Windows)
        enum projectPath = "C:/path/to/proj";
    else
        enum projectPath = "/path/to/proj";

    auto args = ["progname", "-b", "ninja", projectPath]; //fake main function args
    auto options = getOptions(defaultOptions, args);
    enum objPath = "foo" ~ objExt;
    build.targets[0].shellCommand(options).shouldEqual(
        "weirdcc -g -O0 -I" ~ buildPath(projectPath, "includey") ~ " -I" ~ buildPath(projectPath, "headers") ~
        " -MMD -MT " ~ objPath ~ " -MF " ~ objPath ~ ".dep -o " ~ objPath ~ " -c " ~ buildPath(projectPath, "foo.c"));
}


void testOldNinja() {
    import reggae;
    Options defaultOptions;
    defaultOptions.oldNinja = true;
    auto args = ["progname", "-b", "ninja", "/path/to/proj"]; //fake main function args
    auto options = getOptions(defaultOptions, args);
}
