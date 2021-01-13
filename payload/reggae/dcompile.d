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

    const compArgs = compilerArgs(args, objFile);
    const fewerArgs = compArgs[0..$-1]; //non-verbose
    const compRes = execute(compArgs);
    enforce(compRes.status == 0,
            text("Could not compile with args:\n", fewerArgs.join(" "), "\n",
                 execute(fewerArgs).output));

    auto file = File(depFile, "w");
    file.write(dependenciesToFile(objFile, dMainDependencies(compRes.output)).join("\n"));
    file.writeln;
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
