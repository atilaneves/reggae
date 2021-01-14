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
            dcompile(args);
            return 0;
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }
    }
}

/**
Only exists in order to get dependencies for each compilation step.
 */
private void dcompile(string[] args) {

    string depFile, objFile;
    auto helpInfo = getopt(
        args,
        std.getopt.config.passThrough,
        "depFile", "The dependency file to write", &depFile,
        "objFile", "The object file to output", &objFile,
    );

    enforce(args.length >= 2, "Usage: dcompile --objFile <objFile> --depFile <depFile> <compiler> <compiler args>");
    enforce(!depFile.empty && !objFile.empty, "The --depFile and --objFile 'options' are mandatory");

    const compArgs = compilerArgs(args[1 .. $], objFile);
    const fewerArgs = compArgs[0..$-1]; //non-verbose
    const compRes = execute(compArgs);
    enforce(compRes.status == 0,
            text("Could not compile with args:\n", fewerArgs.join(" "), "\n",
                 execute(fewerArgs).output));

    auto file = File(depFile, "w");
    file.write(dependenciesToFile(objFile, dMainDependencies(compRes.output)).join("\n"));
    file.writeln;
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

            // dub adds `-od=.dub/obj`, remove it as it defeats our purpose
            foreach (i; 5 .. args.length) {
                if (args[i] == "-od=.dub/obj") {
                    args = args[0 .. i] ~ args[i+1 .. $];
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

    args ~= ["-of" ~ objFile, "-c", "-v"];

    final switch (cli) {
        case Compiler.dmd: return args;
        case Compiler.gdc: return mapToGdcOptions(args);
        case Compiler.ldc: return mapToLdcOptions(args);
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
    string doMap(string a) {
        switch (a) {
            case "-m32mscoff": return "-m32";
            case "-fPIC":      return "-relocation-model=pic";
            case "-gs":        return "-frame-pointer=all";
            case "-inline":    return "-enable-inlining";
            case "-profile":   return "-fdmd-trace-functions";
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
