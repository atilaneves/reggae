/**
 This module contains the core data definitions that allow a build
 to be expressed in. $(D Build) is a container struct for top-level
 targets, $(D Target) is the heart of the system.
 */

module reggae.build;

import reggae.rules.defaults;
import std.string: replace;
import std.algorithm: map;
import std.path: buildPath;
import std.typetuple: allSatisfy;
import std.traits: Unqual, isSomeFunction, ReturnType, arity;
import std.array: array, join;


Target createTargetFromTarget(in Target target) {
    return Target(target.outputs,
                  target._command.removeBuilddir,
                  target.dependencies.map!(a => a.enclose(target)).array,
                  target.implicits.map!(a => a.enclose(target)).array);
}

/**
 Contains the top-level targets.
 */
struct Build {
    const(Target)[] targets;

    this(in Target[] targets) {
        this.targets = targets.map!createTargetFromTarget.array;
    }

    this(T...)(in T targets) {
        foreach(t; targets) {
            static if(isSomeFunction!(typeof(t))) {
                const target = t();
            } else {
                const target = t;
            }

            this.targets ~= createTargetFromTarget(target);
        }
    }
}

//a directory for each top-level target no avoid name clashes
//@trusted because of map -> buildPath -> array
Target enclose(in Target target, in Target topLevel) @trusted {
    if(target.isLeaf) return Target(target.outputs.map!(a => a._removeBuilddir).array,
                                    target._command.removeBuilddir,
                                    target.dependencies,
                                    target.implicits);

    immutable dirName = buildPath("objs", topLevel.outputs[0] ~ ".objs");
    return Target(target.outputs.map!(a => realTargetPath(dirName, a)).array,
                  target._command.removeBuilddir,
                  target.dependencies.map!(a => a.enclose(topLevel)).array,
                  target.implicits.map!(a => a.enclose(topLevel)).array);
}

immutable gBuilddir = "$builddir";


private string realTargetPath(in string dirName, in string output) @trusted pure {
    import std.algorithm: canFind;

    return output.canFind(gBuilddir)
        ? output._removeBuilddir
        : buildPath(dirName, output);
}

private string _removeBuilddir(in string output) @trusted pure {
    import std.path: buildNormalizedPath;
    import std.algorithm;
    return output.
        splitter.
        map!(a => a.canFind(gBuilddir) ? a.replace(gBuilddir, ".").buildNormalizedPath : a).
        join(" ");
}

enum isTarget(alias T) = is(Unqual!(typeof(T)) == Target) ||
    isSomeFunction!T && is(ReturnType!T == Target);

unittest {
    auto  t1 = Target();
    const t2 = Target();
    static assert(isTarget!t1);
    static assert(isTarget!t2);
}

mixin template buildImpl(targets...) if(allSatisfy!(isTarget, targets)) {
    Build buildFunc() {
        return Build(targets);
    }
}

/**
 Two variations on a template mixin. When reggae is used as a library,
 this will essentially build reggae itself as part of the build description.

 When reggae is used as a command-line tool to generate builds, it simply
 declares the build function that will be called at run-time. The tool
 will then compile the user's reggaefile.d with the reggae libraries,
 resulting in a buildgen executable.

 In either case, the compile-time parameters of $(D build) are the
 build's top-level targets.
 */
version(reggaelib) {
    mixin template build(targets...) if(allSatisfy!(isTarget, targets)) {
        mixin reggaeGen!(targets);
    }
} else {
    alias build = buildImpl;
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


/**
 The core of reggae's D-based DSL for describing build systems.
 Targets contain outputs, a command to generate those outputs,
 explicit dependencies and implicit dependencies. All dependencies
 are themselves $(D Target) structs.

 The command is given as a string. In this string, certain words
 have special meaning: $(D $in), $(D $out), $(D $project) and $(D builddir).

 $(D $in) gets expanded to all explicit dependencies.
 $(D $out) gets expanded to all outputs.
 $(D $project) gets expanded to the project directory (i.e. the directory including
 the source files to build that was given as a command-line argument). This can be
 useful when build outputs are to be placed in the source directory, such as
 automatically generated source files.
 $(D $builddir) expands to the build directory (i.e. where reggae was run from).
 */
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
        this._command = Command(command);
    }

    @property string dependencyFilesString(in string projectPath = "") @safe pure const nothrow {
        return depFilesStringImpl(dependencies, projectPath);
    }

    @property string implicitFilesString(in string projectPath = "") @safe pure const nothrow {
        return depFilesStringImpl(implicits, projectPath);
    }

    @property string command(in string projectPath = "") @trusted pure const nothrow {
        //functional didn't work here, I don't know why so sticking with loops for now
        string[] depOutputs;
        foreach(dep; dependencies) {
            foreach(output; dep.outputs) {
                //leaf objects are references to source files in the project path
                //those need their path built. Any other dependencies are in the
                //build path, so they don't need the same treatment
                depOutputs ~= dep.isLeaf ? buildPath(projectPath, output) : output;
            }
        }
        return _command.expand(projectPath, outputs.join(" "), depOutputs.join(" "));
    }

    bool isLeaf() @safe pure const nothrow {
        return dependencies is null && implicits is null;
    }

    //@trusted because of replace
    string rawCmdString(in string projectPath) @trusted pure nothrow const {
        return _command.rawCmdString(projectPath);
    }


    string shellCommand(in string projectPath = "") @safe pure const {
        return _command.isDefaultCommand ? defaultCommand(projectPath) : command(projectPath);
    }

    string[] outputsInProjectPath(in string projectPath) @safe pure nothrow const {
        return outputs.map!(a => isLeaf ? buildPath(projectPath, a) : a).array;
    }

private:

    Command _command;

    //@trusted because of join
    string depFilesStringImpl(in Target[] deps, in string projectPath) @trusted pure const nothrow {
        import std.conv;
        string files;
        //join doesn't do const, resort to loops
        foreach(i, dep; deps) {
            files ~= text(dep.outputsInProjectPath(projectPath).join(" "));
            if(i != deps.length - 1) files ~= " ";
        }
        return files;
    }

    //this function returns a string to be run by the shell with `std.process.execute`
    //it does 'normal' commands, not built-in rules
    string defaultCommand(in string projectPath) @safe pure const {
        import reggae.config: dCompiler, cppCompiler, cCompiler;

        immutable rawCmdLine = _command.rawCmdString(projectPath);
        immutable flags = rawCmdLine.getDefaultRuleParams("flags", []).join(" ");
        immutable includes = rawCmdLine.getDefaultRuleParams("includes", []).join(" ");
        immutable depfile = outputs[0] ~ ".dep";

        string ccCommand(in string compiler) {
            import std.stdio;
            debug writeln("ccCommand with compiler ", compiler);
            return [compiler, flags, includes, "-MMD", "-MT", outputs[0],
                    "-MF", depfile, "-o", outputs[0], "-c",
                    dependencyFilesString(projectPath)].join(" ");
        }


        immutable rule = rawCmdLine.getDefaultRule;
        import std.stdio;
        debug writeln("rule: ", rule);

        switch(rule) {

        case "_dcompile":
            immutable stringImports = rawCmdLine.getDefaultRuleParams("stringImports", []).join(" ");
            immutable command = [".reggae/dcompile",
                                 "--objFile=" ~ outputs[0],
                                 "--depFile=" ~ depfile, dCompiler,
                                 flags, includes, stringImports,
                                 dependencyFilesString(projectPath),
                ].join(" ");

            return command;

        case "_cppcompile": return ccCommand(cppCompiler);
        case "_ccompile":   return ccCommand(cCompiler);
        case "_link":
            return [dCompiler, "-of" ~ outputs[0],
                    flags,
                    dependencyFilesString(projectPath)].join(" ");
        default:
            assert(0, "Unknown default rule " ~ rule);
        }
    }
}

immutable allDefaultRules = ["_dcompile", "_ccompile", "_cppcompile", "_link"];

bool isDefaultRule(in string rule) @safe pure nothrow {
    return allDefaultRules.canFind(rule);
}

/**
 A command to be execute to produce a targets outputs from its inputs.
 In general this will be a shell command, but the high-level rules
 use commands with known semantics (compilation, linking, etc)
*/
struct Command {
    string command;

    private string getRule() @safe pure const {
        return command.splitter.front;
    }

    bool isDefaultCommand() @safe pure const {
        return isDefaultRule(getRule);
    }

    string getDefaultRule() @safe pure const {
        immutable rule = getRule;
        if(!isDefaultRule(rule)) {
            throw new Exception("Cannot get defaultRule from " ~ command);
        }

        return rule;
    }


    string[] getDefaultRuleParams(in string key) @safe pure const {
        return getDefaultRuleParams(key, false);
    }


    string[] getDefaultRuleParams(in string key, string[] ifNotFound) @safe pure const {
        return getDefaultRuleParams(key, true, ifNotFound);
    }

    string removeBuilddir() @safe pure const {
        return _removeBuilddir(command);
    }

    ///Replace $in, $out, $project with values
    string expand(in string projectPath, in string outputs, in string depOutputs) @safe pure nothrow const {
        auto replaceIn = command.dup.replace("$in", depOutputs);
        auto replaceOut = replaceIn.replace("$out", outputs);
        return replaceOut.replace("$project", projectPath);
    }

    //@trusted because of replace
    string rawCmdString(in string projectPath) @trusted pure nothrow const {
        return command.replace("$project", projectPath);
    }

    //@trusted because of replace
    private string[] getDefaultRuleParams(in string key,
                                          bool useIfNotFound, string[] ifNotFound = []) @trusted pure const {
        import std.conv: text;

        auto parts = command.splitter;
        immutable cmd = parts.front;
        if(!isDefaultRule(cmd)) {
            throw new Exception("Cannot get defaultRule from " ~ command);
        }

        auto fromParamPart = parts.find!(a => a.startsWith(key ~ "="));
        if(fromParamPart.empty) {
            if(useIfNotFound) {
                return ifNotFound;
            } else {
                throw new Exception ("Cannot get default rule from " ~ command);
            }
        }

        auto paramPart = fromParamPart.front;
        auto removeKey = paramPart.replace(key ~ "=", "");

        return removeKey.splitter(",").array;
    }
}
