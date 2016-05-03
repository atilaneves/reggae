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
