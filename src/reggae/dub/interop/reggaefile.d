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
    import reggae.dub.interop.exec: dubFetch;
    import std.stdio: File;
    import std.path: buildPath;
    import std.regex: regex, replaceFirst;

    output.log("Creating reggaefile.d from dub information");
    auto file = File(buildPath(options.projectPath, "reggaefile.d"), "w");

    file.writeln(q{
        import reggae;
        mixin build!(dubDefaultTarget!(), dubTestTarget!());
    }.replaceFirst(regex(`^        `), ""));

    if(!options.noFetch) dubFetch(output, options);
}
