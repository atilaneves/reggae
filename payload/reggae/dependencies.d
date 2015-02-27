module reggae.dependencies;

import std.regex;
import std.algorithm: splitter;

/**
 * Given a source file with a D main() function, return
 * The list of D files to compile to link the executable
 */
//@trusted because of splitter
string[] dMainDependencies(in string output) @trusted {
    string[] dependencies;
    auto importReg = ctRegex!`^import +([^\t]+)\t+\((.+)\)$`;
    auto stdlibReg = ctRegex!`^(std\.|core\.|object$)`;
    foreach(line; output.splitter("\n")) {
        auto importMatch = line.matchFirst(importReg);
        if(importMatch) {
            auto stdlibMatch = importMatch.captures[1].matchFirst(stdlibReg);
            if(!stdlibMatch) {
                dependencies ~= importMatch.captures[2];
            }
        }
    }

    return dependencies;
}
