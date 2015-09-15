module reggae.rules.c_and_cpp;

import reggae.rules.common;


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

    return files.map!(a => `#include "` ~ buildPath(projectPath, a) ~ `"`).join("\n");
}
