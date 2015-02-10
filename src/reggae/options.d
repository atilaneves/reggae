module reggae.options;


struct Options {
    string backend;
    string projectPath;
}


Options getOptions(string[] args) {
    import std.getopt;

    Options options;

    getopt(args,
           "backend|b", &options.backend,
        );

    options.projectPath = args[1];

    return options;
}
