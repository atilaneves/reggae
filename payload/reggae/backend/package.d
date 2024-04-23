module reggae.backend;

public import reggae.backend.binary;

version(minimal) {
} else {
    public import reggae.backend.ninja;
    public import reggae.backend.make;
    public import reggae.backend.tup;
}

package string[] maybeAddDirDependencies(
    in imported!"reggae.build".Target target,
    in string projectPath)
    @safe pure
{
    import reggae.build: Target, CommandType;
    import std.algorithm: filter, map, sort, uniq, joiner, canFind, among;
    import std.path: extension, dirName;
    import std.array: array;
    import std.format: format;

    with(CommandType)
        if(!target.getCommandType.among(compile, compileAndLink))
            return[];

    const outputs = target.expandOutputs(projectPath);

    static bool isSrcFile(in Target t) {
        return t.rawOutputs.length == 1
            && t.dependencyTargets.length == 0
            && t.rawOutputs[0].extension.among(".d", ".di", "c", "cpp", "CPP", "cc", "cxx", "C", "c++");
    }

    auto srcs = target
        .dependencyTargets
        .filter!isSrcFile;

    if(srcs.empty)
        return [];

    return srcs
        .map!(t => t.expandOutputs(projectPath)[0])
        .map!dirName
        .trustedArray;
}

// TODO: fix std.array.array
auto trustedArray(R)(auto ref scope R rng) @trusted {
    import std.array: array;
    return rng.array;
}
