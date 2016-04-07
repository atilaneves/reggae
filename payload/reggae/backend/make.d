module reggae.backend.make;

import reggae.build;
import reggae.range;
import reggae.rules;
import reggae.options;

import std.conv;
import std.array;
import std.path;
import std.algorithm;


struct Makefile {
    Build build;
    const(Options) options;
    string projectPath;

    this(Build build) @safe pure {
        this(build, Options());
    }

    this(Build build, in string projectPath) @safe pure {
        import reggae.config: options;
        auto modOptions = options.dup;
        modOptions.projectPath = projectPath;
        this(build, modOptions);
    }

    this(Build build, in Options options) @safe pure {
        this.build = build;
        this.options = options;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    //only the main targets
    string simpleOutput() @safe {

        auto ret = banner;
        ret ~= text("all: ", build.defaultTargetsString(options.projectPath), "\n");
        ret ~= ".SUFFIXES:\n"; //disable default rules
        ret ~= options.compilerVariables.join("\n") ~ "\n";

        foreach(t; build.range) {

            mkDir(t);

            immutable output = t.outputsInProjectPath(options.projectPath).join(" ");
            if(t.getCommandType == CommandType.phony) {
                ret ~= ".PHONY: " ~ output ~ "\n";
            }
            ret ~= output ~  ": ";
            ret ~= (t.dependenciesInProjectPath(options.projectPath) ~ t.implicitsInProjectPath(options.projectPath)).join(" ");

            ret ~= " " ~ fileName() ~ "\n";
            ret ~= "\t" ~ command(t) ~ "\n";
        }

        return ret;
    }

    //includes rerunning reggae
    string output() @safe {
        auto ret = simpleOutput;

        if(options.export_) {
            ret = options.eraseProjectPath(ret);
        } else {
            // add a dependency on the Makefile to reggae itself and the build description,
            // but only if not exporting a build
            ret ~= fileName() ~ ": " ~ (options.reggaeFileDependencies ~ getReggaeFileDependencies).join(" ") ~ "\n";
            ret ~= "\t" ~ options.rerunArgs.join(" ") ~ "\n";
        }

        return ret;
    }

    private void mkDir(Target target) @trusted const {
        foreach(output; target.outputsInProjectPath(options.projectPath)) {
            import std.file;
            if(!output.dirName.exists) mkdirRecurse(output.dirName);
        }
    }

    //the only reason this is needed is to add auto dependency
    //tracking
    string command(Target target) @safe const {
        immutable cmdType = target.getCommandType;
        if(cmdType == CommandType.code)
            throw new Exception("Command type 'code' not supported for make backend");

        immutable cmd = target.shellCommand(options).replaceConcreteCompilersWithVars(options);
        immutable depfile = target.outputsInProjectPath(options.projectPath)[0] ~ ".dep";
        if(target.hasDefaultCommand) {
            return cmdType == CommandType.link ? cmd : cmd ~ makeAutoDeps(depfile);
        } else {
            return cmd;
        }
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
