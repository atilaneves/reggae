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
    const(Target)[] implicits;

    this(string output) {
        this(output, null, null);
    }

    this(string output, string command, in Target dependency, in Target[] implicits = []) {
        this([output], command, [dependency], implicits);
    }

    this(string output, string command, in Target[] dependencies, in Target[] implicits = []) {
        this([output], command, dependencies, implicits);
    }

    this(string[] outputs, string command, in Target[] dependencies, in Target[] implicits = []) {
        this.outputs = outputs;
        this.dependencies = dependencies;
        this.implicits = implicits;
        this._command = command;
    }

    @property string dependencyFiles(in string projectPath = "") @safe const nothrow {
        return depFilesImpl(dependencies, projectPath);
    }

    @property string implicitFiles(in string projectPath = "") @safe const nothrow {
        return depFilesImpl(implicits, projectPath);
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

    //@trusted because of join
    string depFilesImpl(in Target[] deps, in string projectPath) @trusted const nothrow {
        import std.conv;
        string files;
        //join doesn't do const, resort to loops
        foreach(i, dep; deps) {
            files ~= text(dep.outputs.map!(a => dep.isLeaf ? buildPath(projectPath, a) : a).join(" "));
            if(i != dependencies.length - 1) files ~= " ";
        }
        return files;
    }

}
