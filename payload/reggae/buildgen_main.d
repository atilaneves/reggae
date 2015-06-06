import reggaefile; //the user's build description
import reggae;
import reggae.dependencies;
import std.stdio;
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
        args.length == 1 ? generateBuild : dcompile(args);
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}


private void generateBuild() {
    const buildFunc = getBuild!(reggaefile); //get the function to call by CT reflection
    const build = buildFunc(); //actually call the function to get the build description

    final switch(backend) with(Backend) {

        case make:
            const makefile = Makefile(build, projectPath);
            auto file = File(makefile.fileName, "w");
            file.write(makefile.output);
            break;

        case ninja:
            const ninja = Ninja(build, projectPath);

            auto buildNinja = File("build.ninja", "w");
            buildNinja.writeln("include rules.ninja\n");
            buildNinja.writeln(ninja.buildOutput);

            auto rulesNinja = File("rules.ninja", "w");
            rulesNinja.writeln(ninja.rulesOutput);

            break;

        case binary:
            const binary = Binary(build, projectPath);
            binary.run();
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
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
