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

struct Runtime {
    string testPath;

    static Runtime opCall() {
        Runtime ret;
        ret.testPath = cast(immutable)newTestDir;
        return ret;
    }

    void runReggae(string[] args...) const {
        runImpl(args);
    }

    void runReggae(string[] args, string project) const {
        runImpl(args, project);
    }

    void writeFile(in string fileName, in string[] lines = [""]) const {
        import std.stdio;
        import std.path;
        auto f = File(buildPath(testPath, fileName), "w");
        foreach(l; lines) f.writeln(l);
    }

    void writeHelloWorldApp() const {
        import std.stdio;
        import std.path;
        import std.file;
        import std.array;

        mkdir(buildPath(testPath, "src"));
        writeFile(buildPath("src", "hello.d"), q{
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


private:

    void runImpl(string[] args, string project = "") const {
        if(project == "") project = testPath;
        testRun(["reggae", "-C", testPath] ~ args ~ project);
    }
}
