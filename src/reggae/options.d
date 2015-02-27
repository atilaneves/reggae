module reggae.options;


struct Options {
    string backend;
    string projectPath;
    string dflags;
}


Options getOptions(string[] args) {
    import std.getopt;

    Options options;

    getopt(args,
           "backend|b", &options.backend,
           "dflags", &options.dflags,
        );

    if(args.length > 1) options.projectPath = args[1];

    return options;
}
