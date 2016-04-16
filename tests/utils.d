module tests.utils;

import reggae;
import unit_threaded;

void shouldThrowWithMessage(E)(lazy E expr, string expectedMsg,
                               string file = __FILE__, size_t line = __LINE__) {
    string msg;
    bool threw;
    try {
        expr();
    } catch(Exception ex) {
        msg = ex.msg;
        threw = true;
    }

    if(!threw) throw new UnitTestException(["Expression did not throw. Expected msg: " ~ msg],
                                           file, line);
    msg.shouldEqual(expectedMsg, file, line);
}


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
        throw new UnitTestException(["Could not execute '" ~ args.join(" ") ~ "':"] ~
                                    "" ~ lines,
                                    file, line);
    return lines;
}

struct FakeFile {
    string[] lines;
    void writeln(T...)(T args) {
        import std.conv;
        lines ~= text(args);
    }
}
