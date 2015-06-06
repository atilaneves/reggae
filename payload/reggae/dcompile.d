import reggae.dependencies;
import std.stdio;
import std.exception;
import std.process;
import std.conv;
import std.algorithm;
import std.getopt;
import std.array;

int main(string[] args) {
    try {
        dcompile(args);
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}


/**
Only exists in order to get dependencies for each compilation step.
 */
private void dcompile(string[] args) {
    string depFile, objFile;
    auto helpInfo = getopt(args,
                           std.getopt.config.passThrough,
                           "depFile", "The dependency file to write", &depFile,
                           "objFile", "The object file to output", &objFile,
        );
    enforce(args.length >= 2, "Usage: dcompile -o <objFile> -s <srcFile> -d <depFile> <compiler> <options>");
    enforce(!depFile.empty && !objFile.empty, "The -d and -o options are mandatory");
    const compArgs = args[1 .. $] ~ ["-v", "-of" ~ objFile, "-c"];
    const compRes = execute(compArgs);
    enforce(compRes.status == 0, text("Could not compile with args:\n", compArgs.join(" "), " :\n",
                                      compRes.output.split("\n").
                                      filter!isInterestingCompilerErrorLine.join("\n")));

    auto file = File(depFile, "w");
    file.write(objFile, ": \\\n");
    file.write(dMainDependencies(compRes.output).join(" "));
    file.writeln;
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
    if(line.startsWith("entry ")) return false;
    return true;
}
