module reggae.dependencies;


/**
 * Given a line from verbose compiler output, checks if it is an import
 * of a non-druntime/Phobos module and returns its file path in that case.
 * Otherwise, returns null.
 */
string tryExtractPathFromImportLine(in string line) @safe pure {
    import std.algorithm: any;
    import std.string: indexOf, startsWith, strip;

    // looking for: `import <whitespace(s)> <moduleID> <whitespace(s)> (<filePath>)`
    if (!(line.startsWith("import ") && line[$-1] == ')'))
        return null;

    const rest = line[7 .. $];
    const i = rest.indexOf('(');
    if (i <= 0)
        return null;

    const id = strip(rest[0 .. i-1]);
    static immutable exclPrefixes = ["std.", "core.", "etc.", "ldc."];
    if (id == "object" || exclPrefixes.any!(p => id.startsWith(p)))
        return null;

    return rest[i+1 .. $-1];
}

/**
 * Given the output of compiling a file, return
 * the list of D files to compile to link the executable.
 * Only includes source files to compile
 */
string[] dMainDepSrcs(in string output) {
    import std.string: splitLines;

    string[] dependencies;

    foreach(line; output.splitLines) {
        const importPath = tryExtractPathFromImportLine(line);
        if (importPath !is null)
            dependencies ~= importPath;
    }

    return dependencies;
}
