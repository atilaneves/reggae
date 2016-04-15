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


void doTestBuildFor(string module_ = __MODULE__)(string[] extraArgs = []) {
    auto args = ["reggae", "--no_comp_db"] ~ extraArgs;
    auto options = getOptions(args);
    doBuildFor!(module_)(options, args);
}


auto shouldExecuteOk(string[] args, string file = __FILE__, size_t line = __LINE__) {
    import std.process;
    import std.array;
    import std.string;

    immutable res = execute(args);
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
