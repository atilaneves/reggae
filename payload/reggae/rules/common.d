module reggae.rules.common;


import reggae.build;
import reggae.ctaa;
import reggae.path: buildPath;
import reggae.types;
import std.algorithm;
import std.array: array;
import std.traits;
import std.typecons;

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
Target[] objectFiles(alias sourcesFunc = Sources!(),
                     CompilerFlags flags = CompilerFlags(),
                     ImportPaths includes = ImportPaths(),
                     StringImportPaths stringImports = StringImportPaths(),
    )() @trusted {

    import reggae.config: options;
    const srcFiles = sourcesToFileNames!sourcesFunc(options);
    return srcFilesToObjectTargets(options, srcFiles, flags, includes, stringImports);
}

/// ditto
Target[] objectFiles
    (alias sourcesFunc = Sources!())
    (in CompilerFlags flags = CompilerFlags(),
     in ImportPaths includes = ImportPaths(),
     in StringImportPaths stringImports = StringImportPaths(),
    ) {

    import reggae.config: options;
    return objectFiles!sourcesFunc(flags, includes, stringImports);
}

/// ditto
Target[] objectFiles
    (alias sourcesFunc = Sources!())
    (
        in imported!"reggae.options".Options options,
        in CompilerFlags flags = CompilerFlags(),
        in ImportPaths includes = ImportPaths(),
        in StringImportPaths stringImports = StringImportPaths(),
    )
{
    const srcFiles = sourcesToFileNames!sourcesFunc(options);
    return srcFilesToObjectTargets(options, srcFiles, flags, includes, stringImports);
}



/**
 An object file, typically from one source file in a certain language
 (although for D the default is a whole package). The language is determined
 by the file extension of the file passed in.
 The $(D projDir) variable is best left alone; right now only the dub targets
 make use of it (since dub packages are by definition outside of the project
 source tree).
*/
Target objectFile(SourceFile srcFile,
                  CompilerFlags flags = CompilerFlags(),
                  ImportPaths includePaths = ImportPaths(),
                  StringImportPaths stringImportPaths = StringImportPaths(),
                  Target[] implicits = [],
                  string projDir = "$project")
    ()
{

    static bool isOptionsPure() @safe pure nothrow {
        import reggae.config : options;

        // reggae.config takes two forms: one when compiling reggae
        // itself, where it's fake and never used except in
        // testing. Here `options` is a function that returns a
        // mutable object.  Another form is "IRL" where `config.d` is
        // generated at "reggae-time" and where `options` is an
        // immutable struct.
        // Since this function is `pure`, testing to see if we can
        // access `options.dCompiler` differentiates between the two.
        static if(__traits(compiles, () @safe pure => options.dCompiler))
            return true;
        else
            return false;
    }

    static if(isOptionsPure) {
        import reggae.config: options;
    } else {
        import reggae.options: Options;
        enum options = Options();
    }

    return objectFile(options, srcFile, flags, includePaths, stringImportPaths, implicits, projDir);
}


/**
 An object file, typically from one source file in a certain language
 (although for D the default is a whole package). The language is determined
 by the file extension of the file passed in.
 The $(D projDir) variable is best left alone; right now only the dub targets
 make use of it (since dub packages are by definition outside of the project
 source tree).
*/
Target objectFile(
    in imported!"reggae.options".Options options,
    in SourceFile srcFile,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths includePaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    Target[] implicits = [],
    in string projDir = "$project")
    @safe pure
{

    auto incompleteTarget = Target(
        srcFile.value.objFileName,
        "", // filled in below by compileTarget
        [Target(srcFile.value.dup)],
        implicits ~ compilerBinary(options, srcFile.value)
    );

    return compileTarget(
        options,
        incompleteTarget,
        srcFile.value,
        flags,
        includePaths,
        stringImportPaths,
        projDir
    );
}

private Target[] compilerBinary(in imported!"reggae.options".Options options, in string srcFile) @safe pure nothrow {
    if(options == options.init)
        return [];

    const language = getLanguage(srcFile);
    switch(language) with(Language) {
        default:
            return [];
        case D:
            return [options.dCompiler.Target];
        case Cplusplus:
            return [options.cppCompiler.Target];
        case C:
            return [options.cCompiler.Target];
    }
}

/**
 A binary executable. The same as calling objectFiles and link
 with these parameters.
 */
Target executable(ExeName exeName,
                  alias sourcesFunc = Sources!(),
                  CompilerFlags compilerFlags = CompilerFlags(),
                  ImportPaths includes = ImportPaths(),
                  StringImportPaths stringImports = StringImportPaths(),
                  LinkerFlags linkerFlags = LinkerFlags())
    ()
{
    import reggae.types: TargetName;
    auto objs = objectFiles!(sourcesFunc, compilerFlags, includes, stringImports);
    return link!(TargetName(exeName.value), { return objs; }, linkerFlags);
}

Target executable(in imported!"reggae.options".Options options,
                  in string projectPath,
                  in string name,
                  in string[] srcDirs,
                  in string[] excDirs,
                  in string[] srcFiles,
                  in string[] excFiles,
                  in string[] compilerFlags,
                  in string[] linkerFlags,
                  in string[] includes,
                  in string[] stringImports)
    @safe
{
    auto objs = objectFiles(
        options,
        projectPath,
        srcDirs,
        excDirs,
        srcFiles,
        excFiles,
        compilerFlags,
        includes,
        stringImports
    );
    return link(TargetName(name), objs, const LinkerFlags(linkerFlags));
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
Target link(TargetName targetName, alias dependenciesFunc, LinkerFlags flags = LinkerFlags())() {
    auto dependencies = dependenciesFunc();
    return link(targetName, dependencies, flags);
}

/**
 Regular run-time link function.
 Links an executable from the given dependency targets. The linker used
 depends on the file extension of the leaf nodes of the passed-in targets.
 If any D files are found, the linker is the D compiler, and so on with
 C++ and C. If none of those apply, the D compiler is used.
 */
Target link(in TargetName targetName,
            Target[] dependencies,
            in LinkerFlags flags = LinkerFlags(),
            in LibraryFlags linkLibraryFlags = LibraryFlags())
    @safe pure
{
    auto command = Command(
        CommandType.link,
        assocList([assocEntry("flags", flags.value.dup), assocEntry("link_libraries", linkLibraryFlags.value.dup)]),
    );
    return Target(targetName.value, command, dependencies);
}

Target link(const TargetName targetName,
            Target[] dependencies,
            in LinkerFlags flags,
            Target[] implicits,
            in LibraryFlags linkLibraryFlags = LibraryFlags())
    @safe pure
{
    auto command = Command(
        CommandType.link,
        assocList([assocEntry("flags", flags.value.dup), assocEntry("link_libraries", linkLibraryFlags.value.dup)]),
    );
    return Target(targetName.value, command, dependencies, implicits);
}

/**
 Convenience rule for creating static libraries
 */
Target staticLibrary(string name,
                     alias sourcesFunc = Sources!(),
                     CompilerFlags compilerFlags = CompilerFlags(),
                     ImportPaths includes = ImportPaths(),
                     StringImportPaths stringImports = StringImportPaths(),
                     alias dependenciesFunc = emptyTargets)
    ()
{
    return staticLibraryTarget(
        name,
        objectFiles!(sourcesFunc, compilerFlags, includes, stringImports)() ~ dependenciesFunc()
    );
}

/**
 "Compile-time" target creation.
 Its parameters are compile-time so that it can be aliased and used
 at global scope in a reggaefile
 */
Target target(alias outputs,
              alias command = "",
              alias dependenciesFunc = emptyTargets,
              alias implicitsFunc = emptyTargets)() @trusted {

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
 Compile-time version of Target.phony
 */
Target phony(string name,
             string shellCommand,
             alias dependenciesFunc = emptyTargets,
             alias implicitsFunc = emptyTargets)
    ()
    if(isTargets!dependenciesFunc && isTargets!implicitsFunc)
{
    return Target.phony(name, shellCommand, arrayify!dependenciesFunc, arrayify!implicitsFunc);
}

/**
   Compile-time version of phony targeted towards running binaries
   that are dependencies of the phony rule.
 */
Target phony(
    string name,
    alias dependenciesFunc,
    string[] args = [],
    alias implicitsFunc = emptyTargets,
    )
    ()
    if(isTargets!dependenciesFunc && isTargets!implicitsFunc)
{
    import reggae.build: objDirOf;
    import std.array: join;
    import std.path: buildPath;

    auto deps = arrayify!dependenciesFunc;
    if(deps.length > 1)
        throw new Exception("Only one output allowed for this phony rule");
    if(deps[0].rawOutputs.length > 1)
        throw new Exception("Only one output allowed for this phony rule");
    auto target = deps[0];

    return Target.phony(
        name,
        (buildPath(objDirOf(Target(name)), target.rawOutputs[0]) ~ args).join(" "),
        deps,
        arrayify!implicitsFunc()
    );
}

private template isTargets(alias T) {
    import std.traits: Unqual, ReturnType, isCallable;
    import std.range: isInputRange, ElementType;
    import std.array;

    static if (is(T)) {
        enum isRangeOfTarget = isInputRange!T && is(Unqual!(ElementType!T) == Target);
        enum isTargets = isRangeOfTarget || is(Unqual!T == Target);
    } else static if (isCallable!T)
        enum isTargets = isTargets!(ReturnType!T);
}

//end of rules

private auto arrayify(alias func)() {
    import std.traits;
    auto ret = func();
    static if(isArray!(typeof(ret)))
        return ret;
    else
        return [ret];
}

auto sourcesToTargets(alias sourcesFunc = Sources!())(in imported!"reggae.options".Options options) {
    return sourcesToFileNames!sourcesFunc(options).map!(a => Target(a));
}

// Converts Sources/SourcesImpl to file names
string[] sourcesToFileNames(alias sourcesFunc = Sources!())(in imported!"reggae.options".Options options) {
    import std.exception: enforce;
    import std.file;
    import std.path: buildNormalizedPath;
    import std.array: array;
    import std.traits: isCallable;

    auto srcs = sourcesFunc();

    string[] modules;
    foreach(dir; srcs.dirs.value.map!(a => buildPath(options.projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");
        auto entries = dirEntries(dir, SpanMode.depth);
        auto normalised = entries.filter!(a => !a.isDir).map!(a => a.buildNormalizedPath);

        modules ~= normalised.array;
    }

    foreach(module_; srcs.files.value) {
        modules ~= buildNormalizedPath(buildPath(options.projectPath, module_));
    }

    return modules
        .sort
        .map!(a => removeProjectPath(options.projectPath, a))
        .filter!(srcs.filterFunc)
        .filter!(a => a != "reggaefile.d" || options.includeReggaefileInSources)
        .array
        ;

}

//run-time version
string[] sourcesToFileNames(in string projectPath,
                            in string[] srcDirs,
                            const(string)[] excDirs,
                            in string[] srcFiles,
                            in string[] excFiles) @trusted {



    import std.exception: enforce;
    import std.file;
    import std.path: absolutePath, buildNormalizedPath, dirName;
    import std.array: array;
    import std.traits: isCallable;

    excDirs = (excDirs ~ ".reggae").map!(a => buildPath(projectPath, a)).array;

    string[] files;
    foreach(dir; srcDirs.map!(a => buildPath(projectPath, a))) {
        enforce(isDir(dir), dir ~ " is not a directory name");

        auto entries = dirEntries(dir, SpanMode.depth)
                .map!(a => a.buildNormalizedPath)
                .filter!(a => !excDirs.canFind!(b => a.dirName.absolutePath.startsWith(b)));
        files ~= entries.array;
    }

    foreach(module_; srcFiles) {
        files ~= buildNormalizedPath(buildPath(projectPath, module_));
    }

    return files.sort.
        map!(a => removeProjectPath(projectPath, a)).
        filter!(a => !excFiles.canFind(a)).
        filter!(a => a != "reggaefile.d").
        array;
}


//run-time version
Target[] objectFiles(
    in imported!"reggae.options".Options options,
    in string projectPath,
    in string[] srcDirs,
    in string[] excDirs,
    in string[] srcFiles,
    in string[] excFiles,
    in string[] flags = [],
    in string[] includes = [],
    in string[] stringImports = [])
    @trusted
{

    return srcFilesToObjectTargets(
        options,
        sourcesToFileNames(projectPath, srcDirs, excDirs, srcFiles, excFiles),
        const CompilerFlags(flags),
        const ImportPaths(includes),
        const StringImportPaths(stringImports)
    );
}

//run-time version
Target staticLibrary(
    in imported!"reggae.options".Options options,
    in string projectPath,
    in string name,
    in string[] srcDirs,
    in string[] excDirs,
    in string[] srcFiles,
    in string[] excFiles,
    in string[] flags,
    in string[] includes,
    in string[] stringImports)
    @trusted
{
    return staticLibraryTarget(
        name,
        objectFiles(
            options,
            projectPath,
            srcDirs,
            excDirs,
            srcFiles,
            excFiles,
            flags,
            includes,
            stringImports
        )
    );
}

Target staticLibraryTarget(in string name, Target[] objects) @safe {
    import std.path: defaultExtension;
    return Target(
        [buildPath("$builddir", defaultExtension(name, libExt))],
        staticLibraryShellCommand,
        objects,
    );
}

Target staticLibraryTarget(in string name, Target[] objects, Target[] implicits) @safe {
    import std.path: defaultExtension;
    return Target(
        [buildPath("$builddir", defaultExtension(name, libExt))],
        staticLibraryShellCommand,
        objects,
        implicits
    );
}

private string staticLibraryShellCommand() @safe {
    version(Windows) {
        import reggae.options: resolveExecutable;

        static string libExe;
        if (!libExe.length)
            libExe = resolveExecutable("lib.exe");

        return `"` ~ libExe ~ `" /OUT:$out $in`;
    } else {
        return "ar rcs $out $in";
    }
}

Target[] srcFilesToObjectTargets(
    in imported!"reggae.options".Options options,
    in string[] srcFiles,
    in CompilerFlags flags,
    in ImportPaths includes,
    in StringImportPaths stringImports) {

    const dSrcs = srcFiles.filter!(a => a.getLanguage == Language.D).array;
    auto otherSrcs = srcFiles.filter!(a => a.getLanguage != Language.D && a.getLanguage != Language.unknown);
    import reggae.rules.d: dlangObjectFiles;
    return
        dlangObjectFiles(options, dSrcs, flags, ImportPaths(["."] ~ includes.value), stringImports) ~
        otherSrcs.map!(a => objectFile(options, SourceFile(a), flags, includes)).array;
}


version(Windows) {
    immutable objExt = ".obj";
    immutable exeExt = ".exe";
    immutable libExt = ".lib";
    immutable dynExt = ".dll";
} else {
    immutable objExt = ".o";
    immutable exeExt = "";
    immutable libExt = ".a";
    immutable dynExt = ".so";
}

string objFileName(in string srcFileName) @safe pure {
    return extFileName(srcFileName, objExt);
}

string libFileName(in string srcFileName) @safe pure {
    return extFileName(srcFileName, libExt);
}


string extFileName(in string srcFileName, in string extension) @safe pure {
    import reggae.path: buildPath, deabsolutePath;
    import std.path: stripExtension;
    import std.array: replace;

    auto tmp = srcFileName
        .buildPath
        .deabsolutePath
        .stripExtension
        ;

    return (tmp ~ extension).replace("..", "__");
}


string removeProjectPath(in string projectPath, const string path) @safe pure {
    import std.path: relativePath, absolutePath;
    return path.absolutePath.relativePath(projectPath.absolutePath);
}

version(unittest) {
    public Command compileCommand(
        in string srcFileName,
        in CompilerFlags flags = CompilerFlags(),
        in ImportPaths includePaths = ImportPaths(),
        in StringImportPaths stringImportPaths = StringImportPaths(),
        in string projDir = "$project",
        Flag!"justCompile" justCompile = Yes.justCompile)
        @safe pure
    {
        return compileCommandImpl(srcFileName, flags, includePaths, stringImportPaths, projDir, justCompile);
    }
}

// The reason this is needed is to have one and only one API for
// creating a compilation target. Not all code goes through
// `objectFile` above, because for D compilation can happen
// all-at-once, per-package, or per-module. We want to add the
// compiler binary to the list of implicit dependencies, so this
// function takes a target that wants to add a compilation command to
// it, and we also add the compiler to the implicit dependencies.
package Target compileTarget(
    in imported!"reggae.options".Options options,
    Target target,
    in string srcFileName,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths includePaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    in string projDir = "$project",
    Flag!"justCompile" justCompile = Yes.justCompile)
    @safe pure
{
    return Target(
        target.rawOutputs,
        compileCommandImpl(
            srcFileName,
            flags,
            includePaths,
            stringImportPaths,
            projDir,
            justCompile,
        ),
        target.dependencyTargets,
        target.implicitTargets ~ compilerBinary(options, target.dependencyTargets[0].rawOutputs[0]),
    );
}


private Command compileCommandImpl(
    in string srcFileName,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths includePaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    in string projDir = "$project",
    Flag!"justCompile" justCompile = Yes.justCompile)
    @safe pure
{

    string maybeExpand(string path) {
        return expandOutput(path, projDir, projDir);
    }

    auto includeParams = includePaths
        .value
        .map!(a => "-I" ~ maybeExpand(a))
        .array;

    auto params = [
        assocEntry("includes", includeParams.dup),
        assocEntry("flags", flags.value.dup),
    ];

    params ~= assocEntry(
        "stringImports",
        stringImportPaths.value.map!(a => "-J" ~ maybeExpand(a)).array.dup
    );

    params ~= assocEntry("DEPFILE", [srcFileName.objFileName ~ ".dep"]);

    immutable type = justCompile ? CommandType.compile : CommandType.compileAndLink;
    return Command(type, assocList(params));
}


enum Language {
    C,
    Cplusplus,
    D,
    unknown,
}

Language getLanguage(in string srcFileName) @safe pure nothrow {
    import std.path: extension;

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

package Target[] emptyTargets() @safe @nogc pure nothrow {
    return null;
}
