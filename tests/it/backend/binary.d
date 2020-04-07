// Integration tests for the binary backend
module tests.it.backend.binary;

import reggae;
import unit_threaded;
import std.file;
import std.string;


enum origFileName = "original.txt";
enum copyFileName = "copy.txt";


private Build binaryBuild() {
    version(Windows)
        enum cmd = `copy $in $out`;
    else
        enum cmd = `cp $in $out`;

    mixin build!(Target(copyFileName, cmd, Target(origFileName)),
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
    auto args = ["./build", "--norerun"];
    binary.run(args);

    copyFileName.exists.shouldBeTrue;

    file.lines = [];
    binary.run(args);
    file.lines.shouldEqual(["[build] Nothing to do"]);
}


@("Targets should only be built once") unittest {
    import std.process;
    import std.stdio: File;
    import std.range;
    import std.algorithm: map;
    import std.conv: to;
    import std.string: splitLines;

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
    auto mids = 10.iota
        .map!(a => Target.phony("$project/" ~a.to!string, "echo " ~ a.to!string, [foo, bar]))
        .array
        ;
    auto top = Target.phony("top", "echo top", mids);

    auto binary = Binary(Build(top), getOptions(["reggae", "--export", "-b", "binary"]));
    binary.run(["./build"]);

    // only one line -> rule only called once
    readText("foo").chomp.splitLines.shouldEqual(["foo"]);
    readText("bar").chomp.splitLines.shouldEqual(["bar"]);
}


@("List of targets") unittest {
    auto file = FakeFile();
    auto binary = Binary(binaryBuild, getOptions(["reggae", "-b", "binary"]), file);
    binary.run(["./build", "-l"]);
    file.lines.shouldEqual(
        ["List of available top-level targets:",
         "- copy.txt",
         "- opt (optional)"]);
}

@("List of targets with $project in the name") unittest {
    import std.path;

    auto build = Build(optional(Target("$project/../druntime/" ~ copyFileName, `cp $in $out`, Target(origFileName))),
                       Target.phony(`opt`, `echo Optional!`));
    auto file = FakeFile();
    auto binary = Binary(build, getOptions(["reggae", "-b", "binary"]), file);
    binary.run(["./build", "-l"]);
    file.lines.shouldEqual(
        [
            "List of available top-level targets:",
            "- opt",
            "- " ~ buildPath(getcwd(), "..", "druntime", "copy.txt") ~ " (optional)",
        ]
    );
}
