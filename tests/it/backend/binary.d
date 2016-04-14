// Integration tests for the binary backend
module tests.it.backend.binary;

import reggae;
import unit_threaded;
import std.file;
import std.string;


enum origFileName = "original.txt";
enum copyFileName = "copy.txt";


private Build binaryBuild() {
    mixin build!(Target(copyFileName, `cp $in $out`, Target(origFileName)),
                 optional(Target.phony(`opt`, `echo Optional!`)));
    return buildFunc();
}

private void writeOrigFile() {
    import std.stdio: File;
    auto file = File(origFileName, "w");
    file.writeln("See the little goblin");
}

private struct FakeFile {
    string[] lines;
    void writeln(T...)(T args) {
        import std.conv;
        lines ~= text(args);
    }
}


@("Do nothing after build") unittest {
    scope(exit) {
        remove(copyFileName);
        remove(origFileName);
    }

    writeOrigFile;

    auto file = FakeFile();
    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]), file);
    binary.run(["./build"]);
    copyFileName.exists.shouldBeTrue;

    file.lines = [];
    binary.run(["./build"]);
    file.lines.shouldEqual(["[build] Nothing to do"]);
}


@("Targets should only be built once") unittest {
    import std.process;
    import std.stdio: File;
    import std.range;
    import std.algorithm: map;
    import std.conv: to;

    enum fooSrcName = "foo.txt";
    enum barSrcName = "bar.txt";

    scope(exit) {
        foreach(name; [fooSrcName, barSrcName, "foo", "bar"])
            remove(name);
        executeShell("rm -rf objs");
    }

    {
        // create the src files so the rule fires
        auto fooSrc = File(fooSrcName, "w");
        auto barSrc = File(barSrcName, "w");
    }

    auto foo = Target("$project/foo", "echo foo >> $out", [], [Target(fooSrcName)]);
    auto bar = Target("$project/bar", "echo bar >> $out", [], [Target(barSrcName)]);
    auto mids = iota(10).map!(a => Target.phony("$project/" ~a.to!string, "echo " ~ a.to!string, [foo, bar])).array;
    auto top = Target.phony("top", "echo top", mids);

    auto binary = Binary(Build(top), getOptions(["reggae", "--export"]));
    binary.run(["./build"]);

    // only one line -> rule only called once
    readText("foo").chomp.split("\n").shouldEqual(["foo"]);
    readText("bar").chomp.split("\n").shouldEqual(["bar"]);
}
