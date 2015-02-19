module reggae.build;

import reggae.rules: exeExt;
import std.string: replace;
import std.algorithm: map, join;
import std.path: buildPath, baseName, stripExtension, defaultExtension;
import std.typetuple: allSatisfy;
import std.traits: Unqual, isSomeFunction, ReturnType, arity;

struct Build {
    const(Target)[] targets;

    this(in Target target) {
        this.targets = [target];
    }
}

enum isTarget(alias T) = is(Unqual!(typeof(T)) == Target);

unittest {
    auto  t1 = Target();
    const t2 = Target();
    static assert(isTarget!t1);
    static assert(isTarget!t2);
}

mixin template build(T...) if(allSatisfy!(isTarget, T)) {
    auto buildFunc() {
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

package enum isBuildObject(alias T) = is(typeof(T)) && is(Unqual!(typeof(T)) == Build);

unittest {
    Build bld;
    static assert(isBuildObject!bld);
    int i;
    static assert(!isBuildObject!i);
}

struct App {
    string srcFileName;
    string exeFileName;

    this(string srcFileName) @safe pure nothrow {
        immutable stripped = srcFileName.baseName.stripExtension;
        immutable exeFileName =  exeExt == "" ? stripped : stripped.defaultExtension(exeExt);

        this(srcFileName, exeFileName);
    }

    this(string srcFileName, string exeFileName) @safe pure nothrow {
        this.srcFileName = srcFileName;
        this.exeFileName = exeFileName;
    }
}


struct Flags {
    string flags;
}

struct ImportPaths {
    string[] paths;
}

struct StringImportPaths {
    string[] paths;
}

struct SrcDirs {
    string[] paths;
}

struct SrcFiles {
    string[] paths;
}

struct ExcludeFiles {
    string[] paths;
}

struct Target {
    string[] outputs;
    const(Target)[] dependencies;
    const(Target)[] implicits;

    this(string output) @safe pure nothrow {
        this(output, null, null);
    }

    this(string output, string command, in Target dependency,
         in Target[] implicits = []) @safe pure nothrow {
        this([output], command, [dependency], implicits);
    }

    this(string output, string command,
         in Target[] dependencies, in Target[] implicits = []) @safe pure nothrow {
        this([output], command, dependencies, implicits);
    }

    this(string[] outputs, string command,
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
