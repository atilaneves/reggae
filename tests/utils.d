module tests.utils;

import reggae;
import unit_threaded;


auto shouldExecuteOk(string[] args, string workDir,
                     string file = __FILE__, size_t line = __LINE__) {
    import std.process;
    import std.array;
    import std.string;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;

    immutable res = execute(args, env, config, maxOutput, workDir);

    auto lines = res.output.chomp.split("\n");
    if(res.status != 0)
        throw new UnitTestException(["Could not execute '" ~ args.join(" ") ~
                                     "' in path " ~ workDir ~ ":"] ~
                                    "" ~ lines,
                                    file, line);
    return lines;
}

auto shouldExecuteOk(string[] args, in Options options, string file = __FILE__, size_t line = __LINE__) {
    return shouldExecuteOk(args, options.workingDir, file, line);
}

auto shouldExecuteOk(string arg, in Options options, string file = __FILE__, size_t line = __LINE__) {
    return shouldExecuteOk([arg], options, file, line);
}

auto shouldExecuteOk(string arg, string file = __FILE__, size_t line = __LINE__) {
    import std.file;
    return shouldExecuteOk([arg], getcwd(), file, line);
}


struct FakeFile {
    string[] lines;
    void writeln(T...)(T args) {
        import std.conv;
        lines ~= text(args);
    }
}
