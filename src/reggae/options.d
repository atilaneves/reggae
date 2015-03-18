module reggae.options;
import std.file: thisExePath;


struct Options {
    string backend;
    string projectPath;
    string dflags;
    string reggaePath;
    string[string] userVars;
    string cCompiler;
    string cppCompiler;
    string dCompiler;
}


//getopt is @system
Options getOptions(string[] args) @trusted {
    import std.getopt;

    Options options;

    getopt(args,
           "backend|b", &options.backend,
           "dflags", &options.dflags,
           "d", &options.userVars,
           "dc", &options.dCompiler,
           "cc", &options.cCompiler,
           "cxx", &options.cppCompiler,
        );

    options.reggaePath = thisExePath();
    if(args.length > 1) options.projectPath = args[1];

    if(!options.cCompiler)   options.cCompiler   = "gcc";
    if(!options.cppCompiler) options.cppCompiler = "g++";
    if(!options.dCompiler)   options.dCompiler   = "dmd";

    return options;
}
