module tests.it.buildgen;


public import tests.it;
import tests.utils;


private string projectToModule(in string project) {
    return project ~ ".reggaefile";
}

void generateBuild(string project)(string[] args = []) {
    enum module_ = projectToModule(project);
    auto options = _testProjectOptions!module_;
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
                                 ulong line = __LINE__ ) {
    import reggae.config;
    enum module_ = projectToModule(project);
    buildCmdShouldRunOk!module_(options, args, file, line);
}


// runs a command in the test sandbox, throws if it fails,
// returns the output
auto shouldSucceed(string[] args, string file = __FILE__, size_t line = __LINE__) {
    import reggae.config;
    import std.path;
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
    import std.file;
    import std.string;

    readText(buildPath(options.workingDir, fileName)).chomp.split("\n")
        .shouldEqual(lines, file, line);
}
