module reggae.options;
import std.file: thisExePath;


struct Options {
    string backend;
    string projectPath;
    string dflags;
    string reggaePath;
    string[string] userVars;
}


//getopt is @system
Options getOptions(string[] args) @trusted {
    import std.getopt;

    Options options;

    getopt(args,
           "backend|b", &options.backend,
           "dflags", &options.dflags,
           "d", &options.userVars,
        );

    options.reggaePath = thisExePath();
    if(args.length > 1) options.projectPath = args[1];

    return options;
}
