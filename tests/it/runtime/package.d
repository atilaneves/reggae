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

// calls reggae.run, which is nearly the same as calling
// reggae itself with an array of string args.
// this function calls reggae in a test sandbox dir
// so it takes only the extra options.
// The project path isn't needed, nor the binary name
auto runReggaeImpl(string[] args, string project = "") {
    const testPath = newTestDir;
    if(project == "") project = testPath;
    return testRun(["reggae", "-C", testPath] ~ args ~ project);
}

auto runReggae(string[] args...) {
    return runReggaeImpl(args);
}

auto runReggaeProject(string[] args...) {
    return runReggaeImpl(args[0..$-1], args[$-1]);
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

private void writeFile(in string testPath, in string fileName) {
    import std.stdio;
    import std.path;
    File(buildPath(testPath, fileName), "w").writeln;
}
