/**
   Creates (maybe) a default reggaefile for a dub project.
*/
module reggae.dub.interop.reggaefile;


import reggae.from;


void maybeCreateReggaefile(T)(auto ref T output,
                              in from!"reggae.options".Options options)
{
    import std.file: exists;

    if(options.isDubProject && !options.reggaeFilePath.exists) {
        createReggaefile(output, options);
    }
}

// default build for a dub project when there is no reggaefile
private void createReggaefile(T)(auto ref T output,
                                 in from!"reggae.options".Options options)
{
    import reggae.io: log;
    import reggae.path: buildPath;
    import std.stdio: File;
    import std.string: replace;

    output.log("Creating reggaefile.d from dub information");
    auto file = File(buildPath(options.projectPath, "reggaefile.d"), "w");

    static cleanup(in string str) {
        return str.replace("\n        ", "\n");
    }

    const text = options.dubConfig == ""
        ? standardDubReggaefile
        : reducedDubReggaefile;

    file.write(text.replace("\n    ", "\n"));
}


// This is the default reggaefile for dub projects if one is not found
private enum standardDubReggaefile = q{
    import reggae;

    alias buildTarget = dubDefaultTarget!(); // dub build
    alias testTarget = dubTestTarget!();     // dub test (=> ut[.exe])

    Target aliasTarget(string aliasName, alias target)() {
        import std.algorithm: map;
        // Using a leaf target with `$builddir/<raw output>` outputs as dependency
        // yields the expected relative target names for Ninja/make.
        return Target.phony(aliasName, "", Target(target.rawOutputs.map!(o => "$builddir/" ~ o), ""));
    }

    // Add a `default` convenience alias for the `dub build` target.
    // Especially useful for Ninja (`ninja default ut` to build default & test targets in parallel).
    alias defaultTarget = aliasTarget!("default", buildTarget);

    version (Windows) {
        // Windows: extra `ut` convenience alias for `ut.exe`
        alias utTarget = aliasTarget!("ut", testTarget);
        mixin build!(buildTarget, optional!testTarget, optional!defaultTarget, optional!utTarget);
    } else {
        mixin build!(buildTarget, optional!testTarget, optional!defaultTarget);
    }
};


// This is the default reggaefile if one is not found when --dub-config is used. This speeds
// up running reggae
private enum reducedDubReggaefile = q{
    import reggae;

    alias buildTarget = dubDefaultTarget!(); // dub build

    Target aliasTarget(string aliasName, alias target)() {
        import std.algorithm: map;
        // Using a leaf target with `$builddir/<raw output>` outputs as dependency
        // yields the expected relative target names for Ninja/make.
        return Target.phony(aliasName, "", Target(target.rawOutputs.map!(o => "$builddir/" ~ o), ""));
    }

    // Add a `default` convenience alias for the `dub build` target.
    alias defaultTarget = aliasTarget!("default", buildTarget);

    mixin build!(buildTarget, optional!defaultTarget);
};
