module reggae.backend.binary;

import reggae.build;
import reggae.range;
import std.algorithm: all, splitter;
import std.range: chain;
import std.file: timeLastModified;
import std.process: execute;
import std.path: absolutePath;

@safe:

struct Binary {
    Build build;
    string projectPath;

    this(Build build, string projectPath) pure {
        this.build = build;
        this.projectPath = projectPath;
    }

    void run() const {
        foreach(topTarget; build.targets) {
            foreach(level; ByDepthLevel(topTarget)) {
                foreach(target; level) {
                    foreach(dep; chain(target.dependencies, target.implicits)) {
                        if(dep.outputs[0].newerThan(target.outputs[0])) {
                            immutable cmd = target.command(projectPath).splitter(" ").array;
                            execute(cmd);
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
