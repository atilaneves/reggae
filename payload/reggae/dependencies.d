module reggae.dependencies;


/**
 * Given the output of compiling a file, return
 * the list of D files to compile to link the executable.
 * Only includes source files to compile
 */
string[] dMainDepSrcs()(in string output) {
    import std.regex: regex, matchFirst;
    import std.string: splitLines;

    string[] dependencies;
    auto importReg = regex(`^import +([^\t]+)[\t\s]+\((.+)\)$`);
    auto stdlibReg = regex(`^(std\.|core\.|etc\.|object$)`);

    foreach(line; output.splitLines) {
        auto importMatch = line.matchFirst(importReg);
        if(importMatch) {
            auto stdlibMatch = importMatch.captures[1].matchFirst(stdlibReg);
            if(!stdlibMatch) dependencies ~= importMatch.captures[2];
        }
    }

    return dependencies;
}
