module reggae.backend.make;

import reggae.build;
import reggae.range;
import reggae.rules;
import reggae.config;

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
        this.projectPath = projectPath;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    //only the main targets
    string simpleOutput() @safe const {

        auto ret = text("all: ", build.defaultTargetsString, "\n");

        foreach(topTarget; build.targets) {
            foreach(t; DepthFirst(topTarget)) {

                mkDir(t);

                ret ~= text(t.outputs.join(" "), ": ");
                ret ~= t.dependencyFilesString(projectPath);
                immutable implicitFiles = t.implicitFilesString(projectPath);
                if(!implicitFiles.empty) ret ~= " " ~ t.implicitFilesString(projectPath);
                ret ~= " Makefile\n";

                ret ~= "\t" ~ command(t) ~ "\n";
            }
        }

        return ret;
    }

    //includes rerunning reggae
    string output() @safe const {
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

    //the only reason this is needed is to add auto dependency
    //tracking
    string command(in Target target) @safe const {
        immutable cmdType = target.command.getType;
        if(cmdType == CommandType.code)
            throw new Exception("Command type 'code' not supported for make backend");

        immutable cmd = target.shellCommand(projectPath);
        immutable depfile = target.outputs[0] ~ ".dep";
        if(target.command.isDefaultCommand) {
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
