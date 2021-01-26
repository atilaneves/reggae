module tests.it.buildgen;


public import tests.it;
import tests.utils;
import reggae.path: buildPath;


private string projectToModule(in string project) {
    return project ~ ".reggaefile";
}

void generateBuild(string project)(in string backend, string[] args = []) {
    enum module_ = projectToModule(project);
    auto options = testProjectOptions!module_(backend);
    prepareTestBuild!module_(options);

    // binary backend doesn't need to generate anything
    if(options.backend != Backend.binary) {
        auto cmdArgs = buildCmd(options, args);
        doBuildFor!module_(options, cmdArgs);
    }
}


// runs ninja, make, etc. in an integraton test
void shouldBuild(string project)(string[] args = [],
                                 string file = __FILE__,
                                 size_t line = __LINE__ ) {
    import reggae.config;
    enum module_ = projectToModule(project);
    buildCmdShouldRunOk!module_(options, args, file, line);
}


// runs a command in the test sandbox, throws if it fails,
// returns the output
auto shouldSucceed(string[] args, string file = __FILE__, size_t line = __LINE__) {
    import reggae.config;
    return shouldExecuteOk(buildPath(options.workingDir, args[0]) ~ args[1..$],
                           options, file, line);
}

auto shouldSucceed(string arg, string file = __FILE__, size_t line = __LINE__) {
    return shouldSucceed([arg], file, line);
}


// runs a command in the test sandbox, throws if it succeeds
void shouldFail(T)(T args, string file = __FILE__, size_t line = __LINE__) {
    import reggae.config;
    shouldFailToExecute(args, options.workingDir, file, line);
}


// read a file in the test sandbox and verify its contents
void shouldEqualLines(string fileName, string[] lines,
                      string file = __FILE__, size_t line = __LINE__) {
    import reggae.config;
    import std.ascii: newline;
    import std.file: readText;
    import std.string: chomp, split;

    readText(buildPath(options.workingDir, fileName)).chomp.split(newline)
        .shouldEqual(lines, file, line);
}
