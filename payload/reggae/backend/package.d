module reggae.backend;

public import reggae.backend.binary;

version(minimal) {
} else {
    public import reggae.backend.ninja;
    public import reggae.backend.make;
    public import reggae.backend.tup;
}

package string[] maybeAddDirDependencies(
    in imported!"reggae.build".Target target,
    in string projectPath)
    @safe pure
{
    import reggae.build: Target, CommandType;
    import std.algorithm: filter, map, sort, uniq, joiner, canFind, among;
    import std.path: extension, dirName;
    import std.array: array;
    import std.format: format;

    with(CommandType)
        if(!target.getCommandType.among(compile, compileAndLink))
            return[];

    const outputs = target.expandOutputs(projectPath);

    static bool isSrcFile(in Target t) {
        return t.rawOutputs.length == 1
            && t.dependencyTargets.length == 0
            && t.rawOutputs[0].extension.among(".d", ".di", "c", "cpp", "CPP", "cc", "cxx", "C", "c++");
    }

    auto srcs = target
        .dependencyTargets
        .filter!isSrcFile;

    if(srcs.empty)
        return [];

    return srcs
        .map!(t => t.expandOutputs(projectPath)[0])
        .map!dirName
        .trustedArray;
}

// TODO: fix std.array.array
private auto trustedArray(R)(auto ref scope R rng) @trusted {
    import std.array: array;
    return rng.array;
}

private alias Options = imported!"reggae.options".Options;

// What the generated build files run when any of the build
// description's dependencies (including the source directories) is out
// of date. `--rerun-check` only actually reruns reggae if the build
// description could have changed - see `rerunIsNeeded`.
package string rerunCommand(in Options options) @safe pure {
    string[] args = [options.ranFromPath, "--rerun-check"];
    if(options.rerunArgs.length > 1)
        args ~= options.rerunArgs[1 .. $];
    return flattenShellArgs(args);
}

/**
   Whether reggae needs to be rerun to regenerate the build files.

   Editing an existing source file bumps its directory's timestamp
   (editors that save via a temporary file rename do this), which makes
   make/ninja invoke the rerun command, but the build description only
   changes if files were added or removed. So compare the current set
   of files in the source directories against the set recorded when the
   build was generated, and check if the build description itself (the
   reggaefile and its dependencies) is newer than the generated build.
 */
bool rerunIsNeeded(in Options options) @safe {
    import std.file: exists, timeLastModified;

    const buildFile = buildFilePath(options);
    if(buildFile is null || !buildFile.exists)
        return true;

    const buildFileTime = buildFile.timeLastModified;
    foreach(dep; options.reggaeFileDependencies)
        if(!dep.exists || dep.timeLastModified > buildFileTime)
            return true;

    const state = readRerunState(options);
    return scanSrcFiles(options.workingDir, state.srcDirs) != state.srcFiles;
}

// Called when `rerunIsNeeded` returns false. Make would otherwise run
// the rerun check on every invocation since the source directories
// stay newer than the Makefile, so bump the latter's timestamp. Ninja
// needs no equivalent (and the file must not be touched so that
// `restat = 1` does its job).
void skipRerun(in Options options) @safe {
    import reggae.types: Backend;
    import std.datetime.systime: Clock;
    import std.file: setTimes;

    if(options.backend == Backend.make) {
        const now = Clock.currTime;
        setTimes(buildFilePath(options), now, now);
    }
}

private string buildFilePath(in Options options) @safe pure {
    import reggae.path: buildPath;
    import reggae.types: Backend;

    final switch(options.backend) with(Backend) {
        case make:
            return buildPath(options.workingDir, "Makefile");
        case ninja:
            return buildPath(options.workingDir, "build.ninja");
        case none:
        case tup:
        case binary:
            return null;
    }
}

private struct RerunState {
    string[] srcDirs;
    string[] srcFiles;
}

private string rerunStatePath(in Options options) @safe pure {
    import reggae.options: hiddenDir;
    import reggae.path: buildPath;
    return buildPath(options.workingDir, hiddenDir, "rerun-state.json");
}

// throws if the state file doesn't exist or can't be parsed, which
// callers treat as "rerun needed"
private RerunState readRerunState(in Options options) @safe {
    import std.algorithm: map;
    import std.array: array;
    import std.file: readText;
    import std.json: parseJSON;

    auto json = parseJSON(readText(rerunStatePath(options)));
    RerunState ret;
    ret.srcDirs = json.objectNoRef["srcDirs"].arrayNoRef.map!(a => a.str).array;
    ret.srcFiles = json.objectNoRef["srcFiles"].arrayNoRef.map!(a => a.str).array;
    return ret;
}

package void writeRerunState(in Options options, in string[] srcDirs) @safe {
    import std.algorithm: sort, uniq;
    import std.array: array;
    import std.file: mkdirRecurse;
    import std.json: JSONValue;
    import std.path: dirName;
    import std.stdio: File;

    // exported builds don't rerun reggae
    if(options.export_)
        return;

    const statePath = rerunStatePath(options);
    mkdirRecurse(statePath.dirName);

    auto sortedSrcDirs = srcDirs.dup.sort.uniq.array;
    auto json = JSONValue([
        "srcDirs": JSONValue(sortedSrcDirs),
        "srcFiles": JSONValue(scanSrcFiles(options.workingDir, sortedSrcDirs)),
    ]);

    auto file = File(statePath, "w");
    file.write(json.toString);
}

// All directory entries in the source directories, including ones a
// build description might not care about (e.g. editor backup files):
// whether a given file matters can only be known by actually running
// the build description, so over-approximate and rerun in that case.
// Relative source directories mean what they mean in the generated
// build files, i.e. relative to where make/ninja run, so resolve them
// against the working directory instead of the current one.
private string[] scanSrcFiles(in string workingDir, in string[] srcDirs) @safe {
    import reggae.path: buildPath;
    import std.algorithm: sort, uniq;
    import std.array: array;
    import std.file: exists, isDir;
    import std.path: isAbsolute;

    string[] ret;
    foreach(dir; srcDirs) {
        const absDir = dir.isAbsolute ? dir : buildPath(workingDir, dir);
        if(absDir.exists && absDir.isDir)
            ret ~= dirEntryNames(absDir);
    }

    return ret.sort.uniq.array;
}

private string[] dirEntryNames(in string dir) @trusted {
    import std.algorithm: map;
    import std.array: array;
    import std.file: dirEntries, SpanMode;
    return dirEntries(dir, SpanMode.shallow).map!(e => e.name).array;
}

package string flattenShellArgs(in string[] args) @safe pure {
    import std.algorithm: canFind, map;
    import std.array: join, replace;

    static string quoteArgIfNeeded(string a) {
        return !a.canFind(' ') ? a : `"` ~ a.replace(`"`, `\"`) ~ `"`;
    }

    return args.map!quoteArgIfNeeded.join(" ");
}
