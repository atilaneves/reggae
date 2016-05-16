module tests.it.runtime;

public import tests.it;
public import tests.utils;
import reggae.reggae;

// calls reggae.run, which is basically main, but with a
// fake file
auto testRun(string[] args) {
    auto output = FakeFile();
    run(output, args);
    return output;
}

struct ReggaeSandbox {
    Sandbox sandbox;
    alias sandbox this;

    static ReggaeSandbox opCall() {
        ReggaeSandbox ret;
        ret.sandbox = Sandbox();
        return ret;
    }

    void runReggae(string[] args...) const {
        runImpl(args);
    }

    void runReggae(string[] args, string project) const {
        runImpl(args, project);
    }

    void writeHelloWorldApp() const {
        import std.stdio;
        import std.path;
        import std.file;
        import std.array;

        mkdir(buildPath(testPath, "src"));
        sandbox.writeFile(buildPath("src", "hello.d"), q{
                import std.stdio;
                void main() {
                    writeln("Hello world!");
                }
        }.split("\n").array);
    }

    auto shouldSucceed(in string arg,
                       in string file = __FILE__,
                       ulong line = __LINE__ ) const {
        import tests.utils;
        return [buildPath(testPath, arg)].shouldExecuteOk(testPath, file, line);
    }

    void shouldFail(in string arg, in string file = __FILE__, ulong line = __LINE__) const {
        import tests.utils;
        return [buildPath(testPath, arg)].shouldFailToExecute(testPath, file, line);
    }

    void copyProject(in string projectName) const {
        import std.path;
        const projPath = buildPath(origPath, "tests", "projects", projectName);
        copyProjectFiles(projPath, testPath);
    }


private:

    void runImpl(string[] args, string project = "") const {
        if(project == "") project = testPath;
        testRun(["reggae", "-C", testPath] ~ args ~ project);
    }
}


void shouldContain(string[] haystack, in string needle,
                   string file = __FILE__, size_t line = __LINE__) {
    import std.algorithm;
    import std.array;
    if(!haystack.canFind!(a => a.canFind(needle)))
        throw new UnitTestException(["Could not find " ~ needle ~ " in:"] ~ haystack);

}
