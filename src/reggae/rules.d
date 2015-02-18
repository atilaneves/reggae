module reggae.rules;


import reggae.build;
import reggae.config;
import reggae.dependencies;
import std.path : baseName, stripExtension, defaultExtension, dirSeparator;
import std.algorithm: map, splitter;
import std.array: array;
import std.range: chain;

version(Windows) {
    immutable objExt = ".obj";
    immutable exeExt = ".exe";
} else {
    immutable objExt = ".o";
    immutable exeExt = "";
}


private string objFileName(in string srcFileName) @safe pure nothrow {
    return srcFileName.baseName.stripExtension.defaultExtension(objExt);
}


Target dCompile(in string srcFileName, in string flags = "", in string[] includePaths = []) @safe pure nothrow {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_dcompile " ~ includes,
                  [Target(srcFileName)]);
}


Target cppCompile(in string srcFileName, in string flags = "",
                  in string[] includePaths = []) @safe pure nothrow {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_cppcompile " ~ includes,
                  [Target(srcFileName)]);
}


Target cCompile(in string srcFileName, in string flags = "",
                in string[] includePaths = []) @safe pure nothrow {
    return cppCompile(srcFileName, flags, includePaths);
}


mixin template dExe(App app, Flags flags = Flags(),
                    ImportPaths importPaths = ImportPaths(),
                    StringImportPaths stringImportPaths = StringImportPaths(),
                    Target[] linkWith = []) {
    auto buildFunc() {
        return Build(dExeImpl(app, flags, importPaths, stringImportPaths, linkWith));
    }
}
//@trusted because of .array
Target dExeImpl(in App app, in Flags flags,
                in ImportPaths importPaths,
                in StringImportPaths stringImportPaths,
                in Target[] linkWith) @trusted {

    const dependencies = dSources(buildPath(projectPath, app.srcFileName), flags.flags,
                                  importPaths.paths.map!(a => buildPath(projectPath, a)).array,
                                  stringImportPaths.paths.map!(a => buildPath(projectPath, a)).array);
    return Target(app.exeFileName, "_dlink", dependencies ~ linkWith);
}


private Target[] dSources(in string srcFileName, in string flags,
                          in string[] importPaths, in string[] stringImportPaths) @safe {

    const noProjectIncludes = importPaths.map!removeProjectPath.array;
    auto mainObj = dCompile(srcFileName.removeProjectPath, flags, noProjectIncludes);

    Target depCompile(in string dep) @safe nothrow {
        return dCompile(dep.removeProjectPath, flags, noProjectIncludes);
    }

    const output = runCompiler(srcFileName, flags, importPaths, stringImportPaths);
    return [mainObj] ~ dMainDependencies(output).map!depCompile.array;
}


//@trusted because of splitter
private auto runCompiler(in string srcFileName, in string flags,
                         in string[] importPaths, in string[] stringImportPaths) @trusted {

    import std.process: execute;
    import std.exception: enforce;
    import std.conv:text;

    immutable compiler = "dmd";
    const compArgs = [compiler] ~ flags.splitter.array ~ importPaths.map!(a => "-I" ~ a).array ~
        stringImportPaths.map!(a => "-J" ~ a).array ~ ["-o-", "-v", "-c", srcFileName];
    const compRes = execute(compArgs);
    enforce(compRes.status == 0, text("dExe could not run ", compArgs.join(" "), ":\n", compRes.output));
    return compRes.output;
}

//@trusted becaue of replace
string removeProjectPath(in string path) @trusted pure nothrow {
    return path.replace(projectPath ~ dirSeparator, "");
}
