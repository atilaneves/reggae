/**
High-level rules for compiling D files. For a D-only application with
no dub dependencies, $(D scriptlike) should suffice. If the app depends
on dub packages, consult the reggae.rules.dub module instead.
 */

module reggae.rules.d;

import reggae.types;
import reggae.build;
import reggae.path: buildPath;
import reggae.sorting;
import reggae.rules.common;
import std.algorithm;
import std.array;


Target[] dlangObjects(
    alias sourcesFunc = Sources!(),
    CompilerFlags compilerFlags = CompilerFlags(),
    ImportPaths importPaths = ImportPaths(),
    StringImportPaths stringImportPaths = StringImportPaths(),
    ProjectDir projectDir = ProjectDir(),
    )
    ()
{
    import reggae.config: options;
    return dlangObjectFiles(
        options,
        sourcesToFileNames!sourcesFunc(options),
        compilerFlags,
        importPaths,
        stringImportPaths,
        [], // implicits
        projectDir.value,
    );
}


Target[] dlangObjectsPerPackage(
    alias sourcesFunc = Sources!(),
    CompilerFlags compilerFlags = CompilerFlags(),
    ImportPaths importPaths = ImportPaths(),
    StringImportPaths stringImportPaths = StringImportPaths(),
    ProjectDir projectDir = ProjectDir(),
    )
    ()
{
    return dlangObjectFilesPerPackage(
        sourcesToFileNames!sourcesFunc,
        compilerFlags,
        importPaths,
        stringImportPaths,
        [], // implicits
        projectDir.value,
    );
}

Target[] dlangObjectsPerModule(
    alias sourcesFunc = Sources!(),
    CompilerFlags compilerFlags = CompilerFlags(),
    ImportPaths importPaths = ImportPaths(),
    StringImportPaths stringImportPaths = StringImportPaths(),
    ProjectDir projectDir = ProjectDir(),
    )
    ()
{
    return dlangObjectFilesPerModule(
        sourcesToFileNames!sourcesFunc,
        compilerFlags,
        importPaths,
        stringImportPaths,
        [], // implicits
        projectDir.value,
    );
}


/**
   Generate object file(s) for D sources.
   Depending on command-line options compiles all files together, per package, or per module.
*/
Target[] dlangObjectFiles(
    in imported!"reggae.options".Options options,
    in string[] srcFiles,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths importPaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    Target[] implicits = [],
    in string projDir = "$project")
    @safe pure
{

    auto func = dlangObjectFilesFunc(options);
    return func(options, srcFiles, flags, importPaths, stringImportPaths, implicits, projDir);
}

/**
   Returns a function that compiles D sources in the manner specified by the user
   in the command-line options.
 */
auto dlangObjectFilesFunc(in imported!"reggae.options".Options options) @safe pure nothrow {
    return options.perModule
        ? &dlangObjectFilesPerModule
        : options.allAtOnce
            ? &dlangObjectFilesTogether
            : &dlangObjectFilesPerPackage;
}



/// Generate object files for D sources, compiling the whole package together.
Target[] dlangObjectFilesPerPackage(
    in imported!"reggae.options".Options options,
    in string[] srcFiles,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths importPaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    Target[] implicits = [],
    in string projDir = "$project")
    @safe pure
{

    if(srcFiles.empty) return [];

    // the object file for a D package containing pkgFiles
    static string outputFileName(in string[] pkgFiles) {
        import std.path: baseName;
        const path = packagePath(pkgFiles[0]) ~ "_" ~ pkgFiles[0].baseName(".d");
        return objFileName(path);
    }

    auto target(in string[] files) {
        auto incompleteTarget = Target(
            outputFileName(files),
            "", // filled in by compilerTarget below
            files.map!(a => Target(a)).array,
            implicits,
        );
        return compileTarget(
            options,
            incompleteTarget,
            files[0].packagePath ~ ".d",
            flags,
            importPaths,
            stringImportPaths,
            projDir,
        );
    }

    return srcFiles
        .byPackage
        .map!target
        .array;
}

/// Generate object files for D sources, compiling each module separately
Target[] dlangObjectFilesPerModule(
    in imported!"reggae.options".Options options,
    in string[] srcFiles,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths importPaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    Target[] implicits = [],
    in string projDir = "$project")
    @trusted /*TODO: std.array.array*/ pure
{
    return srcFiles
        .map!(a => objectFile(options,
                              const SourceFile(a),
                              flags,
                              importPaths,
                              stringImportPaths,
                              implicits,
                              projDir))
        .array;
}

/// Generate object files for D sources, compiling all of them together
Target[] dlangObjectFilesTogether(
    in imported!"reggae.options".Options options,
    in string[] srcFiles,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths importPaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    Target[] implicits = [],
    in string projDir = "$project")
    @safe pure
{
    import reggae.rules.common: objFileName;
    return dlangTargetTogether(
        options,
        &objFileName,
        srcFiles,
        flags,
        importPaths,
        stringImportPaths,
        implicits,
        projDir
    );
}


/**
   Generate a static library for D sources, compiling all of them together.
   With dmd, this results in a different static library than compiling the
   source into object files then using `ar` to create the .a.
*/
Target[] dlangStaticLibraryTogether(
    in imported!"reggae.options".Options options,
    in string[] srcFiles,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths importPaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    Target[] implicits = [],
    in string projDir = "$project")
    @safe pure
{
    import reggae.rules.common: libFileName;

    // for ldc2, mimic ldmd2: uniquely-name and remove the temporary object files
    const libFlags = options.isLdc
        ? ["-lib", "-oq", "-cleanup-obj"]
        : ["-lib"];

    return dlangTargetTogether(
        options,
        &libFileName,
        srcFiles,
        const CompilerFlags(libFlags ~ flags.value),
        importPaths,
        stringImportPaths,
        implicits,
        projDir
    );
}


private Target[] dlangTargetTogether(
    in imported!"reggae.options".Options options,
    string function(in string) @safe pure toFileName,
    in string[] srcFiles,
    in CompilerFlags flags = CompilerFlags(),
    in ImportPaths importPaths = ImportPaths(),
    in StringImportPaths stringImportPaths = StringImportPaths(),
    Target[] implicits = [],
    in string projDir = "$project",
    )
    @safe pure
{
    if(srcFiles.empty) return [];

    // when building a .o or .a for multiple source files, this generates a name
    // designed to avoid filename clashes (see arsd-official)
    string outputNameForSrcFiles() @safe pure {
        import reggae.sorting: packagePath;
        import std.array: join;
        import std.path: stripExtension, baseName;
        import std.range: take;

        // then number in `take` is arbitrary but larger than 1 to try to get
        // unique file names without making the file name too long.
        const name = srcFiles
            .take(4)
            .map!baseName
            .map!stripExtension
            .join("_")

            ~ ".d";
        return packagePath(srcFiles[0]) ~ "_" ~ name;
    }

    const outputFileName = toFileName(outputNameForSrcFiles);
    auto incompleteTarget = Target(
        outputFileName,
        "", // filled in by compilerTarget below
        srcFiles.map!(a => Target(a)).array,
        implicits,
    );

    auto target = compileTarget(
        options,
        incompleteTarget,
        srcFiles[0],
        flags,
        importPaths,
        stringImportPaths,
        projDir,
    );


    return [target];
}



/**
 Currently only works for D. This convenience rule builds a D scriptlike, automatically
 calculating which files must be compiled in a similar way to rdmd.
 All paths are relative to projectPath.
 This template function is provided as a wrapper around the regular runtime version
 below so it can be aliased without trying to call it at runtime. Basically, it's a
 way to use the runtime scriptlike without having define a function in reggaefile.d,
 i.e.:
 $(D
 alias myApp = scriptlike!(...);
 mixin build!(myApp);
 )
 vs.
 $(D
 Build myBuld() { return scriptlike(..); }
 )
 */
Target scriptlike(App app,
                  CompilerFlags flags = CompilerFlags(),
                  ImportPaths importPaths = ImportPaths(),
                  StringImportPaths stringImportPaths = StringImportPaths(),
                  alias linkWithFunction = imported!"reggae.rules.common".emptyTargets)
    () @trusted
{
    auto linkWith = linkWithFunction();
    import reggae.config: options;
    return scriptlike(options, options.projectPath, app, flags, importPaths, stringImportPaths, linkWith);
}


//regular runtime version of scriptlike
//all paths relative to projectPath
//@trusted because of .array
Target scriptlike(
    in imported!"reggae.options".Options options,
    in string projectPath,
    in App app, in CompilerFlags flags,
    in ImportPaths importPaths,
    in StringImportPaths stringImportPaths,
    Target[] linkWith)
    @safe
{

    import reggae.dependencies: parseDepFile;
    import std.path: buildPath;

    if(getLanguage(app.srcFileName.value) != Language.D)
        throw new Exception("'scriptlike' rule only works with D files");

    auto mainObj = objectFile(options, SourceFile(app.srcFileName.value), flags,
                               importPaths, stringImportPaths);
    const depsFile = runDCompiler(
        options,
        projectPath,
        buildPath(projectPath, app.srcFileName.value),
        flags.value,
        importPaths.value,
        stringImportPaths.value
   );

    const files = parseDepFile(depsFile);
    auto dependencies = [mainObj] ~ dlangObjectFiles(
        options,
        files,
        flags,
        importPaths,
        stringImportPaths,
    );

    return link(TargetName(app.exeFileName.value), dependencies ~ linkWith);
}


// run to get dependencies
private auto runDCompiler(in imported!"reggae.options".Options options,
                          in string projectPath,
                          in string srcFileName,
                          in string[] flags,
                          in string[] importPaths,
                          in string[] stringImportPaths)
    @safe
{
    import std.process: execute;
    import std.exception: enforce;
    import std.file: tempDir;
    import std.path: buildPath;
    import std.conv: text;

    immutable compiler = options.dCompiler;
    const depsFile = buildPath(tempDir, "scriptlike.dep");
    const makeDepsFlag = "-makedeps=" ~ depsFile;

    const compArgs = [compiler.idup] ~ flags ~
        importPaths.map!(a => "-I" ~ buildPath(projectPath, a)).array ~
        stringImportPaths.map!(a => "-J" ~ buildPath(projectPath, a)).array ~
        ["-o-", makeDepsFlag, "-c", srcFileName.idup];

    const compRes = execute(compArgs);
    enforce(compRes.status == 0,
            text("scriptlike could not run ", compArgs.join(" "), ":\n", compRes.output));
    return depsFile;
}

Target dlink(in TargetName targetName, Target[] dependencies, in LinkerFlags flags = LinkerFlags()) @safe pure {
    import reggae.rules.common: link;
    return link(
        targetName,
        dependencies,
        LinkerFlags(flags.value ~ maybeLibFlags(targetName.value))
    );
}


private string[] maybeLibFlags(in string targetName) @safe pure {
    import reggae.rules.common: libExt, dynExt;
    import std.path: extension;

    const maybeStatic = targetName.extension == libExt
        ? ["-lib"]
        : [];
    auto maybeShared = targetName.extension == dynExt
        ? ["-shared"]
        : [];

    return maybeStatic ~ maybeShared;
}
