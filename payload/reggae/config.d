/**
 This file is never actually used in production. It owes its existence
 to allowing the UTs to build and flycheck to not complain.
 */

module reggae.config;

import reggae.types;
import reggae.options;
import reggae.ctaa;

version(minimal) {
    enum isDubProject = false;
} else {
    enum isDubProject = true;
}


version(DigitalMars)
    enum dCompiler = "dmd";
else version(LDC)
    enum dCompiler = "ldc2";
else version(GNU)
    enum dCompiler = "gdc";
else
    static assert(false, "Unknown D compiler");


immutable Options gDefaultOptions = Options(Backend.ninja,
            "",
            null,
            "",
            defaultCC,
            defaultCXX,
            dCompiler,
            false,
            false,
            true, //perModule only for UTs, false in real world
            isDubProject,
            false,
);

private Options gOptions = gDefaultOptions.dup;

Options options() @safe nothrow {
    return gOptions;
}

void setOptions(Options options) {
    gOptions = options;
}

enum userVars = AssocList!(string, string)();

version(minimal) {}
else {
    import reggae.dub.info;
    import reggae.ctaa;

    enum dubInfo = ["default": DubInfo() ];
    enum configToDubInfo = AssocList!(string, DubInfo)();
}
