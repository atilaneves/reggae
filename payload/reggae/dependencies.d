module reggae.dependencies;


import std.range.primitives: isInputRange;


string[] dependenciesFromFile(R)(R lines) if(isInputRange!R) {
    import std.algorithm: map, filter, find;
    import std.string: strip;
    import std.array: empty, join, array, replace, split;

    if(lines.empty) return [];
    return lines
        .map!(a => a.replace(`\`, ``).strip)
        .join(" ")
        .find(":")
        .split(" ")
        .filter!(a => a != "")
        .array[1..$];
}


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


string[] dependenciesToFile(in string objFile, in string[] deps) @safe pure nothrow {
    import std.array: join;
    return [
        objFile ~ ": \\",
        deps.join(" "),
    ];
}
