module tests.ut.backend.binary;

import reggae;
import unit_threaded;
import tests.utils;

void testTargetSelection() {

    bool fooCalled;
    bool barCalled;
    void resetCalls() { fooCalled = false; barCalled = false;}

    auto foo = Target("foo", (in string[] i, in string[] o) { fooCalled = true; }, Target("foo.d"));
    auto bar = Target("bar", (in string[] i, in string[] o) { barCalled = true; }, Target("bar.d"));
    auto binary = Binary(Build(foo, bar), getOptions(["reggae", "--export"]));

    {
        scope(exit) resetCalls;
        binary.run(["prog", "--norerun"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "--norerun", "foo", "bar"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "--norerun", "foo"]);
        fooCalled.shouldBeTrue;
        barCalled.shouldBeFalse;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "--norerun", "bar"]);
        fooCalled.shouldBeFalse;
        barCalled.shouldBeTrue;
    }

    {
        scope(exit) resetCalls;
        binary.run(["prog", "--norerun", "nonexistent"]).shouldThrow;
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


private Build binaryBuild() {
    mixin build!(Target("app", "dmd -of$out $in", [Target("foo.o"), Target("bar.o") ]),
                 optional(Target.phony(`opt`, `echo Optional!`)));
    return buildFunc();
}

@("Listing targets") unittest {
    import std.stdio: stdout, File;

    auto file = FakeFile();
    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]), file);
    binary.run(["./build", "--norerun", "-l"]);

    file.lines.shouldEqual(
        ["List of available top-level targets:",
         "- app",
         "- opt (optional)"]);
}


@("Unknown target") unittest {
    import std.stdio: stdout, File;

    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
    binary.run(["./build", "--norerun", "oops"]).
        shouldThrowWithMessage("Unknown target(s) 'oops'");
}

@("Unknown targets") unittest {
    import std.stdio: stdout, File;

    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
    binary.run(["./build", "--norerun", "oops", "woopsie"]).
        shouldThrowWithMessage("Unknown target(s) 'oops' 'woopsie'");
}
