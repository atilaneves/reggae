module reggae.rules.common;


import reggae.build;
import reggae.config: options;
import reggae.ctaa;
import reggae.types;
import std.algorithm;
import std.path;
import std.array: array;
import std.traits;

version(Windows) {
    immutable objExt = ".obj";
    immutable exeExt = ".exe";
} else {
    immutable objExt = ".o";
    immutable exeExt = "";
}

package string objFileName(in string srcFileName) @safe pure {
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
    )() @trusted {

    const srcFiles = sourcesToFileNames!(sourcesFunc);
    const dSrcs = srcFiles.filter!(a => a.getLanguage == Language.D).array;
    auto otherSrcs = srcFiles.filter!(a => a.getLanguage != Language.D && a.getLanguage != Language.unknown);
    import reggae.rules.d: dlangPackageObjectFiles;
    return dlangPackageObjectFiles(dSrcs, flags.value, ["."] ~ includes.value, stringImports.value) ~
        otherSrcs.map!(a => objectFile(SourceFile(a), flags, includes)).array;
}


string[] sourcesToFileNames(alias sourcesFunc = Sources!())() @trusted {

    import std.exception: enforce;
    import std.file;
    import std.path: buildNormalizedPath, buildPath;
    import std.array: array;
    import std.traits: isCallable;

    auto srcs = sourcesFunc();

    DirEntry[] modules;
    foreach(dir; srcs.dirs.value.map!(a => buildPath(options.projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");
        auto entries = dirEntries(dir, SpanMode.depth);
        auto normalised = entries.map!(a => DirEntry(buildNormalizedPath(a)));

        modules ~= normalised.filter!(a => !a.isDir).array;
    }

    foreach(module_; srcs.files.value) {
        modules ~= DirEntry(buildNormalizedPath(buildPath(options.projectPath, module_)));
    }

    return modules.
        map!(a => a.name.removeProjectPath).
        filter!(srcs.filterFunc).
        filter!(a => a != "reggaefile.d").
        array;
}


@safe:

string removeProjectPath(in string path) pure {
    import std.path: relativePath, absolutePath;
    //relativePath is @system
    return () @trusted { return path.absolutePath.relativePath(options.projectPath.absolutePath); }();
}

/**
 An object file, typically from one source file in a certain language
 (although for D the default is a whole package. The language is determined
 by the file extension of the file passed in.
 The $(D projDir) variable is best left alone; right now only the dub targets
 make use of it (since dub packages are by definition outside of the project
 source tree).
*/
Target objectFile(in SourceFile srcFile,
                  in Flags flags = Flags(),
                  in ImportPaths includePaths = ImportPaths(),
                  in StringImportPaths stringImportPaths = StringImportPaths(),
                  in string projDir = "$project") pure {

    const cmd = compileCommand(srcFile.value, flags.value, includePaths.value, stringImportPaths.value, projDir);
    return Target(srcFile.value.objFileName, cmd, [Target(srcFile.value)]);
}


Command compileCommand(in string srcFileName,
                       in string flags = "",
                       in string[] includePaths = [],
                       in string[] stringImportPaths = [],
                       in string projDir = "$project") pure {

    string buildIncludeyPath(string path) {
        return path.startsWith(gBuilddir) ? expandBuildDir(path) : buildPath(projDir, path);
    }

    auto includeParams = includePaths.map!(a => "-I" ~ buildIncludeyPath(a)). array;
    auto flagParams = flags.splitter.array;
    immutable language = getLanguage(srcFileName);

    auto params = [assocEntry("includes", includeParams),
                   assocEntry("flags", flagParams)];

    if(language == Language.D)
        params ~= assocEntry("stringImports", stringImportPaths.map!(a => "-J" ~ buildIncludeyPath(a)).array);

    params ~= assocEntry("DEPFILE", [srcFileName.objFileName ~ ".dep"]);

    return Command(CommandType.compile, assocList(params));
}

enum Language {
    C,
    Cplusplus,
    D,
    unknown,
}

Language getLanguage(in string srcFileName) pure nothrow {
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
        return unknown;
    }
}

/**
 "Compile-time" link function.
 Its parameters are compile-time so that it can be aliased and used
 at global scope in a reggafile.
 Links an executable from the given dependency targets. The linker used
 depends on the file extension of the leaf nodes of the passed-in targets.
 If any D files are found, the linker is the D compiler, and so on with
 C++ and C. If none of those apply, the D compiler is used.
 */
Target link(ExeName exeName, alias dependenciesFunc, Flags flags = Flags())() @safe {
    auto dependencies = dependenciesFunc();
    return link(exeName, dependencies, flags);
}

/**
 Regular run-time link function.
 Links an executable from the given dependency targets. The linker used
 depends on the file extension of the leaf nodes of the passed-in targets.
 If any D files are found, the linker is the D compiler, and so on with
 C++ and C. If none of those apply, the D compiler is used.
 */
Target link(in ExeName exeName, in Target[] dependencies, in Flags flags = Flags()) @safe pure {
    const command = Command(CommandType.link, assocList([assocEntry("flags", flags.value.splitter.array)]));
    return Target(exeName.value, command, dependencies);
}

/**
 * Convenience alias for appending targets without calling any runtime function.
 * This replaces the need to manually define a function to return a `Build` struct
 * just to concatenate targets
 */
Target[] targetConcat(T...)() {
    Target[] ret;
    foreach(target; T) {
        static if(isCallable!target)
            ret ~= target();
        else
            ret ~= target;
    }
    return ret;
}

/**
 "Compile-time" target creation.
 Its parameters are compile-time so that it can be aliased and used
 at global scope in a reggaefile
 */
Target target(alias outputs,
              alias command = "",
              alias dependenciesFunc = () { Target[] ts; return ts; },
              alias implicitsFunc = () { Target[] ts; return ts; })() @trusted {

    auto depsRes = dependenciesFunc();
    auto impsRes = implicitsFunc();

    static if(isArray!(typeof(depsRes)))
        auto dependencies = depsRes;
    else
        auto dependencies = [depsRes];

    static if(isArray!(typeof(impsRes)))
        auto implicits = impsRes;
    else
        auto implicits = [impsRes];


    return Target(outputs, command, dependencies, implicits);
}


/**
 Convenience rule for creating static libraries
 */
Target[] staticLibrary(string name,
                       alias sourcesFunc = Sources!(),
                       Flags flags = Flags(),
                       ImportPaths includes = ImportPaths(),
                       StringImportPaths stringImports = StringImportPaths())
    () {

    version(Posix) {}
    else
        static assert(false, "Can only create static libraries on Posix");

    const srcFiles = sourcesToFileNames!(sourcesFunc);
    return [Target(buildPath("$builddir", name), "ar rcs $out $in",
                   targetsFromSources!(sourcesFunc, flags, includes, stringImports)())];
}
