module reggae.makefile;

import reggae.build;
import reggae.range;
import reggae.rules;
import std.conv;
import std.array;
import std.path;
import std.algorithm;


struct Makefile {
    Build build;
    string projectPath;

    this(Build build) @safe pure {
        this.build = build;
        this.projectPath = "";
    }

    this(Build build, string projectPath) @safe pure {
        this.build = build;
        this.projectPath = projectPath.absolutePath;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    string simpleOutput() @safe const {

        const outputs = build.targets.map!(a => a.outputs[0]).join(" ");
        auto ret = text("all: ", outputs, "\n");

        foreach(topTarget; build.targets) {
            foreach(t; DepthFirst(topTarget)) {

                mkDir(t);

                ret ~= text(t.outputs.join(" "), ": ");
                ret ~= t.dependencyFiles(projectPath);
                immutable implicitFiles = t.implicitFiles(projectPath);
                if(!implicitFiles.empty) ret ~= " " ~ t.implicitFiles(projectPath);
                ret ~= " Makefile\n";
                ret ~= "\t";
                ret ~= command(t);
                ret ~= "\n";
            }
        }

        return ret;
    }

    string output() @safe const {
        import reggae.config;
        auto ret = simpleOutput;
        ret ~= "Makefile: " ~ buildFilePath ~ " " ~ reggaePath ~ "\n";
        immutable _dflags = dflags == "" ? "" : " --dflags='" ~ dflags ~ "'";
        ret ~= "\t" ~ reggaePath ~ " -b make" ~ _dflags ~ " " ~ projectPath ~ "\n";
        return ret;
    }

    private void mkDir(in Target target) @trusted const {
        foreach(output; target.outputs) {
            import std.file;
            if(!output.dirName.exists) mkdirRecurse(output.dirName);
        }
    }

    string command(in Target target) @safe const {
        immutable rawCmdLine = target.inOutCommand(projectPath);
        if(rawCmdLine.isDefaultCommand) {
            return command(target, rawCmdLine);
        } else {
            return target.command(projectPath);
        }
    }

    string command(in Target target, in string rawCmdLine) @safe const {
        import reggae.config;

        immutable rule = rawCmdLine.getDefaultRule;
        immutable flags = rawCmdLine.getDefaultRuleParams("flags", []).join(" ");
        immutable includes = rawCmdLine.getDefaultRuleParams("includes", []).join(" ");
        immutable depfile = target.outputs[0] ~ ".d";

        string ccCommand(in string compiler) {
            immutable command = [compiler, flags, includes, "-MMD", "-MT", target.outputs[0],
                                 "-MF", depfile, "-o", target.outputs[0], "-c",
                                 target.dependencyFiles(projectPath)].join(" ");
            return command ~ makeAutoDeps(depfile);
        }

        if(rule == "_dcompile") {
            immutable stringImports = rawCmdLine.getDefaultRuleParams("stringImports", []).join(" ");
            immutable command = [".reggae/dcompile",
                                 target.dependencyFiles(projectPath).splitter(" ").
                                 map!(a => "--srcFile=" ~ a).join(" "),
                                 "--objFile=" ~ target.outputs[0],
                                 "--depFile=" ~ depfile, dCompiler,
                                 flags, includes, stringImports].join(" ");

            return command ~ makeAutoDeps(depfile);

        } else if(rule == "_cppcompile") {
            return ccCommand(cppCompiler);
        } else if(rule == "_ccompile") {
            return ccCommand(cCompiler);
        } else if(rule == "_dlink") {
            return [dCompiler, "-of" ~ target.outputs[0], target.dependencyFiles(projectPath)].join(" ");
        } else {
            throw new Exception("Unknown Makefile default rule " ~ rule);
        }
    }

private:

    void addRerunBuild(ref string ret) @safe pure nothrow const {
        import reggae.config;
        ret ~= "Makefile: " ~ buildFilePath ~ " " ~ reggaePath ~ "\n";
        immutable _dflags = dflags == "" ? "" : " --dflags='" ~ dflags ~ "'";
        ret ~= "\t" ~ reggaePath ~ " -b make" ~ _dflags ~ " " ~ projectPath ~ "\n";
    }
}


//For explanation of the crazy Makefile commands, see:
//http://stackoverflow.com/questions/8025766/makefile-auto-dependency-generation
//http://make.mad-scientist.net/papers/advanced-auto-dependency-generation/
private string makeAutoDeps(in string depfile) @safe pure nothrow {
    immutable pFile = depfile ~ ".P";
    return "\n\t@cp " ~ depfile ~ " " ~ pFile ~ "; \\\n" ~
        "    sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \\\n" ~
        "        -e '/^$$/ d' -e 's/$$/ :/' < " ~ depfile ~ " >> " ~ pFile ~"; \\\n" ~
        "    rm -f " ~ depfile ~ "\n\n" ~
        "-include " ~ pFile ~ "\n\n";
}
