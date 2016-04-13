module tests.ut.backend.binary;

import reggae;
import unit_threaded;


bool fooCalled;
bool barCalled;

void resetCalls() { fooCalled = false; barCalled = false;}


void testTargetSelection() {
    auto foo = Target("foo", (string[] i, string[] o) { fooCalled = true; }, Target("foo.d"));
    auto bar = Target("bar", (string[] i, string[] o) { barCalled = true; }, Target("bar.d"));
    auto binary = Binary(Build(foo, bar), getOptions(["reggae", "--export"]));

    {
        scope(exit) resetCalls;
        binary.run(["prog"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "foo", "bar"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "foo"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeFalse;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "bar"]);
        fooCalled.shouldBeFalse;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "nonexistent"]).shouldThrow;
        fooCalled.shouldBeFalse;
        barCalled.shouldBeFalse;
    }
}

void testTopLevelTargets() {
    auto foo = Target("foo", "", Target("foo.d"));
    auto bar = Target("bar", "", Target("bar.d"));
    auto binary = Binary(Build(foo, bar), Options());
    binary.topLevelTargets(["foo"]).shouldEqual([foo]);
    binary.topLevelTargets(["bar"]).shouldEqual([bar]);
    binary.topLevelTargets([]).shouldEqual([foo, bar]);
    binary.topLevelTargets(["oops"]).shouldEqual([]);
}


@("Targets should only be built once") unittest {
}

private Build binaryBuild() {
    mixin build!(Target("app", "dmd -of$out $in", [Target("foo.o"), Target("bar.o") ]),
                 optional(Target.phony(`opt`, `echo Optional!`)));
    return buildFunc();
}

private struct FakeFile {
    string[] lines;
    void writeln(T...)(T args) {
        import std.conv;
        lines ~= text(args);
    }
}

@("Listing targets") unittest {
    import std.stdio: stdout, File;

    auto file = FakeFile();
    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]), file);
    binary.run(["./build", "-l"]);

    file.lines.shouldEqual(
        ["List of available top-level targets:",
         "- app",
         "- opt (optional)"]);
}

private void shouldThrowWithMessage(E)(lazy E expr, string msg,
                                       string file = __FILE__, size_t line = __LINE__) {
    try {
        expr();
    } catch(Exception ex) {
        ex.msg.shouldEqual(msg);
        return;
    }

    throw new Exception("Expression did not throw. Expected msg: " ~ msg, file, line);
}

@("Unknown target") unittest {
    import std.stdio: stdout, File;

    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
    binary.run(["./build", "oops"]).
        shouldThrowWithMessage("Unknown target(s) 'oops'");
}

@("Unknown targets") unittest {
    import std.stdio: stdout, File;

    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
    binary.run(["./build", "oops", "woopsie"]).
        shouldThrowWithMessage("Unknown target(s) 'oops' 'woopsie'");
}
