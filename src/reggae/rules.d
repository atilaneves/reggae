module reggae.rules;


import reggae.build;
import reggae.config;
import std.path : baseName, stripExtension, defaultExtension, dirSeparator;
import std.algorithm: map, splitter;
import std.array: array;


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


private string exeFileName(in string srcFileName) @safe pure nothrow {
    immutable stripped = srcFileName.baseName.stripExtension;
    return exeExt == "" ? stripped : stripped.defaultExtension(exeExt);
}


Target dCompile(in string srcFileName, in string flags = "", in string[] includePaths = []) @safe pure nothrow {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_dcompile " ~ includes,
                  [Target(srcFileName)]);
}


Target cppCompile(in string srcFileName, in string flags = "", in string[] includePaths = []) @safe pure nothrow {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_cppcompile " ~ includes,
                  [Target(srcFileName)]);
}


Target cCompile(in string srcFileName, in string flags = "", in string[] includePaths = []) @safe pure nothrow {
    return cppCompile(srcFileName, flags, includePaths);
}


//@trusted because of .array
Target dExe(in string srcFileName, in string flags = "",
            in string[] includePaths = [], in string[] stringPaths = [],
            in Target[] linkWith = []) @trusted {

    const dependencies = dSources(buildPath(projectPath, srcFileName), flags,
                                  includePaths.map!(a => buildPath(projectPath, a)).array,
                                  stringPaths.map!(a => buildPath(projectPath, a)).array);
    return Target(srcFileName.exeFileName, "_dlink", dependencies ~ linkWith);
}


//@trusted because of splitter
private Target[] dSources(in string srcFileName, in string flags,
                          in string[] includePaths, in string[] stringPaths) @trusted {

    import std.process: execute;
    import std.exception: enforce;
    import std.conv: text;
    import std.regex: ctRegex, matchFirst;

    immutable compiler = "dmd";
    const compArgs = [compiler] ~ flags.splitter.array ~ includePaths.map!(a => "-I" ~ a).array ~
        stringPaths.map!(a => "-J" ~ a).array ~ ["-o-", "-v", "-c", srcFileName];
    const compRes = execute(compArgs);
    enforce(compRes.status == 0, text("dExe could not run ", compArgs.join(" "), ":\n", compRes.output));


    Target[] dependencies = [dCompile(srcFileName.replace(projectPath ~ dirSeparator, ""),
                                      flags,
                                      includePaths.map!(a => a.replace(projectPath ~ dirSeparator, "")).array)];
    auto importReg = ctRegex!`^import +([^\t]+)\t+\((.+)\)$`;
    auto stdlibReg = ctRegex!`^(std\.|core\.|object$)`;
    foreach(line; compRes.output.splitter("\n")) {
        auto importMatch = line.matchFirst(importReg);
        if(importMatch) {
            auto stdlibMatch = importMatch.captures[1].matchFirst(stdlibReg);
            if(!stdlibMatch) {
                immutable depSrcFileName = importMatch.captures[2].replace(projectPath ~ dirSeparator, "");
                dependencies ~= dCompile(depSrcFileName, flags,
                                         includePaths.map!(a => a.replace(projectPath ~ dirSeparator, "")).array);
            }
        }
    }

    return dependencies;
}
