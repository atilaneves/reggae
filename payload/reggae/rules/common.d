module reggae.rules.common;


import reggae.build;
import reggae.config: projectPath;
import std.algorithm;
import std.path;
import std.array: array;

version(Windows) {
    immutable objExt = ".obj";
    immutable exeExt = ".exe";
} else {
    immutable objExt = ".o";
    immutable exeExt = "";
}


package string objFileName(in string srcFileName) @safe pure nothrow {
    import std.path: stripExtension, defaultExtension, isRooted, stripDrive;
    immutable localFileName = srcFileName.isRooted
        ? srcFileName.stripDrive[1..$]
        : srcFileName;
    return localFileName.stripExtension.defaultExtension(objExt);
}


Target[] srcObjects(alias func)(in string extension,
                                string[] dirs,
                                string[] srcFiles,
                                in string[] excludeFiles) {
    auto files = selectSrcFiles(srcFilesInDirs(extension, dirs), srcFiles, excludeFiles);
    return func(files);
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
    import std.path: buildNormalizedPath, buildPath;
    import std.array: array;

    DirEntry[] modules;
    foreach(dir; dirs.map!(a => buildPath(projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");
        auto entries = dirEntries(dir, "*." ~ extension, SpanMode.depth);
        auto normalised = entries.map!(a => DirEntry(buildNormalizedPath(a)));
        modules ~= array(normalised);
    }

    return modules.map!(a => a.name.removeProjectPath).array;
}

string removeProjectPath(in string path) @safe pure {
    import std.path: relativePath, absolutePath;
    return path.absolutePath.relativePath(projectPath.absolutePath);
}

@safe:
/**
 An object file, typically from one source file in a certain language
 (although for D the default is a whole package. The language is determined
 by the file extension of the file(s) passed in.
*/
Target objectFile(in string srcFileName, in string flags = "",
                  in string[] includePaths = [],
                  in string[] stringImportPaths = [],
                  in string projDir = "$project") pure {

    immutable cmd = compileCommand(srcFileName, flags, includePaths, stringImportPaths, projDir);
    return Target(srcFileName.objFileName, cmd, [Target(srcFileName)]);
}

string compileCommand(in string srcFileName,
                      in string flags = "",
                      in string[] includePaths = [],
                      in string[] stringImportPaths = [],
                      in string projDir = "$project") pure {
    immutable includeParams = includePaths.map!(a => "-I" ~ buildPath(projDir, a)).join(",");
    immutable flagParams = flags.splitter.join(",");
    immutable ruleName = getBuiltinRule(srcFileName);
    auto cmd = [ruleName, "includes=" ~ includeParams, "flags=" ~ flagParams];
    if(ruleName == "_dcompile")
        cmd ~= "stringImports=" ~ stringImportPaths.map!(a => "-J" ~ buildPath(projDir, a)).join(",");

    return cmd.join(" ");
}

private string getBuiltinRule(in string srcFileName) pure {
    switch(srcFileName.extension) {
    case ".d":
        return "_dcompile";
    case ".cpp":
    case ".CPP":
    case ".C":
    case ".cxx":
    case ".c++":
    case ".cc":
        return "_cppcompile";
    case ".c":
        return "_ccompile";
    default:
        throw new Exception("Unknown file extension " ~ srcFileName.extension);
    }
}
