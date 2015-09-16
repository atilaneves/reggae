module reggae.rules.c_and_cpp;

import reggae.build;
import reggae.rules.common;
import reggae.types;
import std.range;
import std.traits;


@safe:


/**
 Returns the contents of the unity build file for these source files.
 The source files have to all be in the same language and the only
 supported languages are C and C++
 */
string unityFileContents(in string projectPath, in string[] files) pure {
    import std.array;
    import std.algorithm;
    import std.path;

    if(files.empty)
        throw new Exception("Cannot perform a unity build with no files");

    immutable languages = files.map!getLanguage.array;

    if(!languages.all!(a => a == Language.C) && !languages.all!(a => a == Language.Cplusplus))
        throw new Exception("Unity build can only be done if all files are C or C++");


    return files.map!(a => `#include "` ~ buildPath(projectPath, a) ~ `"`).join("\n");
}


/**
 Returns the unity build target for these parameters.
 */
Target unityTarget(ExeName exeName,
                   string projectPath,
                   string[] files,
                   Flags flags = Flags(),
                   IncludePaths includes = IncludePaths(),
                   alias dependenciesFunc = emptyTargets,
                   alias implicitsFunc = emptyTargets,
    )() {
    return unityTarget(exeName, projectPath, files, flags, includes, dependenciesFunc());
}

Target unityTarget(R1, R2)(in ExeName exeName,
                           in string projectPath,
                           in string[] files,
                           in Flags flags = Flags(),
                           in IncludePaths includes = IncludePaths(),
                           R1 dependencies = emptyTargets(),
                           R2 implicits = emptyTargets(),

    )
    pure if(isInputRange!R1 && is(ElementType!R1 == Target) && isInputRange!R2 && is(ElementType!R2 == Target)) {

    const unityFileName = buildPath(gBuilddir, topLevelDirName(Target(exeName.value)), "unity.cpp");
    const command = compileCommand(unityFileName,
                                   flags.value,
                                   includes.value,
                                   [],
                                   projectPath,
                                   No.justCompile);
    return Target(exeName.value, command, Target(unityFileName) ~ dependencies.array);
}


private Target[] emptyTargets() {
    return [];
}
