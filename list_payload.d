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
    const outputDir = args.length > 1
        ? args[1]
        : ".";

    listReggaePayload(outputDir);
    listDubPayload(outputDir);
}

void listReggaePayload(in string outputDir) {
    import std.file: dirEntries, SpanMode, mkdirRecurse, exists, readText;
    import std.stdio: File;
    import std.algorithm: filter, map;
    import std.path: buildPath, pathSeparator, dirName;
    import std.conv: text;

    // not using buildPath to guarantee the path separator at the end
    enum prefix = "payload" ~ pathSeparator ~ "reggae" ~ pathSeparator;
    auto entries = dirEntries("payload", SpanMode.breadth)
        .filter!(de => !de.isDir)
        .map!(de => de.name[prefix.length .. $]);

    const fileName = buildPath(outputDir, "string-imports", "reggae-payload.txt");
    if(!fileName.dirName.exists)
        fileName.dirName.mkdirRecurse;

    const toWrite = text(entries, "\n");
    if(fileName.exists && fileName.readText == toWrite) return;

    auto file = File(fileName, "w");
    file.write(toWrite);
}

void listDubPayload(in string outputDir) {
    import std.file: dirEntries, SpanMode, mkdirRecurse, exists, readText;
    import std.stdio: File;
    import std.algorithm: filter, map, startsWith;
    import std.path: buildPath, dirSeparator, dirName;
    import std.conv: text;

    // not using buildPath to guarantee the path separator at the end
    enum prefix = "dub" ~ dirSeparator ~ "source" ~ dirSeparator ~ "dub" ~ dirSeparator;
    auto entries = dirEntries(buildPath("dub", "source"), SpanMode.breadth)
        .filter!(de => !de.isDir)
        .filter!(de => de.name.startsWith(prefix))
        .map!(de => de.name[prefix.length .. $])
        ;

    const fileName = buildPath(outputDir, "string-imports", "dub-payload.txt");
    if(!fileName.dirName.exists)
        fileName.dirName.mkdirRecurse;

    const toWrite = text(entries, "\n");
    if(fileName.exists && fileName.readText == toWrite) return;

    auto file = File(fileName, "w");
    file.write(toWrite);
}
