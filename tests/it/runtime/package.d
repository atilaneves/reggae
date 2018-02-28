module tests.it.runtime;

public import tests.it;
public import tests.utils;
import reggae.reggae;

// calls reggae.run, which is basically main, but with a
// fake file
@DontTest
auto testRun(string[] args) {
    auto output = FakeFile();
    run(output, args);
    return output;
}

struct ReggaeSandbox {

    alias sandbox this;

    Sandbox sandbox;
    static string currentTestPath;

    static ReggaeSandbox opCall() {
        ReggaeSandbox ret;
        ret.sandbox = Sandbox();
        currentTestPath = ret.testPath;
        return ret;
    }

    static ReggaeSandbox opCall(in string projectName) {
        auto ret = ReggaeSandbox();
        ret.copyProject(projectName);
        return ret;
    }

    ~this() @safe {
        currentTestPath = null;
    }

    auto runReggae(string[] args...) const {
        return runImpl(args);
    }

    auto runReggae(string[] args, string project) const {
        return runImpl(args, project);
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
        import std.path: buildPath;
        return [buildPath(testPath, arg)].shouldExecuteOk(WorkDir(testPath), file, line);
    }

    auto shouldFail(in string arg, in string file = __FILE__, ulong line = __LINE__) const {
        import tests.utils;
        import std.path: buildPath;
        return [buildPath(testPath, arg)].shouldFailToExecute(testPath, file, line);
    }

    void copyProject(in string projectName) const {
        import std.path;
        const projPath = buildPath(origPath, "tests", "projects", projectName);
        copyProjectFiles(projPath, testPath);
    }


private:

    auto runImpl(string[] args, string project = "") const {
        import std.file: thisExePath;
        import std.path: buildPath, dirName, absolutePath;
        if(project == "") project = testPath;
        return testRun(["reggae", "-C", testPath] ~ args ~ project);
    }
}


void shouldContain(string[] haystack, in string needle,
                   string file = __FILE__, size_t line = __LINE__) {
    import std.algorithm;
    import std.array;
    if(!haystack.canFind!(a => a.canFind(needle)))
        throw new UnitTestException(["Could not find " ~ needle ~ " in:"] ~ haystack, file, line);
}

void shouldContain(in string haystack, in string needle,
                   in string file = __FILE__, in size_t line = __LINE__) {
    import std.algorithm;
    import std.array;
    if(!haystack.canFind(needle))
        throw new UnitTestException(["Could not find " ~ needle ~ " in:"] ~ haystack, file, line);
}


void shouldNotContain(string[] haystack, in string needle,
                      string file = __FILE__, size_t line = __LINE__) {
    import std.algorithm;
    import std.array;
    if(haystack.canFind!(a => a.canFind(needle)))
        throw new UnitTestException(["Should not have found " ~ needle ~ " in:"] ~ haystack, file, line);
}

void shouldNotContain(in string haystack, in string needle,
                      in string file = __FILE__, in size_t line = __LINE__) {
    import std.algorithm;
    import std.array;
    if(haystack.canFind(needle))
        throw new UnitTestException(["Should not have found " ~ needle ~ " in:"] ~ haystack, file, line);
}
