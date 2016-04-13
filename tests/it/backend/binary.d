// Integration tests for the binary backend
module tests.it.backend.binary;

import reggae;
import unit_threaded;
import std.file;
import std.string;


enum origFileName = "original.txt";
enum copyFileName = "copy.txt";

string stdoutFileName() {
    import std.concurrency;
    import std.conv;
    return "stdout" ~ thisTid.to!string ~ ".txt";
}

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

void shouldWriteToStdout(E)(lazy E expr, string[] expectedLines,
                            string file = __FILE__, size_t line = __LINE__) {
    import std.stdio: stdout, File;

    // replace stdout so we can see what happens
    {
        auto oldStdout = stdout;

        scope(exit) stdout = oldStdout;
        auto fileName = stdoutFileName;
        stdout = File(stdoutFileName, "w");
        expr();
    }

    auto lines = readText(stdoutFileName).chomp.split("\n");
    scope(exit) remove(stdoutFileName);
    lines.shouldEqual(expectedLines, file, line);
}

@("Do nothing after build") unittest {
    scope(exit) {
        remove(copyFileName);
        remove(origFileName);
    }

    writeOrigFile;

    {
        auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
        binary.run(["./build"]);
        copyFileName.exists.shouldBeTrue;
    }

    {
        import std.stdio: File;
        auto file = File(stdoutFileName, "w");
        auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]), file);
        binary.run(["./build"]);
    }

    scope(exit) remove(stdoutFileName);
    readText(stdoutFileName).chomp.split("\n").shouldEqual(
        ["[build] Nothing to do"]);
}

@("Listing targets") unittest {
    import std.stdio: stdout, File;

    {
        auto file = File(stdoutFileName, "w");
        auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]), file);
        binary.run(["./build", "-l"]);
    }

    scope(exit) remove(stdoutFileName);
    readText(stdoutFileName).chomp.split("\n").shouldEqual(
        ["List of available top-level targets:",
         "- copy.txt",
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
