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

//dCompileCommand, cCompile, cppCompile and dLink are the only default rules
//They work by serialising the rule to use piggy-backing on Target's string
//command attribute. It's horrible, but it works with the original decision
//of using strings as commands. Should be changed to be a sum type where
//a string represents a shell command and other variants call D code.
Target[] dCompileGrouped(in string[] srcFiles, in string flags = "",
                         in string[] importPaths = [], in string[] stringImportPaths = [],
                         in string projDir = "$project") @safe {
    import reggae.config;
    auto func = perModule ? &dCompilePerModule : &dCompilePerPackage;
    return func(srcFiles, flags, importPaths, stringImportPaths, projDir);
}

Target[] dCompilePerPackage(in string[] srcFiles, in string flags = "",
                            in string[] importPaths = [], in string[] stringImportPaths = [],
                            in string projDir = "$project") @safe {

    immutable command = compileCommand(srcFiles[0], flags, importPaths, stringImportPaths, projDir);
    return srcFiles.byPackage.map!(a => Target(a[0].packagePath.objFileName,
                                               command,
                                               a.map!(a => Target(a)).array)).array;
}

Target[] dCompilePerModule(in string[] srcFiles, in string flags = "",
                           in string[] importPaths = [], in string[] stringImportPaths = [],
                           in string projDir = "$project") @safe {

    immutable command = compileCommand(srcFiles[0], flags, importPaths, stringImportPaths, projDir);
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
        return dCompileGrouped(files, flags.value, ["."] ~ includes.value, stringImports.value);
    }

    return srcObjects!dCompileInner("d", dirs.value, srcFiles.value, excludeFiles.value);
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

    auto mainObj = objectFile(app.srcFileName, flags.value, importPaths.value, stringImportPaths.value);
    const output = runDCompiler(buildPath(projectPath, app.srcFileName), flags.value,
                                importPaths.value, stringImportPaths.value);

    const files = dMainDepSrcs(output).map!(a => a.removeProjectPath).array;
    const dependencies = [mainObj] ~ dCompileGrouped(files, flags.value,
                                                     importPaths.value, stringImportPaths.value);

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
