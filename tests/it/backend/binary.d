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
