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
    bool help;
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
           "help|h", &options.help,
        );

    if(options.help) {
        writeHelp;
    }

    options.reggaePath = thisExePath();
    if(args.length > 1) options.projectPath = args[1];

    if(!options.cCompiler)   options.cCompiler   = "gcc";
    if(!options.cppCompiler) options.cppCompiler = "g++";
    if(!options.dCompiler)   options.dCompiler   = "dmd";

    return options;
}

void writeHelp() {
    import std.stdio;
    writeln("Usage: reggae -b <ninja|make> </path/to/project>");
    writeln("Options: ");
    writeln("  -h/--help: help");
    writeln("  -d: User-defined variables (-d myvar=foo)");
    writeln("  --dflags: D compiler flags");
    writeln("  --dc: D compiler to use (default dmd)");
    writeln("  --cc: C compiler to use (default gcc)");
    writeln("  --cxx: C++ compiler to use (default g++)");
}
