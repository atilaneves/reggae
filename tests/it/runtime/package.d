module tests.it.runtime;

public import tests.it;
public import tests.utils;
import reggae.path: buildPath;
import reggae.reggae;

// calls reggae.run, which is basically main, but with a
// fake file
auto testRun(string[] args) {
    import reggae.reggae: run;

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
        import std.algorithm: filter;
        import std.array: array;
        return runImpl(args.filter!(a => a !is null).array);
    }

    auto runReggae(string[] args, string project) const {
        return runImpl(args, project);
    }

    void writeHelloWorldApp() const {
        import std.stdio;
        import std.file;
        import std.array;

        mkdir(buildPath(testPath, "src"));
        sandbox.writeFile(buildPath("src/hello.d"), q{
                import std.stdio;
                void main() {
                    writeln("Hello world!");
                }
        }.split("\n").array);
    }

    auto shouldSucceed(string file = __FILE__, size_t line = __LINE__)(in string[] args...) const
    {
        import tests.utils;
        auto rest = args.length > 1
            ? args[1..$]
            : [];
        return shouldExecuteOk([buildPath(testPath, args[0])] ~ rest, WorkDir(testPath), file, line);
    }

    auto shouldFail(in string arg, in string file = __FILE__, in size_t line = __LINE__) const {
        import tests.utils;
        return [buildPath(testPath, arg)].shouldFailToExecute(testPath, file, line);
    }

    void copyProject(in string projectName, in string testSubPath = ".") const {
        const fromPath = buildPath(origPath, "tests/projects", projectName);
        const toPath = buildPath(testPath, testSubPath);
        copyProjectFiles(fromPath, toPath);
    }

    string[] binary(string[] args = []) {
        import tests.it: binary;
        return .binary(testPath, args);
    }

private:

    auto runImpl(string[] args, string project = "") const {

        import std.algorithm: canFind;

        if(project == "") project = testPath;

        string[] fromWhereArgs;
        if(!args.canFind("-C")) fromWhereArgs = ["-C", testPath];

        version(LDC)
            enum compiler = "ldc2";
        else version (GDC)
            enum compiler = "gdc";
        else version(DigitalMars)
            enum compiler = "dmd";
        else
            static assert(false, "Unknown D compiler");

        return testRun(["reggae"] ~ fromWhereArgs ~ args ~ project);
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
