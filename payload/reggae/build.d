/**
 This module contains the core data definitions that allow a build
 to be expressed in. $(D Build) is a container struct for top-level
 targets, $(D Target) is the heart of the system.
 */

module reggae.build;
import reggae.ctaa;
import reggae.rules.common: Language, getLanguage;

import std.string: replace;
import std.algorithm;
import std.path: buildPath;
import std.typetuple: allSatisfy;
import std.traits: Unqual, isSomeFunction, ReturnType, arity;
import std.array: array, join;
import std.conv;
import std.exception;

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
        this(output, "", null);
    }

    this(C)(in string output,
            in C command,
            in Target dependency,
            in Target[] implicits = []) @safe pure nothrow {
        this([output], command, [dependency], implicits);
    }

    this(C)(in string output,
            in C command,
            in Target[] dependencies,
            in Target[] implicits = []) @safe pure nothrow {
        this([output], command, dependencies, implicits);
    }

    this(C)(in string[] outputs,
            in C command,
            in Target[] dependencies,
            in Target[] implicits = []) @safe pure nothrow {

        this.outputs = outputs;
        this.dependencies = dependencies;
        this.implicits = implicits;

        static if(is(C == Command))
            this._command = command;
        else
            this._command = Command(command);
    }

    @property string dependencyFilesString(in string projectPath = "") @safe pure const nothrow {
        return depFilesStringImpl(dependencies, projectPath);
    }

    @property string implicitFilesString(in string projectPath = "") @safe pure const nothrow {
        return depFilesStringImpl(implicits, projectPath);
    }

    ///replace all special variables with their expansion
    @property string expandCommand(in string projectPath = "") @trusted pure const nothrow {
        return _command.expand(projectPath, outputs, inputs(projectPath));
    }

    bool isLeaf() @safe pure const nothrow {
        return dependencies is null && implicits is null;
    }

    //@trusted because of replace
    string rawCmdString(in string projectPath) @trusted pure nothrow const {
        return _command.rawCmdString(projectPath);
    }

    ///returns a command string to be run by the shell
    string shellCommand(in string projectPath = "") @safe pure const {
        return _command.shellCommand(projectPath, outputs, inputs(projectPath));
    }

    string[] outputsInProjectPath(in string projectPath) @safe pure nothrow const {
        return outputs.map!(a => isLeaf ? buildPath(projectPath, a) : a).array;
    }

    @property const(Command) command() @safe const pure nothrow { return _command; }

    Language getLanguage() @safe pure nothrow const {
        return reggae.rules.common.getLanguage(inputs("")[0]);
    }

    void execute(in string projectPath = "") @safe const {
        _command.execute(projectPath, outputs, inputs(projectPath));
    }


private:

    const(Command) _command;

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

    string[] inputs(in string projectPath) @safe pure nothrow const {
        //functional didn't work here, I don't know why so sticking with loops for now
        string[] inputs;
        foreach(dep; dependencies) {
            foreach(output; dep.outputs) {
                //leaf objects are references to source files in the project path,
                //those need their path built. Any other dependencies are in the
                //build path, so they don't need the same treatment
                inputs ~= dep.isLeaf ? buildPath(projectPath, output) : output;
            }
        }
        return inputs;
    }
}


enum CommandType {
    shell,
    compile,
    link,
    code,
}

alias CommandFunction = void function();

/**
 A command to be execute to produce a targets outputs from its inputs.
 In general this will be a shell command, but the high-level rules
 use commands with known semantics (compilation, linking, etc)
*/
struct Command {
    alias Params = AssocList!(string, string[]);

    private string command;
    private CommandType type;
    private Params params;
    private CommandFunction func;

    this(string shellCommand) @safe pure nothrow {
        command = shellCommand;
        type = CommandType.shell;
    }

    this(CommandType type, Params params) @safe pure {
        if(type == CommandType.shell) throw new Exception("Command rule cannot be shell");
        this.type = type;
        this.params = params;
    }

    this(CommandFunction func) @safe pure nothrow {
        type = CommandType.code;
        this.func = func;
    }

    const(string)[] paramNames() @safe pure nothrow const {
        return params.keys;
    }

    CommandType getType() @safe pure const {
        return type;
    }

    bool isDefaultCommand() @safe pure const {
        return type != CommandType.shell;
    }

    string[] getParams(in string projectPath, in string key, string[] ifNotFound) @safe pure const {
        return getParams(projectPath, key, true, ifNotFound);
    }

    Command removeBuilddir() @safe pure const {
        auto cmd = Command(_removeBuilddir(command));
        cmd.type = this.type;
        //FIXME
        () @trusted {
            cmd.params = cast()this.params;
        }();
        return cmd;
    }

    ///Replace $in, $out, $project with values
    string expand(in string projectPath, in string[] outputs, in string[] inputs) @safe pure nothrow const {
        return expandCmd(command, projectPath, outputs, inputs);
    }

    private static string expandCmd(in string cmd, in string projectPath,
                                    in string[] outputs, in string[] inputs) @safe pure nothrow {
        auto replaceIn = cmd.dup.replace("$in", inputs.join(" "));
        auto replaceOut = replaceIn.replace("$out", outputs.join(" "));
        return replaceOut.replace("$project", projectPath);
    }

    //@trusted because of replace
    string rawCmdString(in string projectPath) @trusted pure nothrow const {
        return command.replace("$project", projectPath);
    }

    //@trusted because of replace
    private string[] getParams(in string projectPath, in string key,
                               bool useIfNotFound, string[] ifNotFound = []) @safe pure const {
        return params.get(key, ifNotFound).map!(a => a.replace("$project", projectPath)).array;
    }

    static string builtinTemplate(CommandType type, Language language) @safe pure {
        import reggae.config: dCompiler, cppCompiler, cCompiler;

        immutable ccParams = " $flags $includes -MMD -MT $out -MF $DEPFILE -o $out -c $in";

        final switch(type) with(CommandType) {
            case shell:
                assert(0, "builtinTemplate cannot be shell");

            case link:
                return dCompiler ~ " -of$out $flags $in";

            case code:
                throw new Exception("Command type 'code' has no built-in template");

            case compile:
                final switch(language) with(Language) {
                    case D:
                        return ".reggae/dcompile --objFile=$out --depFile=$DEPFILE " ~
                            dCompiler ~ " $flags $includes $stringImports $in";
                    case Cplusplus:
                        return cppCompiler ~ ccParams;
                    case C:
                        return cCompiler ~ ccParams;
                    case unknown:
                        throw new Exception("Unsupported language");
                }
        }
    }

    string defaultCommand(in string projectPath, in string[] outputs, in string[] inputs) @safe pure const {
        assert(isDefaultCommand, text("This command is not a default command: ", this));
        immutable language = getLanguage(inputs[0]);
        auto cmd = builtinTemplate(type, language);
        foreach(key; params.keys) {
            immutable var = "$" ~ key;
            immutable value = getParams(projectPath, key, []).join(" ");
            cmd = cmd.replace(var, value);
        }
        return expandCmd(cmd, projectPath, outputs, inputs);
    }

    ///returns a command string to be run by the shell
    string shellCommand(in string projectPath, in string[] outputs, in string[] inputs) @safe pure const {
        return isDefaultCommand
            ? defaultCommand(projectPath, outputs, inputs)
            : expand(projectPath, outputs, inputs);
    }


    void execute(in string projectPath, in string[] outputs, in string[] inputs) const @trusted {
        import std.process;
        import std.stdio;

        switch(type) with(CommandType) {
            case shell:
                immutable cmd = shellCommand(projectPath, outputs, inputs);
                immutable res = executeShell(cmd);
                enforce(res.status == 0, "Could not execute" ~ cmd ~ ":\n" ~ res.output);
                break;
            case code:
                assert(func !is null, "Command of type code with null function");
                func();
                break;
            default:
                throw new Exception(text("Cannot execute unsupported command type ", type));
        }
    }

}
