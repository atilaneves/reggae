module reggae.dub.interop.exec;


package string callDub(T)(
    auto ref T output,
    in imported!"reggae.options".Options options,
    in string[] rawArgs,
    imported!"std.typecons".Flag!"maybeNoDeps" maybeNoDeps = imported!"std.typecons".No.maybeNoDeps)
{
    import reggae.io: log;
    import reggae.path: buildPath;
    import std.process: execute, Config;
    import std.exception: enforce;
    import std.conv: text;
    import std.string: join, split;
    import std.file: exists;

    const hasSelections = buildPath(options.projectPath, "dub.selections.json").exists;
    string[] emptyArgs;
    const noDepsArgs = hasSelections && maybeNoDeps
        ? ["--nodeps", "--skip-registry=all"]
        : emptyArgs;
    const archArg = !options.dubArchOverride.length || rawArgs[1] == "fetch" || rawArgs[1] == "upgrade"
        ? emptyArgs
        : ["--arch=" ~ options.dubArchOverride];
    const args = rawArgs ~ noDepsArgs ~ dubEnvArgs ~ archArg;
    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    const workDir = options.projectPath;

    output.log("Calling `", args.join(" "), "`");
    const ret = execute(args, env, config, maxOutput, workDir);
    enforce(ret.status == 0,
            text("Error calling `", args.join(" "), "` (", ret.status, ")", ":\n",
                 ret.output));

    return ret.output;
}


package string[] dubEnvArgs() @safe {
    import std.process: environment;
    import std.string: split;
    return environment.get("REGGAE_DUB_ARGS", "").split(" ");
}
