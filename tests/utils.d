module tests.utils;

import reggae;
import unit_threaded;
import std.file;

struct WorkDir {
    string value;
}

auto shouldExecuteOk(in string[] args, in string file = __FILE__, in size_t line = __LINE__) {
    import tests.it.runtime: ReggaeSandbox;
    return shouldExecuteOk(args, WorkDir(ReggaeSandbox.currentTestPath), file, line);
}

auto shouldExecuteOk(in string[] args, in WorkDir workDir,
                     in string file = __FILE__, in size_t line = __LINE__) {
    import std.process;
    import std.array;
    import std.string;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;

    immutable res = execute(args, env, config, maxOutput, workDir.value);

    auto lines = res.output.chomp.split("\n");
    if(res.status != 0)
        throw new UnitTestException(["Could not execute '" ~ args.join(" ") ~
                                     "' in path " ~ workDir.value ~ ":"] ~
                                    "" ~ lines,
                                    file, line);
    return lines;
}

auto shouldExecuteOk(string[] args, in Options options,
                     string file = __FILE__, size_t line = __LINE__) {
    return shouldExecuteOk(args, WorkDir(options.workingDir), file, line);
}

auto shouldExecuteOk(string arg, in Options options,
                     string file = __FILE__, size_t line = __LINE__) {
    return shouldExecuteOk([arg], options, file, line);
}

auto shouldExecuteOk(string arg, string file = __FILE__, size_t line = __LINE__) {
    import std.file: getcwd;
    return shouldExecuteOk([arg], WorkDir(getcwd()), file, line);
}

auto shouldFailToExecute(string arg, string workDir = getcwd(),
                         string file = __FILE__, size_t line = __LINE__) {
    return shouldFailToExecute([arg], workDir, file, line);
}

auto shouldFailToExecute(string[] args, string workDir = getcwd(),
                         string file = __FILE__, size_t line = __LINE__) {

    import std.process;
    import std.array;
    import std.string: splitLines, chomp;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;

    try {
        immutable res = execute(args, env, config, maxOutput, workDir);
        if(res.status == 0)
            throw new UnitTestException([args.join(" ") ~
                                         " executed ok but was expected to fail"], file, line);
        return res.output.chomp.splitLines;
    } catch(ProcessException) {}
    return "".chomp.splitLines;
}


struct FakeFile {

    string soFar;
    string[] lines;

    void write(T...)(auto ref T args) {
        import std.conv: text;
        static if(T.length > 0)
            soFar ~= text(args);
    }

    void writeln(T...)(auto ref T args) {
        import std.conv: text;
        static if(T.length > 0)
            lines ~= soFar ~ text(args);
        else
            lines ~= soFar;
    }

    string toString() @safe pure nothrow const {
        import std.array: join;
        return "--------------------\n" ~
            lines.join("\n") ~
            soFar ~ "\n" ~
            "--------------------\n";
    }
}
