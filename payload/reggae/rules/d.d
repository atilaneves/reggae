/**
High-level rules for compiling D files
 */

module reggae.rules.d;

import reggae.types;
import reggae.build;
import reggae.sorting;
import reggae.dependencies: dMainDepSrcs;
import reggae.rules.common;
import std.algorithm;

//objectFile, objectFiles and link are the only default rules
//They work by serialising the rule to use piggy-backing on Target's string
//command attribute. It's horrible, but it works with the original decision
//of using strings as commands. Should be changed to be a sum type where
//a string represents a shell command and other variants call D code.

//generate object file(s) for a D package. By default generates one per package,
//if reggae.config.perModule is true, generates one per module
Target[] objectFiles(in string[] srcFiles, in string flags = "",
                     in string[] importPaths = [], in string[] stringImportPaths = [],
                     in string projDir = "$project") @safe pure {
    import reggae.config;
    auto func = perModule ? &objectFilesPerModule : &objectFilesPerPackage;
    return func(srcFiles, flags, importPaths, stringImportPaths, projDir);
}

Target[] objectFilesPerPackage(in string[] srcFiles, in string flags = "",
                               in string[] importPaths = [], in string[] stringImportPaths = [],
                               in string projDir = "$project") @trusted pure {

    const command = compileCommand(srcFiles[0], flags, importPaths, stringImportPaths, projDir);
    return srcFiles.byPackage.map!(a => Target(a[0].packagePath.objFileName,
                                               command,
                                               a.map!(a => Target(a)).array)).array;
}

Target[] objectFilesPerModule(in string[] srcFiles, in string flags = "",
                              in string[] importPaths = [], in string[] stringImportPaths = [],
                              in string projDir = "$project") @trusted pure {

    return srcFiles.map!(a => objectFile(a, flags, importPaths, stringImportPaths, projDir)).array;
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

    Target[] dCompileInner(in string[] files) {
        return objectFiles(files, flags.value, ["."] ~ includes.value, stringImports.value);
    }

    return srcObjects!dCompileInner("d", dirs.value, srcFiles.value, excludeFiles.value);
}

/**
 Currently only works for D. This convenience rule builds a D executable, automatically
 calculating which files must be compiled in a similar way to rdmd.
 All paths are relative to projectPath.
 This template function is provided as a wrapper around the regular runtime version
 below so it can be aliased without trying to call it at runtime. Basically, it's a
 way to use the runtime executable without having define a function in reggaefile.d,
 i.e.:
 $(D
 alias myApp = executable!(...);
 mixin build!(myApp);
 )
 vs.
 $(D
 Build myBuld() { return executable(..); }
 )
 */
Target executable(App app,
            Flags flags = Flags(),
            ImportPaths importPaths = ImportPaths(),
            StringImportPaths stringImportPaths = StringImportPaths(),
            alias linkWithFunction = () { return cast(Target[])[];})
    () {
    auto linkWith = linkWithFunction();
    return executable(app, flags, importPaths, stringImportPaths, linkWith);
}


//regular runtime version of executable
//all paths relative to projectPath
//@trusted because of .array
Target executable(in App app, in Flags flags,
            in ImportPaths importPaths,
            in StringImportPaths stringImportPaths,
            in Target[] linkWith) @trusted {

    auto mainObj = objectFile(app.srcFileName, flags.value, importPaths.value, stringImportPaths.value);
    const output = runDCompiler(buildPath(projectPath, app.srcFileName), flags.value,
                                importPaths.value, stringImportPaths.value);

    const files = dMainDepSrcs(output).map!(a => a.removeProjectPath).array;
    const dependencies = [mainObj] ~ objectFiles(files, flags.value,
                                                 importPaths.value, stringImportPaths.value);

    return link(app.exeFileName, dependencies ~ linkWith);
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
    enforce(compRes.status == 0, text("executable could not run ", compArgs.join(" "), ":\n", compRes.output));
    return compRes.output;
}
