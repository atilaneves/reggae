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

void shouldWriteToStdout(E)(lazy E expr, string[] expectedLines,
                            string file = __FILE__, size_t line = __LINE__) {
    import std.stdio: stdout, File;

    // replace stdout so we can see what happens
    auto oldStdout = stdout;
    scope(exit) stdout = oldStdout;
    stdout = File(stdoutFileName, "w");
    expr();
    remove(stdoutFileName);
}

@("Do nothing after build") unittest {
    scope(exit) {
        remove(copyFileName);
        remove(origFileName);
    }

    writeOrigFile;
    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
    binary.run(["./build"]);
    copyFileName.exists.shouldBeTrue;

    binary.run(["./build"]).shouldWriteToStdout(
        ["[build] Nothing to do"]);
}


@("Listing targets") unittest {
    import std.stdio: stdout, File;

    auto binary = Binary(binaryBuild, getOptions(["./reggae", "-b", "binary"]));
    binary.run(["./build", "-l"]).shouldWriteToStdout(
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
