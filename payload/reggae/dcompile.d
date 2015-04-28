import reggae.dependencies;
import std.exception;
import std.process;
import std.stdio;
import std.conv;
import std.regex;
import std.algorithm;
import std.array;
import std.getopt;


int main(string[] args) {
    try {
        string depFile, srcFile, objFile;
        auto helpInfo = getopt(args,
                               std.getopt.config.passThrough,
                               "srcFile", "The source file to compile", &srcFile,
                               "depFile", "The dependency file to write", &depFile,
                               "objFile", "The object file to output", &objFile,
            );
        enforce(args.length >= 2, "Usage: dcompile -o <objFile> -s <srcFile> -d <depFile> <compiler> <options>");
        enforce(!depFile.empty && !srcFile.empty && !objFile.empty, "The -d, -s and -o options are mandatory");
        const compArgs = args[1 .. $] ~ ["-v", "-of" ~ objFile, "-c", srcFile];
        const compRes = execute(compArgs);
        enforce(compRes.status == 0, text("Could not compile with args:\n", compArgs.join(" "), " :\n",
                                          compRes.output.split("\n").
                                          filter!isInterestingCompilerErrorLine.join("\n")));

        auto file = File(depFile, "w");
        file.write(objFile, ": ");

        foreach(immutable dep; dMainDependencies(compRes.output)) {
            file.write(dep, " ");
        }

        file.writeln;

    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}


bool isInterestingCompilerErrorLine(in string line) @safe pure nothrow {
    if(line.startsWith("binary ")) return false;
    if(line.startsWith("version ")) return false;
    if(line.startsWith("config ")) return false;
    if(line.startsWith("parse ")) return false;
    if(line.startsWith("importall ")) return false;
    if(line.startsWith("import ")) return false;
    if(line.startsWith("semantic")) return false;
    if(line.startsWith("code ")) return false;
    if(line.startsWith("function ")) return false;
    return true;
}
