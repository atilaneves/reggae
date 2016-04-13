// Integration tests for the binary backend
module tests.it.backend.binary;

import reggae;
import unit_threaded;
import std.file;
import std.string;


enum origFileName = "original.txt";
enum copyFileName = "copy.txt";
enum stdoutFileName = "stdout.txt";

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

@("Do nothing after build") unittest {
    import std.stdio: stdout, File;

    scope(exit) {
        remove(copyFileName);
        remove(origFileName);
    }

    writeOrigFile;
    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
    binary.run(["./build"]);
    copyFileName.exists.shouldBeTrue;

    // replace stdout so we can see what happens
    {
        auto oldStdout = stdout;
        scope(exit) stdout = oldStdout;
        stdout = File(stdoutFileName, "w");
        binary.run(["./build"]);
    }

    readText(stdoutFileName).chomp.shouldEqual("[build] Nothing to do");
    scope(exit) remove(stdoutFileName);
}
