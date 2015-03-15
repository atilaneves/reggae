module reggae.build;

import std.string: replace;
import std.algorithm: map, join;
import std.path: buildPath;
import std.typetuple: allSatisfy;
import std.traits: Unqual, isSomeFunction, ReturnType, arity;
import std.array: array;

struct Build {
    const(Target)[] targets;

    this(T...)(in T targets) {
        foreach(t; targets) {
            static if(isSomeFunction!(typeof(t))) {
                const target = t();
            } else {
                const target = t;
            }

            this.targets ~= Target(target.outputs,
                                   target._command,
                                   target.dependencies.map!(a => a.enclose(target)).array,
                                   target.implicits);
        }
    }
}

//a directory for each top-level target no avoid name clashes
//@trusted because of map -> buildPath -> array
Target enclose(in Target target, in Target topLevel) @trusted nothrow {
    if(target.isLeaf) return Target(target.outputs, target._command,
                                    target.dependencies, target.implicits);

    immutable dirName = buildPath("objs", topLevel.outputs[0] ~ ".objs");
    return Target(target.outputs.map!(a => realTargetPath(dirName, a)).array,
                  target._command,
                  target.dependencies.map!(a => a.enclose(topLevel)).array,
                  target.implicits);
}

private string realTargetPath(in string dirName, in string output) @trusted pure nothrow {
    import std.algorithm;
    import std.path: buildNormalizedPath;
    static immutable builddir = "$builddir";

    return output.canFind(builddir)
        ? output.replace(builddir, ".").buildNormalizedPath
        : buildPath(dirName, output);
}


enum isTarget(alias T) = is(Unqual!(typeof(T)) == Target) ||
    isSomeFunction!T && is(ReturnType!T == Target);

unittest {
    auto  t1 = Target();
    const t2 = Target();
    static assert(isTarget!t1);
    static assert(isTarget!t2);
}

mixin template build(T...) if(allSatisfy!(isTarget, T)) {
    Build buildFunc() {
        return Build(T);
    }
}


package template isBuildFunction(alias T) {
    static if(!isSomeFunction!T) {
        enum isBuildFunction = false;
    } else {
        enum isBuildFunction = is(ReturnType!T == Build) && arity!T == 0;
    }
}

unittest {
    Build myBuildFunction() { return Build(); }
    static assert(isBuildFunction!myBuildFunction);
    float foo;
    static assert(!isBuildFunction!foo);
}


struct Target {
    const(string)[] outputs;
    const(Target)[] dependencies;
    const(Target)[] implicits;

    this(in string output) @safe pure nothrow {
        this(output, null, null);
    }

    this(in string output, string command, in Target dependency,
         in Target[] implicits = []) @safe pure nothrow {
        this([output], command, [dependency], implicits);
    }

    this(in string output, string command,
         in Target[] dependencies, in Target[] implicits = []) @safe pure nothrow {
        this([output], command, dependencies, implicits);
    }

    this(in string[] outputs, string command,
         in Target[] dependencies, in Target[] implicits = []) @safe pure nothrow {
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
            if(i != deps.length - 1) files ~= " ";
        }
        return files;
    }
}
