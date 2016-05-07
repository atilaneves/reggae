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

    void writeFile(in string fileName) const {
        import std.stdio;
        import std.path;
        File(buildPath(testPath, fileName), "w").writeln;
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
