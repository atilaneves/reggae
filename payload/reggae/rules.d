module reggae.rules;


import reggae.build;
import reggae.config;
import reggae.dependencies;
import reggae.types;
import std.path : baseName, absolutePath, dirSeparator;
import std.algorithm: map, splitter, remove, canFind, startsWith, find;
import std.array: array, replace;
import std.range: chain;

version(Windows) {
    immutable objExt = ".obj";
    immutable exeExt = ".exe";
} else {
    immutable objExt = ".o";
    immutable exeExt = "";
}


private string objFileName(in string srcFileName) @safe pure nothrow {
    import std.path: stripExtension, defaultExtension, isRooted, stripDrive;
    immutable localFileName = srcFileName.isRooted
        ? srcFileName.stripDrive[1..$]
        : srcFileName;
    return localFileName.stripExtension.defaultExtension(objExt);
}


//@trusted because of join
Target dCompile(in string srcFileName, in string flags = "",
                in string[] importPaths = [], in string[] stringImportPaths = [],
                in string projDir = "$project") @trusted pure {

    immutable importParams = importPaths.map!(a => "-I" ~ buildPath(projDir, a)).join(",");
    immutable stringParams = stringImportPaths.map!(a => "-J" ~ buildPath(projDir, a)).join(",");
    immutable flagParams = flags.splitter.join(",");
    immutable command = ["_dcompile ", "includes=" ~ importParams, "flags=" ~ flagParams,
                         "stringImports=" ~ stringParams].join(" ");

    return Target(srcFileName.objFileName, command, [Target(srcFileName)]);
}


Target cppCompile(in string srcFileName, in string flags = "",
                  in string[] includePaths = []) @safe pure nothrow {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_cppcompile includes=" ~ includes ~ " flags=" ~ flags,
                  [Target(srcFileName)]);
}

Target cCompile(in string srcFileName, in string flags = "",
                in string[] includePaths = []) @safe pure nothrow {
    return cppCompile(srcFileName, flags, includePaths);
}

/**
 * Compile-time function to that returns a list of Target objects
 * corresponding to D source files from a particular directory
 */
Target[] dObjects(SrcDirs dirs = SrcDirs(),
                  Flags flags = Flags(),
                  ImportPaths includes = ImportPaths(),
                  StringImportPaths stringImports = StringImportPaths(),
                  SrcFiles srcFiles = SrcFiles(),
                  ExcludeFiles excludeFiles = ExcludeFiles())
    () {

    auto dCompileInner(in string srcFileName) {
        return dCompile(srcFileName, flags.flags, ["."] ~ includes.paths,
                        stringImports.paths);
    }

    return srcObjects!dCompileInner("d", dirs.paths, srcFiles.paths, excludeFiles.paths);
}

/**
 * Compile-time function to that returns a list of Target objects
 * corresponding to C++ source files from a particular directory
 */
auto cppObjects(SrcDirs dirs = SrcDirs(),
                Flags flags = Flags(),
                ImportPaths includes = ImportPaths(),
                SrcFiles srcFiles = SrcFiles(),
                ExcludeFiles excludeFiles = ExcludeFiles())
    () {

    auto cppCompileInner(in string srcFileName) {
        return cppCompile(srcFileName, flags.flags, includes.paths);
    }

    return srcObjects!cppCompileInner("cpp", dirs.paths, srcFiles.paths, excludeFiles.paths);
}


/**
 * Compile-time function to that returns a list of Target objects
 * corresponding to C source files from a particular directory
 */
auto cObjects(SrcDirs dirs = SrcDirs(),
              Flags flags = Flags(),
              ImportPaths includes = ImportPaths(),
              SrcFiles srcFiles = SrcFiles(),
              ExcludeFiles excludeFiles = ExcludeFiles())
    () {

    auto cCompileInner(in string srcFileName) {
        return cCompile(srcFileName, flags.flags, includes.paths);
    }


    return srcObjects!cCompileInner("c", dirs.paths, srcFiles.paths, excludeFiles.paths);
}


auto srcObjects(alias func)(in string extension,
                            string[] dirs, string[] srcFiles, in string[] excludeFiles) {
    auto files = selectSrcFiles(srcFilesInDirs(extension, dirs), srcFiles, excludeFiles);
    return files.map!func.array;
}

//The parameters would be "in" except that "remove" doesn't like that...
string[] selectSrcFiles(string[] dirFiles,
                        string[] srcFiles,
                        in string[] excludeFiles) @safe pure nothrow {
    return (dirFiles ~ srcFiles).remove!(a => excludeFiles.canFind(a)).array;
}

private string[] srcFilesInDirs(in string extension, in string[] dirs) {
    import std.exception: enforce;
    import std.file;
    import std.path: buildNormalizedPath;

    DirEntry[] modules;
    foreach(dir; dirs.map!(a => buildPath(projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");
        auto entries = dirEntries(dir, "*." ~ extension, SpanMode.depth);
        auto normalised = entries.map!(a => DirEntry(buildNormalizedPath(a)));
        modules ~= array(normalised);
    }

    return modules.map!(a => a.name.removeProjectPath).array;
}


//compile-time verson of dExe, to be used with alias
//all paths relative to projectPath
Target dExe(App app,
            Flags flags = Flags(),
            ImportPaths importPaths = ImportPaths(),
            StringImportPaths stringImportPaths = StringImportPaths(),
            alias linkWithFunction = () { return cast(Target[])[];})
    () {
    auto linkWith = linkWithFunction();
    return dExe(app, flags, importPaths, stringImportPaths, linkWith);
}


//regular runtime version of dExe
//all paths relative to projectPath
//@trusted because of .array
Target dExe(in App app, in Flags flags,
            in ImportPaths importPaths,
            in StringImportPaths stringImportPaths,
            in Target[] linkWith) @trusted {

    auto mainObj = dCompile(app.srcFileName, flags.flags, importPaths.paths, stringImportPaths.paths);
    const output = runDCompiler(buildPath(projectPath, app.srcFileName), flags.flags,
                                importPaths.paths, stringImportPaths.paths);

    Target depCompile(in string dep) @safe {
        return dCompile(dep.removeProjectPath, flags.flags, importPaths.paths, stringImportPaths.paths);
    }

    const dependencies = [mainObj] ~ dMainDepSrcs(output).map!depCompile.array;

    return dLink(app.exeFileName, dependencies ~ linkWith);
}


Target dLink(in string exeName, in Target[] dependencies, in string flags = "") @safe pure nothrow {
    auto cmd = "_dlink";
    if(flags != "") cmd ~= " flags=" ~ flags;
    return Target(exeName, cmd, dependencies);
}


//@trusted because of splitter
private auto runDCompiler(in string srcFileName, in string flags,
                          in string[] importPaths, in string[] stringImportPaths) @trusted {

    import std.process: execute;
    import std.exception: enforce;
    import std.conv:text;

    immutable compiler = "dmd";
    const compArgs = [compiler] ~ flags.splitter.array ~
        importPaths.map!(a => "-I" ~ buildPath(projectPath, a)).array ~
        stringImportPaths.map!(a => "-J" ~ buildPath(projectPath, a)).array ~
        ["-o-", "-v", "-c", srcFileName];
    const compRes = execute(compArgs);
    enforce(compRes.status == 0, text("dExe could not run ", compArgs.join(" "), ":\n", compRes.output));
    return compRes.output;
}

string removeProjectPath(in string path) @safe pure {
    import std.path: relativePath;
    return path.absolutePath.relativePath(projectPath.absolutePath);
}

private immutable defaultRules = ["_dcompile", "_ccompile", "_cppcompile", "_dlink"];

private bool isDefaultRule(in string command) @safe pure nothrow {
    return defaultRules.canFind(command);
}

private string getRule(in string command) @safe pure {
    return command.splitter.front;
}

bool isDefaultCommand(in string command) @safe pure {
    return isDefaultRule(command.getRule);
}

string getDefaultRule(in string command) @safe pure {
    immutable rule = command.getRule;
    if(!isDefaultRule(rule)) {
        throw new Exception("Cannot get defaultRule from " ~ command);
    }

    return rule;
}


string[] getDefaultRuleParams(in string command, in string key) @safe pure {
    return getDefaultRuleParams(command, key, false);
}


string[] getDefaultRuleParams(in string command, in string key, string[] ifNotFound) @safe pure {
    return getDefaultRuleParams(command, key, true, ifNotFound);
}


//@trusted because of replace
private string[] getDefaultRuleParams(in string command, in string key,
                                      bool useIfNotFound, string[] ifNotFound = []) @trusted pure {
    import std.conv: text;

    auto parts = command.splitter;
    immutable cmd = parts.front;
    if(!isDefaultRule(cmd)) {
        throw new Exception("Cannot get defaultRule from " ~ command);
    }

    auto fromParamPart = parts.find!(a => a.startsWith(key ~ "="));
    if(fromParamPart.empty) {
        if(useIfNotFound) {
            return ifNotFound;
        } else {
            throw new Exception ("Cannot get default rule from " ~ command);
        }
    }

    auto paramPart = fromParamPart.front;
    auto removeKey = paramPart.replace(key ~ "=", "");

    return removeKey.splitter(",").array;
}
