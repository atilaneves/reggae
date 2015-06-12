module reggae.rules.common;


import reggae.build;
import reggae.config: projectPath;
import reggae.ctaa;
import reggae.types;
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


/**
 This template function exists so as to be referenced in a reggaefile.d
 at top-level without being called via $(D alias). That way it can be
 named and used in a further $(D Target) definition without the need to
 define a function returning $(D Build).
 This function gets the source files to be compiled at runtime by searching
 for source files in the given directories, adding files and filtering
 as appropriate by the parameters given in $(D sources), its first compile-time
 parameter. The other parameters are self-explanatory.

 This function returns a list of targets that are the result of compiling
 source files written in the supported languages. The $(Sources) function
 can be used to specify source directories and source files, as well as
 a filter function to select those files that are actually wanted.
 */
Target[] targetsFromSources(alias sourcesFunc = Sources!(),
                            Flags flags = Flags(),
                            ImportPaths includes = ImportPaths(),
                            StringImportPaths stringImports = StringImportPaths(),
    )() {

    import std.exception: enforce;
    import std.file;
    import std.path: buildNormalizedPath, buildPath;
    import std.array: array;
    import std.traits: isCallable;

    auto srcs = sourcesFunc();

    DirEntry[] modules;
    foreach(dir; srcs.dirs.value.map!(a => buildPath(projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");
        auto entries = dirEntries(dir, SpanMode.depth);
        auto normalised = entries.map!(a => DirEntry(buildNormalizedPath(a)));

        modules ~= normalised.filter!(a => !a.isDir).array;
    }

    foreach(module_; srcs.files.value)
        modules ~= DirEntry(buildNormalizedPath(buildPath(projectPath, module_)));

    const srcFiles = modules.
        map!(a => a.name.removeProjectPath).
        filter!(srcs.filterFunc).
        array;

    const dSrcs = srcFiles.filter!(a => a.getLanguage == Language.D).array;
    auto otherSrcs = srcFiles.filter!(a => a.getLanguage != Language.D);

    import reggae.rules.d: objectFiles;
    return objectFiles(dSrcs, flags.value, ["."] ~ includes.value, stringImports.value) ~
        otherSrcs.map!(a => objectFile(a, flags.value, includes.value)).array;
}

@safe:

string removeProjectPath(in string path) pure {
    import std.path: relativePath, absolutePath;
    return path.absolutePath.relativePath(projectPath.absolutePath);
}

/**
 An object file, typically from one source file in a certain language
 (although for D the default is a whole package. The language is determined
 by the file extension of the file(s) passed in.
*/
Target objectFile(in string srcFileName,
                  in string flags = "",
                  in string[] includePaths = [],
                  in string[] stringImportPaths = [],
                  in string projDir = "$project") pure {

    const cmd = compileCommand(srcFileName, flags, includePaths, stringImportPaths, projDir);
    return Target(srcFileName.objFileName, cmd, [Target(srcFileName)]);
}


Command compileCommand(in string srcFileName,
                       in string flags = "",
                       in string[] includePaths = [],
                       in string[] stringImportPaths = [],
                       in string projDir = "$project") pure {
    auto includeParams = includePaths.map!(a => "-I" ~ buildPath(projDir, a)).array;
    auto flagParams = flags.splitter.array;
    immutable commandType = getCommandType(srcFileName);

    auto params = [assocEntry("includes", includeParams),
                   assocEntry("flags", flagParams)];

    if(commandType == CommandType.compileD)
        params ~= assocEntry("stringImports", stringImportPaths.map!(a => "-J" ~ buildPath(projDir, a)).array);

    params ~= assocEntry("DEPFILE", ["$out.dep"]);

    return Command(commandType, assocList(params));
}

enum Language {
    C,
    Cplusplus,
    D,
}

private Language getLanguage(in string srcFileName) pure {
    switch(srcFileName.extension) with(Language) {
    case ".d":
        return D;
    case ".cpp":
    case ".CPP":
    case ".C":
    case ".cxx":
    case ".c++":
    case ".cc":
        return Cplusplus;
    case ".c":
        return C;
    default:
        throw new Exception("Unknown file extension for file " ~ srcFileName);
    }
}

private CommandType getCommandType(in string srcFileName) pure {
    final switch(getLanguage(srcFileName)) with(Language) {
        case D:
            return CommandType.compileD;
        case Cplusplus:
            return CommandType.compileCpp;
        case C:
            return CommandType.compileC;
    }
}


/**
 Should pull its weight more in the future by automatically figuring out what
 to do. Right now only works for linking D applications using the configured
 D compiler
 */
Target link(in string exeName, in Target[] dependencies, in string flags = "") @safe pure {
    const command = Command(CommandType.link, assocList([assocEntry("flags", flags.splitter.array)]));
    return Target(exeName, command, dependencies);
}
