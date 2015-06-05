module reggae.binary;

import reggae.build;
import reggae.range;
import std.algorithm: all;
import std.range: chain;
import std.file: timeLastModified;
import std.process: execute;

@safe:

struct Binary {
    Build build;
    string projectPath;

    void run() const {
        foreach(topTarget; build.targets) {
            auto allDeps = chain(topTarget.dependencies, topTarget.implicits);
            // if(allDeps.all!(a => a.isLeaf)) {
            //     foreach(dep; allDeps) {
            //     }
            // }
            foreach(dep; allDeps) {
                import std.stdio;
                if(dep.outputs[0].newerThan(topTarget.outputs[0])) {
                    writeln(dep.outputs[0], " is newer than ", topTarget.outputs[0]);
                    execute(topTarget.command);
                }
            }
            //recursive(topTarget);
            foreach(target; DepthFirst(topTarget)) {
            }
        }
    }

    private void recursive(in Target target) const {
        if(target.isLeaf) return;


    }
}


bool newerThan(in string a, in string b) {
    try {
        return a.timeLastModified > b.timeLastModified;
    } catch(Exception) { //file not there, so newer
        return true;
    }
}
