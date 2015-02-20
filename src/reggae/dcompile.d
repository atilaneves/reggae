import reggae.dependencies;
import std.exception;
import std.process;
import std.stdio;
import std.conv;
import std.regex;
import std.algorithm;
import std.array;


int main(string[] args) {
    try {

        enforce(args.length > 4, "Usage: dcompile <compiler> <options> <objFile> <srcFile> <depFile>");
        immutable depFile = args[$ - 1];
        immutable srcFile = args[$ - 2];
        immutable objFile = args[$ - 3];
        const compArgs = args[1 .. $ - 3] ~ ["-v", "-of" ~ objFile, "-c", srcFile];
        const compRes = execute(compArgs);
        enforce(compRes.status == 0, text("Could not compile with args ", compArgs.join(" "), " :\n",
                                          compRes.output));

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
