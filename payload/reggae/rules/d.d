
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
    return dlangObjectFiles(
        sourcesToFileNames!sourcesFunc,
        compilerFlags.value,
        importPaths.value,
        stringImportPaths.value,
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
        compilerFlags.value,
        importPaths.value,
        stringImportPaths.value,
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
        compilerFlags.value,
        importPaths.value,
        stringImportPaths.value,
        [], // implicits
        projectDir.value,
    );
}



/**
   Generate object file(s) for D sources.
   Depending on command-line options compiles all files together, per package, or per module.
*/
Target[] dlangObjectFiles(in string[] srcFiles,
                          in string[] flags = [],
                          in string[] importPaths = [],
                          in string[] stringImportPaths = [],
                          Target[] implicits = [],
                          in string projDir = "$project")
    @safe
{

    import reggae.config: options;

    auto func = options.perModule
        ? &dlangObjectFilesPerModule
        : options.allAtOnce
            ? &dlangObjectFilesTogether
            : &dlangObjectFilesPerPackage;

    return func(srcFiles, flags, importPaths, stringImportPaths, implicits, projDir);
}

/// Generate object files for D sources, compiling the whole package together.
Target[] dlangObjectFilesPerPackage(in string[] srcFiles,
                                    in string[] flags = [],
                                    in string[] importPaths = [],
                                    in string[] stringImportPaths = [],
                                    Target[] implicits = [],
                                    in string projDir = "$project")
    @trusted pure
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
Target[] dlangObjectFilesPerModule(in string[] srcFiles,
                                   in string[] flags = [],
                                   in string[] importPaths = [],
                                   in string[] stringImportPaths = [],
                                   Target[] implicits = [],
                                   in string projDir = "$project")
    @trusted pure
{
    return srcFiles
        .map!(a => objectFile(const SourceFile(a),
                              const Flags(flags),
                              const ImportPaths(importPaths),
                              const StringImportPaths(stringImportPaths),
                              implicits,
                              projDir))
        .array;
}

/// Generate object files for D sources, compiling all of them together
Target[] dlangObjectFilesTogether(in string[] srcFiles,
                                  in string[] flags = [],
                                  in string[] importPaths = [],
                                  in string[] stringImportPaths = [],
                                  Target[] implicits = [],
                                  in string projDir = "$project")
    @safe pure
{
    import reggae.rules.common: objFileName;
    return dlangTargetTogether(
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
Target[] dlangStaticLibraryTogether(in string[] srcFiles,
                                    in string[] flags = [],
                                    in string[] importPaths = [],
                                    in string[] stringImportPaths = [],
                                    Target[] implicits = [],
                                    in string projDir = "$project")
    @safe
{
    import reggae.rules.common: libFileName;
    import reggae.config: options;

    /* Unlike DMD, LDC does not write static libraries directly, but writes
     * object files and archives them to a static lib.
     * Make sure the temporary object files don't collide across parallel
     * compiler invocations in the same working dir by placing the object
     * files into the library's output directory via -od.
     */
    const libFlags = options.isLdc
        ? ["-lib", "--oq", "--cleanup-obj"]
        : ["-lib"];

    return dlangTargetTogether(
        &libFileName,
        srcFiles,
        libFlags ~ flags,
        importPaths,
        stringImportPaths,
        implicits,
        projDir
    );
}


private Target[] dlangTargetTogether(
    string function(in string) @safe pure toFileName,
    in string[] srcFiles,
    in string[] flags = [],
    in string[] importPaths = [],
    in string[] stringImportPaths = [],
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
                  Flags flags = Flags(),
                  ImportPaths importPaths = ImportPaths(),
                  StringImportPaths stringImportPaths = StringImportPaths(),
                  alias linkWithFunction = () { return cast(Target[])[];})
    () @trusted
{
    auto linkWith = linkWithFunction();
    import reggae.config: options;
    return scriptlike(options.projectPath, app, flags, importPaths, stringImportPaths, linkWith);
}


//regular runtime version of scriptlike
//all paths relative to projectPath
//@trusted because of .array
Target scriptlike
    ()
    (in string projectPath,
     in App app, in Flags flags,
     in ImportPaths importPaths,
     in StringImportPaths stringImportPaths,
     Target[] linkWith)
    @trusted
{

    import reggae.dependencies: makeDeps;
    import std.path: buildPath;

    if(getLanguage(app.srcFileName.value) != Language.D)
        throw new Exception("'scriptlike' rule only works with D files");

    auto mainObj = objectFile(SourceFile(app.srcFileName.value), flags,
                              importPaths, stringImportPaths);
    const depsFile = runDCompiler(projectPath, buildPath(projectPath, app.srcFileName.value), flags.value,
                                  importPaths.value, stringImportPaths.value);

    const files = makeDeps(depsFile);
    auto dependencies = [mainObj] ~ dlangObjectFiles(files, flags.value,
                                                     importPaths.value, stringImportPaths.value);

    return link(ExeName(app.exeFileName.value), dependencies ~ linkWith);
}


// run to get dependencies
private auto runDCompiler(in string projectPath,
                          in string srcFileName,
                          in string[] flags,
                          in string[] importPaths,
                          in string[] stringImportPaths)
    @safe
{
    import reggae.config: options;
    import reggae.dependencies: makeDeps;
    import std.process: execute;
    import std.exception: enforce;
    import std.file: tempDir;
    import std.path: buildPath;
    import std.conv: text;

    immutable compiler = options.dCompiler;
    const depsFile = buildPath(tempDir, "scriptlike.dep");
    const makeDepsFlag = "-makedeps=" ~ depsFile;

    const compArgs = [compiler] ~ flags ~
        importPaths.map!(a => "-I" ~ buildPath(projectPath, a)).array ~
        stringImportPaths.map!(a => "-J" ~ buildPath(projectPath, a)).array ~
        ["-o-", makeDepsFlag, "-c", srcFileName];

    const compRes = execute(compArgs);
    enforce(compRes.status == 0,
            text("scriptlike could not run ", compArgs.join(" "), ":\n", compRes.output));
    return depsFile;
}
