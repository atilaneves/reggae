// Integration tests for the binary backend
module tests.it.backend.binary;

import reggae;
import unit_threaded;
import tests.utils: FakeFile;
import std.file;
import std.string;


enum origFileName = "original.txt";
enum copyFileName = "copy.txt";


private Build binaryBuild() {
    version(Windows)
        enum cmd = `copy $in $out`;
    else
        enum cmd = `cp $in $out`;

    return Build(Target(copyFileName, cmd, Target(origFileName)),
                 optional(Target.phony(`opt`, `echo Optional!`)));
}

private void writeOrigFile() {
    import std.stdio: File;
    auto file = File(origFileName, "w");
    file.writeln("See the little goblin");
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


version(Windows) {}
else {
    @("Targets should only be built once") unittest {
        import std.process;
        import std.stdio: File;
        import std.range;
        import std.algorithm: map;
        import std.conv: to;
        import std.string: splitLines, stripRight;

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
        readText("foo").splitLines.map!stripRight.shouldEqual(["foo"]);
        readText("bar").splitLines.map!stripRight.shouldEqual(["bar"]);
    }
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
    import reggae.path: buildPath;

    version(Windows)
        enum cmd = `copy $in $out`;
    else
        enum cmd = `cp $in $out`;

    auto build = Build(optional(Target(buildPath("$project/../druntime", copyFileName), cmd, Target(origFileName))),
                       Target.phony(`opt`, `echo Optional!`));
    auto file = FakeFile();
    auto binary = Binary(build, getOptions(["reggae", "-b", "binary"]), file);
    binary.run(["./build", "-l"]);
    file.lines.shouldEqual(
        [
            "List of available top-level targets:",
            "- opt",
            "- " ~ buildPath(getcwd(), "../druntime/copy.txt") ~ " (optional)",
        ]
    );
}

@("command.code")
unittest {
    import std.algorithm: filter, canFind;
    import std.array: array;

    with(immutable Sandbox()) {
        auto build = Build(
            Target(
                "bar.txt",
                (in string[] inputs, in string[] outputs){ writeFile(outputs[0], "bar"); },
                Target(inSandboxPath("foo.txt"))
            ),
            Target(
                "baz.txt",
                (in string[] inputs, in string[] outputs){ writeFile(outputs[0], "baz"); },
                Target(inSandboxPath("foo.txt"))
            ),
        );
        writeFile("foo.txt");
        auto file = FakeFile();
        auto binary = Binary(
            build,
            getOptions(["reggae", "-b", "binary"]),
            file,
        );
        binary.run(["./build"]);
        writelnUt(file);
        shouldExist("bar.txt");
        shouldExist("baz.txt");
    }
}

@("binary.out-of-tree.timestamps-and-depfile") unittest {
    import reggae.path: buildPath;
    import std.datetime: Clock;
    import core.time: seconds;

    with(immutable Sandbox()) {
        const workDir = inSandboxPath("build");
        mkdirRecurse(workDir);
        writeFile("source.txt", "first");
        writeFile("build/extra.txt", "extra");
        const source = inSandboxPath("source.txt");
        const result = buildPath(workDir, "copy.txt");
        version(Windows)
            enum command = "copy $in $out";
        else
            enum command = "cp $in $out";
        auto options = getOptions(["reggae", "-b", "binary", "-C", workDir]);
        auto file = FakeFile();
        auto binary = Binary(Build(Target("copy.txt", command, Target(source))), options, file);
        auto args = ["build", "--norerun", "--single"];

        binary.run(args);
        readText(result).strip.shouldEqual("first");
        file.lines = [];
        binary.run(args);
        file.lines.shouldEqual(["[build] Nothing to do"]);

        writeFile("source.txt", "second");
        auto earlier = Clock.currTime - 2.seconds;
        setTimes(result, earlier, earlier);
        binary.run(args);
        readText(result).strip.shouldEqual("second");

        writeFile("build/copy.txt.dep", "copy.txt: extra.txt");
        const oldSource = Clock.currTime - 4.seconds;
        setTimes(source, oldSource, oldSource);
        earlier = Clock.currTime - 2.seconds;
        setTimes(result, earlier, earlier);
        file.lines = [];
        binary.run(args);
        file.lines.shouldNotEqual(["[build] Nothing to do"]);
        setTimes(buildPath(workDir, "extra.txt"), earlier, earlier);
        file.lines = [];
        binary.run(args);
        file.lines.shouldEqual(["[build] Nothing to do"]);
    }
}

@("binary.out-of-tree.creates-output-directory") unittest {
    import reggae.path: buildPath;
    import std.path: baseName;

    with(immutable Sandbox()) {
        const workDir = inSandboxPath("build");
        mkdirRecurse(workDir);
        writeFile("source.txt", "nested");
        const outputDir = "result-" ~ testPath.baseName;
        scope(exit) if(outputDir.exists) rmdirRecurse(outputDir);
        version(Windows)
            enum command = "copy $in $out";
        else
            enum command = "cp $in $out";
        auto options = getOptions(["reggae", "-b", "binary", "-C", workDir]);
        auto binary = Binary(Build(Target(buildPath(outputDir, "copy.txt"), command,
            Target(inSandboxPath("source.txt")))), options);
        binary.run(["build", "--norerun", "--single"]);
        readText(buildPath(workDir, outputDir, "copy.txt")).strip.shouldEqual("nested");
        outputDir.exists.shouldBeFalse;
    }
}
