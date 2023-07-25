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

    const makeDeps = "-makedeps=" ~ depFile;
    const compArgs = compilerArgs(args[1 .. $], objFile) ~ makeDeps;
    const compRes = invokeCompiler(compArgs, objFile);

    if (compRes.status != 0) {
        stderr.writeln("Error compiling!");
        return compRes.status;
    }

    return 0;
}


private string[] compilerArgs(string[] args, string objFile) @safe pure {
    import std.path: absolutePath, baseName, dirName, stripExtension;

    enum Compiler { dmd, gdc, ldc }

    const compilerBinName = baseName(stripExtension(args[0]));
    Compiler compiler = Compiler.dmd;
    Compiler cli = Compiler.dmd;
    switch (compilerBinName) {
        default:
            break;
        case "gdmd":
            compiler = Compiler.gdc;
            break;
        case "gdc":
            compiler = Compiler.gdc;
            cli = Compiler.gdc;
            break;
        case "ldmd":
        case "ldmd2":
            compiler = Compiler.ldc;
            break;
        case "ldc":
        case "ldc2":
            compiler = Compiler.ldc;
            cli = Compiler.ldc;
            break;
    }

    if (compiler == Compiler.ldc && args.length > 1 && args[1] == "-lib") {
        /* Unlike DMD, LDC does not write static libraries directly, but writes
         * object files and archives them to a static lib.
         * Make sure the temporary object files don't collide across parallel
         * compiler invocations in the same working dir by placing the object
         * files into the library's output directory via -od.
         */
        const od = "-od=" ~ dirName(objFile);

        if (cli == Compiler.ldc) { // ldc2
            // mimic ldmd2 - uniquely-name and remove the object files
            args.insertInPlace(2, "-oq", "-cleanup-obj", od);

            // dub adds `--oq -od=…/obj`, remove it as it defeats our purpose
            foreach (i; 5 .. args.length - 1) {
                if (args[i] == "--oq" && args[i+1].startsWith("-od=")) {
                    args = args[0 .. i] ~ args[i+2 .. $];
                    break;
                }
            }
        } else { // ldmd2
            args.insertInPlace(2, od);
            // As with dmd, -od may affect the final path of the static library
            // (relative to -od) - make -of absolute to prevent this.
            objFile = absolutePath(objFile);
        }
    }

    args ~= ["-color=on", "-of" ~ objFile];

    final switch (cli) {
        case Compiler.dmd: return args;
        case Compiler.gdc: return mapToGdcOptions(args);
        case Compiler.ldc: return mapToLdcOptions(args);
    }
}

//takes a dmd command line and maps arguments to gdc ones
private string[] mapToGdcOptions(in string[] compArgs) @safe pure {
    string[string] options = [
        "-v": "-fd-verbose",
        "-O": "-O2",
        "-debug": "-fdebug",
        "-of": "-o",
        "-color=on": "-fdiagnostics-color=always",
    ];

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
    string doMap(string a) {
        switch (a) {
            case "-m32mscoff": return "-m32";
            case "-fPIC":      return "-relocation-model=pic";
            case "-gs":        return "-frame-pointer=all";
            case "-inline":    return "-enable-inlining";
            case "-profile":   return "-fdmd-trace-functions";
            case "-color=on": return "-enable-color";
            default:
                if (a.startsWith("-version="))
                    return "-d-version=" ~ a[9 .. $];
                if (a.startsWith("-debug"))
                    return "-d-debug" ~ a[6 .. $];
                return a;
        }
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
            const res = execute([quoteArgIfNeeded(args[0]), "@" ~ rspFile], /*env=*/null, Config.stderrPassThrough);
            remove(rspFile);
            return res;
        }
    }

    // pass through stderr, capture stdout with -v output
    return execute(args, /*env=*/null, Config.stderrPassThrough);
}


// Parses the arguments from the specified response file content.
version(Windows)
string[] parseResponseFile(in string data) @safe pure {
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
            // inside quoted arg/fragment
            if (c != currentQuoteChar) {
                currentArg ~= c;
            } else {
                auto a = currentArg[];
                if (currentQuoteChar == '"' && a.length > 0 && a[$-1] == '\\') {
                    a[$-1] = c; // un-escape: \" => "
                } else { // closing quote
                    currentQuoteChar = 0;
                }
            }
        } else if (isWhite(c)) {
            pushArg();
        } else if (c == '"' || c == '\'') {
            // beginning of quoted arg/fragment
            currentQuoteChar = c;
        } else {
            // inside unquoted arg/fragment
            currentArg ~= c;
        }
    }

    pushArg();

    return args[];
}
