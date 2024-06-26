#!/usr/bin/env rdmd
// Lists the D files that are reggae's "payload": the files it writes
// when it runs that are required to compile the reggaefile.

int main(string[] args) {
    try {
        run(args);
        return 0;
    } catch(Throwable t) {
        import std.stdio: stderr;
        stderr.writeln("Error: ", t.msg);
        return 1;
    }
}

void run(string[] args) {
    import std.file: dirEntries, SpanMode, readText, exists;
    import std.stdio: File;
    import std.algorithm: filter, map;
    import std.path: buildPath, pathSeparator;
    import std.conv: text;

    import std.stdio;
    args[0].writeln;

    const outputDir = args.length > 1
        ? args[1]
        : ".";

    // not using buildPath to guarantee the path separator at the end
    enum prefix = "payload" ~ pathSeparator ~ "reggae" ~ pathSeparator;
    auto entries = dirEntries("payload", SpanMode.breadth)
        .filter!(de => !de.isDir)
        .map!(de => de.name[prefix.length .. $]);

    const output = text(entries, "\n");
    const outputFileName = buildPath(outputDir, "payload.txt");
    if(outputFileName.exists && outputFileName.readText == output)
        return;

    auto file = File(outputFileName, "w");
    file.write(output);
}
