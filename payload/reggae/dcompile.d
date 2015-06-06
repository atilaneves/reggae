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
    const compArgs = args[1 .. $] ~ ["-of" ~ objFile, "-c", "-v"];
    const fewerArgs = compArgs[0..$-1]; //non-verbose
    const compRes = execute(compArgs);
    enforce(compRes.status == 0,
            text("Could not compile with args:\n", fewerArgs.join(" "), "\n",
                 execute(fewerArgs).output));

    auto file = File(depFile, "w");
    file.write(objFile, ": \\\n");
    file.write(dMainDependencies(compRes.output).join(" "));
    file.writeln;
}
