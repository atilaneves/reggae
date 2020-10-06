module reggae.dub.interop.configurations;


import reggae.from;


@safe:


struct DubConfigurations {
    string[] configurations;
    string default_;
}


DubConfigurations getConfigs(O)(auto ref O output, in from!"reggae.options".Options options) {
    import reggae.io: log;
    import reggae.dub.interop.exec: dubFetch;

    try {
        return tryGetConfigs(output, options);
    } catch(Exception _) {
        output.log("Calling `dub fetch` since getting the configuration failed");
        dubFetch(output, options);
        return tryGetConfigs(output, options);
    }
}

DubConfigurations tryGetConfigs(O)(auto ref O output, in from!"reggae.options".Options options) {
    import reggae.dub.interop.exec: callDub;
    import std.typecons: Yes;

    immutable dubBuildArgs = ["dub", "--annotate", "build", "--compiler=" ~ options.dCompiler,
                              "--print-configs", "--build=docs"];
    immutable dubBuildOutput = callDub(output, options, dubBuildArgs, Yes.maybeNoDeps);
    return outputStringToConfigurations(dubBuildOutput);
}


// public because of unit tests
DubConfigurations outputStringToConfigurations(in string rawOutput) pure {

    import std.algorithm: findSkip, filter, map, canFind, startsWith;
    import std.string: splitLines, stripLeft;
    import std.array: array, replace;

    string output = rawOutput;  // findSkip mutates output
    const found = output.findSkip("Available configurations:");
    assert(found, "Could not find configurations in:\n" ~ rawOutput);
    auto configs = output
        .splitLines
        .filter!(a => a.startsWith("  "))
        .map!stripLeft
        .array;

    if(configs.length == 0) return DubConfigurations();

    enum defaultMarker = " [default]";

    string default_;
    foreach(ref config; configs) {
        if(config.canFind(defaultMarker)) {
            assert(default_ is null);
            config = config.replace(defaultMarker, "");
            default_ = config;
            break;
        }
    }

    return DubConfigurations(configs, default_);
}
