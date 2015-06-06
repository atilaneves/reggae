module reggae.backend.binary;


import reggae.build;
import reggae.range;
import reggae.config;
import std.algorithm: all, splitter, cartesianProduct, any, filter;
import std.range: chain;
import std.file: timeLastModified, thisExePath, exists;
import std.process: execute, executeShell;
import std.path: absolutePath;
import std.typecons: tuple;
import std.exception: enforce;
import std.stdio;
import std.parallelism: parallel;
import std.conv: text;
import std.array: replace, empty;
import std.string: stripLeft;

@safe:

struct Binary {
    Build build;
    string projectPath;

    this(Build build, string projectPath) pure {
        this.build = build;
        this.projectPath = projectPath;
    }

    void run() const @system { //@system due to parallel

        bool didAnything = checkReRun();

        foreach(topTarget; build.targets) {
            foreach(level; ByDepthLevel(topTarget)) {
                foreach(target; level.parallel) {

                    const outs = target.outputsInProjectPath(projectPath);
                    //if((outs[0] ~ ".d").exists) writeln("A dep file for ", outs[0]);

                    didAnything = checkTarget(target) || didAnything;
                }
            }
        }

        if(!didAnything) writeln("Nothing to do");
    }

private:

    bool checkReRun() const {
        immutable myPath = thisExePath;
        if(reggaePath.newerThan(myPath) || buildFilePath.newerThan(myPath)) {
            writeln("[build] " ~ reggaeCmd.join(" "));
            immutable reggaeRes = execute(reggaeCmd);
            enforce(reggaeRes.status == 0,
                    text("Could not run ", reggaeCmd.join(" "), " to regenerate build:\n",
                         reggaeRes.output));
            writeln(reggaeRes.output);

            //currently not needed because generating the build also runs it.
            // immutable buildRes = execute([myPath]);
            // enforce(buildRes.status == 0, "Could not redo the build:\n", buildRes.output);
            return true;
        }

        return false;
    }

    string[] reggaeCmd() pure nothrow const {
        immutable _dflags = dflags == "" ? "" : " --dflags='" ~ dflags ~ "'";
        auto mutCmd = [reggaePath, "-b", "binary"];
        if(_dflags != "") mutCmd ~= _dflags;
        return mutCmd ~ projectPath;
    }

    bool checkTarget(in Target target) const {
        bool didAnything;
        foreach(dep; chain(target.dependencies, target.implicits)) {
            if(cartesianProduct(dep.outputsInProjectPath(projectPath),
                                target.outputsInProjectPath(projectPath)).
               any!(a => a[0].newerThan(a[1]))) {

                didAnything = true;
                mkDir(target);
                immutable cmd = target.shellCommand(projectPath);
                writeln("[build] " ~ cmd);
                immutable res = executeShell(cmd);
                enforce(res.status == 0, "Could not execute " ~ cmd ~ ":\n" ~ res.output);
            }
        }

        return didAnything;
    }
}


bool newerThan(in string a, in string b) nothrow {
    try {
        return a.timeLastModified > b.timeLastModified;
    } catch(Exception) { //file not there, so newer
        return true;
    }
}

//@trusted because of mkdirRecurse
private void mkDir(in Target target) @trusted {
    foreach(output; target.outputs) {
        import std.file: exists, mkdirRecurse;
        import std.path: dirName;
        if(!output.dirName.exists) mkdirRecurse(output.dirName);
    }
}

string[] dependenciesFromFile(in string output) pure {
    return output.
        splitter("\n").
        map!(a => a.replace(" \\", "")).
        filter!(a => !a.empty).
        map!(a => a.stripLeft).
        array[1..$];
}
