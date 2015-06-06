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
        foreach(topTarget; build.targets) {
            foreach(level; ByDepthLevel(topTarget)) {
                foreach(target; level.parallel) {
                    foreach(dep; chain(target.dependencies, target.implicits)) {
                        if(cartesianProduct(dep.outputs, target.outputs).
                           any!(a => a[0].newerThan(a[1]))) {
                            immutable cmd = target.shellCommand(projectPath);
                            writeln("[build] " ~ cmd);
                            immutable res = executeShell(cmd);
                            enforce(res.status == 0, "Could not execute " ~ cmd ~ ":\n" ~ res.output);
                        }
                    }
                }
            }
        }
    }
}


bool newerThan(in string a, in string b) {
    try {
        return a.timeLastModified > b.timeLastModified;
    } catch(Exception) { //file not there, so newer
        return true;
    }
}
