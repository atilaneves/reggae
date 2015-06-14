module reggae.options;

import reggae.types: Backend;

import std.file: thisExePath;
import std.conv: ConvException;
import std.path: absolutePath, buildPath;
import std.file: exists;

struct Options {
    Backend backend;
    string projectPath;
    string dflags;
    string reggaePath;
    string[string] userVars;
    string cCompiler;
    string cppCompiler;
    string dCompiler;
    bool noFetch;
    bool help;
    bool perModule;
    bool isDubProject;

    //finished setup
    void finalize() @safe{
        reggaePath = thisExePath();

        if(!cCompiler)   cCompiler   = "gcc";
        if(!cppCompiler) cppCompiler = "g++";
        if(!dCompiler)   dCompiler   = "dmd";

        isDubProject = _isDubProject;
    }

    private bool _isDubProject() @safe nothrow {
        return buildPath(projectPath, "dub.json").exists ||
            buildPath(projectPath, "package.json").exists;
    }

}


//getopt is @system
Options getOptions(string[] args) @trusted {
    import std.getopt;

    Options options;
    try {
        auto helpInfo = getopt(
            args,
            "backend|b", "Backend to use (ninja|make). Mandatory.", &options.backend,
            "dflags", "D compiler flags.", &options.dflags,
            "d", "User-defined variables (e.g. -d myvar=foo).", &options.userVars,
            "dc", "D compiler to use (default dmd).", &options.dCompiler,
            "cc", "C compiler to use (default gcc).", &options.cCompiler,
            "cxx", "C++ compiler to use (default g++).", &options.cppCompiler,
            "nofetch", "Assume dub packages are present (no dub fetch).", &options.noFetch,
            "per_module", "Compile D files per module (default is per package)", &options.perModule,

            );

        if(helpInfo.helpWanted) {
            defaultGetoptPrinter("Usage: reggae -b <ninja|make> </path/to/project>",
                                 helpInfo.options);
            options.help = true;
        }

    } catch(ConvException ex) {
        throw new Exception("Unsupported backend, -b must be one of: make|ninja|tup|binary");
    }

    if(args.length > 1) options.projectPath = args[1].absolutePath;
    options.finalize();

    return options;
}

string projectBuildFile(in Options options) @safe pure nothrow {
    return buildPath(options.projectPath, "reggaefile.d");
}
