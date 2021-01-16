module reggae.dcompile;

import std.stdio;
import std.exception;
import std.process;
import std.conv;
import std.algorithm;
import std.getopt;
import std.array;


version(ReggaeTest) {}
else {
    int main(string[] args) {
        try {
            return dcompile(args);
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }
    }
}

/**
Only exists in order to get dependencies for each compilation step.
 */
private int dcompile(string[] args) {

    version(Windows) {
        // expand any response files in args (`dcompile @file.rsp`)
        import std.array: appender;
        import std.file: readText;

        auto expandedArgs = appender!(string[]);
        expandedArgs.reserve(args.length);

        foreach (arg; args) {
            if (arg.length > 1 && arg[0] == '@') {
                expandedArgs ~= parseResponseFile(readText(arg[1 .. $]));
            } else {
                expandedArgs ~= arg;
            }
        }

        args = expandedArgs[];
    }

    string depFile, objFile;
    auto helpInfo = getopt(
        args,
        std.getopt.config.passThrough,
        "depFile", "The dependency file to write", &depFile,
        "objFile", "The object file to output", &objFile,
    );

    enforce(args.length >= 2, "Usage: dcompile --objFile <objFile> --depFile <depFile> <compiler> <compiler args>");
    enforce(!depFile.empty && !objFile.empty, "The --depFile and --objFile 'options' are mandatory");

    const compArgs = compilerArgs(args, objFile);
    const fewerArgs = compArgs[0..$-1]; //non-verbose

    const compRes = invokeCompiler(compArgs, objFile);
    if (compRes.status != 0) {
        stderr.writeln("Could not compile with args:\n", fewerArgs.join(" "));
        return compRes.status;
    }

    auto file = File(depFile, "w");
    file.write(dependenciesToFile(objFile, dMainDependencies(compRes.output)).join("\n"));
    file.writeln;

    return 0;
}


private string[] compilerArgs(string[] args, in string objFile) @safe pure {
    auto compArgs = args[1 .. $] ~ ["-of" ~ objFile, "-c", "-v"];

    import std.path: baseName, stripExtension;
    const compilerBinName = baseName(stripExtension(args[1]));

    switch(compilerBinName) {
        default:
            return compArgs;
        case "gdc":
            return mapToGdcOptions(compArgs);
        case "ldc":
        case "ldc2":
            return mapToLdcOptions(compArgs);
    }
}

//takes a dmd command line and maps arguments to gdc ones
private string[] mapToGdcOptions(in string[] compArgs) @safe pure {
    string[string] options = ["-v": "-fd-verbose", "-O": "-O2", "-debug": "-fdebug", "-of": "-o"];

    string doMap(string a) {
        foreach(k, v; options) {
            if(a.startsWith(k)) a = a.replace(k, v);
        }
        return a;
    }

    return compArgs.map!doMap.array;
}


//takes a dmd command line and maps arguments to ldc2 ones
private string[] mapToLdcOptions(in string[] compArgs) @safe pure {
    string[string] options = [
        "-m32mscoff": "-m32",
        "-version": "-d-version",
        "-debug": "-d-debug",
        "-fPIC": "-relocation-model=pic",
        "-gs": "-frame-pointer=all",
        "-inline": "-enable-inlining",
        "-profile": "-fdmd-trace-functions",
    ];

    string doMap(string a) {
        foreach(k, v; options) {
            if(a.startsWith(k)) a = a.replace(k, v);
        }
        return a;
    }

    return compArgs.map!doMap.array;
}


private auto invokeCompiler(in string[] args, in string objFile) @safe {
    version(Windows) {
        static string quoteArgIfNeeded(string a) {
            return !a.canFind(' ') ? a : `"` ~ a.replace(`"`, `\"`) ~ `"`;
        }

        const rspFileContent = args[1..$].map!quoteArgIfNeeded.join("\n");

        // max command-line length (incl. args[0]) is ~32,767 on Windows
        if (rspFileContent.length > 32_000) {
            import std.file: mkdirRecurse, remove, write;
            import std.path: dirName;

            const rspFile = objFile ~ ".dcompile.rsp"; // Ninja uses `<objFile>.rsp`, don't collide
            mkdirRecurse(dirName(rspFile));
            write(rspFile, rspFileContent);
            const res = execute([args[0], "@" ~ rspFile], /*env=*/null, Config.stderrPassThrough);
            remove(rspFile);
            return res;
        }
    }

    // pass through stderr, capture stdout with -v output
    return execute(args, /*env=*/null, Config.stderrPassThrough);
}


/**
 * Given the output of compiling a file, return
 * the list of D files to compile to link the executable
 * Includes all dependencies, not just source files to
 * compile.
 */
string[] dMainDependencies(in string output) @safe {
    import reggae.dependencies: dMainDepSrcs;
    import std.regex: regex, matchFirst;
    import std.string: splitLines;

    string[] dependencies = dMainDepSrcs(output);
    auto fileReg = regex(`^file +([^\t]+)\t+\((.+)\)$`);

    foreach(line; output.splitLines) {
        auto fileMatch = line.matchFirst(fileReg);
        if(fileMatch) dependencies ~= fileMatch.captures[2];
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


// Parses the arguments from the specified response file content.
version(Windows)
private string[] parseResponseFile(in string data) @safe pure {
    import std.array: appender;
    import std.ascii: isWhite;

    auto args = appender!(string[]);
    auto currentArg = appender!(char[]);
    void pushArg() {
        if (currentArg[].length > 0) {
            args ~= currentArg[].idup;
            currentArg.clear();
        }
    }

    args.reserve(128);
    currentArg.reserve(512);

    char currentQuoteChar = 0;
    foreach (char c; data) {
        if (currentQuoteChar) {
            // inside quoted arg
            if (c != currentQuoteChar) {
                currentArg ~= c;
            } else {
                auto a = currentArg[];
                if (a.length > 0 && a[$-1] == '\\') {
                    a[$-1] = c; // un-escape: \" => "
                } else { // closing quote
                    currentQuoteChar = 0;
                }
            }
        } else if (isWhite(c)) {
            pushArg();
        } else if (currentArg[].length == 0 && (c == '"' || c == '\'')) {
            // beginning of quoted arg
            currentQuoteChar = c;
        } else {
            // inside unquoted arg
            currentArg ~= c;
        }
    }

    pushArg();

    return args[];
}
