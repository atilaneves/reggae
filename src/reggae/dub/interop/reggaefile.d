/**
   Creates (maybe) a default reggaefile for a dub project.
*/
module reggae.dub.interop.reggaefile;


import reggae.from;


auto defaultDubBuild(in from!"reggae.options".Options options) {
    import reggae.build: Build;
    import reggae.dub.interop: dubInfos;
    import std.file: exists;
    import std.stdio: stdout;

    if(!options.isDubProject || options.reggaeFilePath.exists)
        return Build();

    const configToDubInfo = dubInfos(stdout, options);

    return options.dubConfig == ""
        ? standardDubBuild(options, configToDubInfo)
        : reducedDubBuild(options, configToDubInfo);
}

private auto standardDubBuild(in from!"reggae.options".Options options, in ConfigToDubInfo configToDubInfo) {
    import reggae.build: Build, Target, optional;
    import reggae.rules.dub: dubDefaultTarget, dubTestTarget;

    auto buildTarget = dubDefaultTarget(options, configToDubInfo); // dub build
    auto testTarget = dubTestTarget(options, configToDubInfo);     // dub test

    Target aliasTarget(string aliasName, alias target)() {
        import std.algorithm: canFind, map;
        const rawOutputs = target.rawOutputs;

        // If the aliased target has an output with the same name, return a dummy target which
        // won't make it to the Ninja/make build scripts.
        // E.g., no conflicting `ut` alias target if the test target already produces a `ut` executable.
        version (Windows) { /* all outputs feature some file extension */ }
        else if (rawOutputs.canFind(aliasName) || rawOutputs.canFind("./" ~ aliasName))
            return Target(null);

        // Using a leaf target with `$builddir/<raw output>` outputs as dependency
        // yields the expected relative target names for Ninja/make.
        return Target.phony(aliasName, "", Target(rawOutputs.map!(o => "$builddir/" ~ o), ""));
    }

    // Add a `default` convenience alias for the `dub build` target.
    // Especially useful for Ninja (`ninja default ut` to build default & test targets in parallel).
    alias defaultTarget = aliasTarget!("default", buildTarget);

    // And a `ut` convenience alias for the `dub test` target.
    alias utTarget = aliasTarget!("ut", testTarget);

    return Build(buildTarget, optional(testTarget), optional(defaultTarget), optional(utTarget));
}

private auto reducedDubBuild(in from!"reggae.options".Options options, in ConfigToDubInfo configToDubInfo) {
    import reggae.build: Build, Target, optional;
    import reggae.rules.dub: dubDefaultTarget;

    auto buildTarget = dubDefaultTarget(options, configToDubInfo); // dub build

    Target aliasTarget(string aliasName, alias target)() {
        import std.algorithm: map;
        // Using a leaf target with `$builddir/<raw output>` outputs as dependency
        // yields the expected relative target names for Ninja/make.
        return Target.phony(aliasName, "", Target(target.rawOutputs.map!(o => "$builddir/" ~ o), ""));
    }

    // Add a `default` convenience alias for the `dub build` target.
    alias defaultTarget = aliasTarget!("default", buildTarget);

    return Build(buildTarget, optional(defaultTarget));
}

private alias ConfigToDubInfo = from!"reggae.dub.info".DubInfo[string];
