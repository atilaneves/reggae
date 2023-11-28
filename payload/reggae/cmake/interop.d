module reggae.cmake.interop;

auto doCmakeBuild(in imported!"reggae.options".Options options) {
    import std.process : executeShell;
    import std.path : buildPath;
    import std.file : getcwd, mkdir, rmdirRecurse, exists, chdir;
    import std.format : format;
    import reggae.build : Build;

    if (!options.isCmakeProject || options.reggaeFilePath.exists)
        return Build();

    const oldcwd = getcwd;
    scope(exit) {
        oldcwd.chdir;
    }

    const buildDir = buildPath(options.projectPath, "build");
    if (buildDir.exists) {
        buildDir.rmdirRecurse;
    }

    buildDir.mkdir;
    buildDir.chdir;

    const cmd = "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON %s";

    const genJsonCompilationDB = executeShell(cmd.format(options.projectPath));
    if (genJsonCompilationDB.status != 0) {
        throw new Exception("Could not generate the 'compile_commands.json' file for the project "
                ~ options.projectPath);
    }

    return fromJSonCompilationDBToBuild(buildPath(options.projectPath, "build", "compile_commands.json"));
}

auto fromJsonToTarget(in imported!"std.json".JSONValue json) {
    import reggae.build : Target;
    import std.path : buildPath, dirSeparator;
    import std.array : replaceFirst, split, join, array;
    import std.algorithm : countUntil, setIntersection, sort, endsWith;
    import std.uni : isWhite;

    const directory = json["directory"].str;
    const file = json["file"].str;
    const originalOutput = json["output"].str;
    const originalCmd = json["command"].str;

    auto originalOutputParts = originalOutput.split(dirSeparator).sort.array;
    auto directoryParts = directory.split(dirSeparator).sort.array;
    const numCommon = setIntersection(directoryParts, originalOutputParts).array.length;
    const output = buildPath(directory.split(dirSeparator)[0 .. $ - numCommon].join(dirSeparator), originalOutput);

    auto originalCmdParts = originalCmd.split!isWhite;
    const outputIndex = originalCmdParts.countUntil!(e => e != "" && output.endsWith(e));
    const command = originalCmd.replaceFirst(file, "$in").replaceFirst(originalCmdParts[outputIndex], "$out");

    return Target(output, command, Target(file));
}

auto fromJSonCompilationDBToBuild(in string jsonDBFile) {
    import std.json : parseJSON;
    import std.file : readText;
    import std.algorithm : map;
    import std.array : array;
    import reggae.build : Build;

    auto json = readText(jsonDBFile).parseJSON;
    auto targets = json.array.map!fromJsonToTarget.array;
    return Build(targets);
}
