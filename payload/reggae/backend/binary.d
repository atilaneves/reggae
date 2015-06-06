module reggae.backend.binary;


import reggae.build;
import reggae.range;
import std.algorithm: all, splitter, cartesianProduct, any;
import std.range: chain;
import std.file: timeLastModified;
import std.process: executeShell;
import std.path: absolutePath;
import std.typecons: tuple;
import std.exception: enforce;
import std.stdio;
import std.parallelism: parallel;

@safe:

struct Binary {
    Build build;
    string projectPath;

    this(Build build, string projectPath) pure {
        this.build = build;
        this.projectPath = projectPath;
    }

    //ugh, arrow anti-pattern
    void run() const @system { //@system due to parallel

        bool didAnything;

        foreach(topTarget; build.targets) {
            foreach(level; ByDepthLevel(topTarget)) {
                foreach(target; level.parallel) {
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
                }
            }
        }

        if(!didAnything) writeln("Nothing to do");
    }
}


bool newerThan(in string a, in string b) {
    try {
        return a.timeLastModified > b.timeLastModified;
    } catch(Exception) { //file not there, so newer
        return true;
    }
}

private void mkDir(in Target target) @trusted {
    foreach(output; target.outputs) {
        import std.file: exists, mkdirRecurse;
        import std.path: dirName;
        if(!output.dirName.exists) mkdirRecurse(output.dirName);
    }
}
