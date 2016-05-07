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

struct Reggae {
    string testPath;

    static Reggae opCall() {
        Reggae ret;
        ret.testPath = cast(immutable)newTestDir;
        return ret;
    }

    void run(string[] args...) const {
        runImpl(args);
    }

    void run(string[] args, string project) const {
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


private:

    void runImpl(string[] args, string project = "") const {
        if(project == "") project = testPath;
        testRun(["reggae", "-C", testPath] ~ args ~ project);
    }
}


void writeHelloWorldApp(in string testPath) {
    import std.stdio;
    import std.path;
    import std.file;

    mkdir(buildPath(testPath, "src"));
    File(buildPath(testPath, "src", "hello.d"), "w").writeln(q{
        import std.stdio;
        void main() {
            writeln("Hello world!");
        }
    });
}
