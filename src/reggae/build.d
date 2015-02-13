module reggae.build;

import std.string: replace;
import std.algorithm: map, join;
import std.path: buildPath;


struct Build {
    const(Target)[] targets;

    this(in Target target) {
        this([target]);
    }

    this(in Target[] targets) {
        this.targets = targets;
    }
}

struct Target {
    string[] outputs;
    const(Target)[] dependencies;

    this(string output) {
        this(output, null, null);
    }

    this(string output, string command, in Target dependency) {
        this([output], command, [dependency]);
    }

    this(string output, string command, in Target[] dependencies) {
        this([output], command, dependencies);
    }

    this(string[] outputs, string command, in Target[] dependencies) {
        this.outputs = outputs;
        this.dependencies = dependencies;
        this._command = command;
    }

    @property string dependencyFiles(in string projectPath = "") @trusted const nothrow {
        import std.conv;
        string files;
        //join doesn't do const, resort to loops
        foreach(i, dep; dependencies) {
            files ~= text(dep.outputs.map!(a => dep.isLeaf ? buildPath(projectPath, a) : a).join(" "));
            if(i != dependencies.length - 1) files ~= " ";
        }
        return files;
    }

    @property string command(in string projectPath = "") @trusted pure const nothrow {
        //functional didn't work here, I don't know why so sticking with loops for now
        string[] depOutputs;
        foreach(dep; dependencies) {
            foreach(output; dep.outputs) {
                depOutputs ~= dep.isLeaf ? buildPath(projectPath, output) : output;
            }
        }
        auto replaceIn = _command.replace("$in", depOutputs.join(" "));
        auto replaceOut = replaceIn.replace("$out", outputs.join(" "));
        return replaceOut.replace("$project", projectPath);
    }

    bool isLeaf() @safe pure const nothrow {
        return dependencies is null;
    }

    //@trusted because of replace
    package string inOutCommand(in string projectPath = "") @trusted pure nothrow const {
        return _command.replace("$project", projectPath);
    }

private:

    string _command;
}
