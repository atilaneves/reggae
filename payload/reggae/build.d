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
import std.path: buildPath, dirSeparator;
import std.typetuple: allSatisfy;
import std.traits: Unqual, isSomeFunction, ReturnType, arity;
import std.array: array, join;
import std.conv;
import std.exception;
import std.typecons;
import std.range;
import std.typecons;


/**
 Contains the top-level targets.
 */
struct Build {
    static struct TopLevelTarget {
        Target target;
        bool optional;
    }

    private const(TopLevelTarget)[] _targets;

    this(in Target[] targets) {
        _targets = targets.map!createTopLevelTarget.array;
    }

    this(T...)(in T targets) {
        foreach(t; targets) {
            //the constructor needs to go from Target to TopLevelTarget
            //and accepts functions that return a parameter as well as parameters themselves
            //if a function, call it, if not, take the value
            //if the value is Target, call createTopLevelTarget, if not, take it as is
            static if(isSomeFunction!(typeof(t)) && is(ReturnType!(typeof(t))) == Target) {
                _targets ~= createTopLevelTarget(t());
            } else static if(is(Unqual!(typeof(t)) == TopLevelTarget)) {
                _targets ~= t;
            } else {
                _targets ~= createTopLevelTarget(t);
            }
        }
    }

    auto targets() @trusted pure nothrow const {
        return _targets.map!(a => a.target);
    }

    auto defaultTargets() @trusted pure nothrow const {
        return _targets.filter!(a => !a.optional).map!(a => a.target);
    }

    string defaultTargetsString(in string projectPath) @trusted pure const {
        return defaultTargets.map!(a => a.outputsInProjectPath(projectPath).join(" ")).join(" ");
    }

    auto range() @safe pure const {
        import reggae.range;
        return UniqueDepthFirst(this);
    }
}


/**
 Designate a target as optional so it won't be built by default.
 "Compile-time" version that can be aliased
 */
Build.TopLevelTarget optional(alias targetFunc)() {
    auto target = targetFunc();
    return createTopLevelTarget(target, true);
}

/**
 Designate a target as optional so it won't be built by default.
 */
Build.TopLevelTarget optional(in Target target) {
    return Build.TopLevelTarget(target, true);
}

Build.TopLevelTarget createTopLevelTarget(in Target target, bool optional = false) {
    return Build.TopLevelTarget(target.inTopLevelObjDirOf(topLevelDirName(target), Yes.topLevel),
                                optional);
}


immutable gBuilddir = "$builddir";
immutable gProjdir  = "$project";

//a directory for each top-level target no avoid name clashes
//@trusted because of map -> buildPath -> array
Target inTopLevelObjDirOf(in Target target, string dirName, Flag!"topLevel" isTopLevel = No.topLevel) @trusted {
    //leaf targets only get the $builddir expansion, nothing else
    //this is because leaf targets are by definition in the project path

    //every other non-top-level target gets its outputs placed in a directory
    //specific to its top-level parent

    if(target.outputs.any!(a => a.startsWith(gBuilddir) || a.startsWith(gProjdir))) {
         dirName = topLevelDirName(target);
    }

    const outputs = isTopLevel
        ? target.outputs.map!(a => expandBuildDir(a)).array
        : target.outputs.map!(a => realTargetPath(dirName, target, a)).array;

    return Target(outputs,
                  target._command.expandVariables,
                  target.dependencies.map!(a => a.inTopLevelObjDirOf(dirName)).array,
                  target.implicits.map!(a => a.inTopLevelObjDirOf(dirName)).array);
}


string topLevelDirName(in Target target) @safe pure {
    return buildPath("objs", target.outputs[0].expandBuildDir ~ ".objs");
}

//targets that have outputs with $builddir or $project in them want to be placed
//in a specific place. Those don't get touched. Other targets get
//placed in their top-level parent's object directory
string realTargetPath(in string dirName, in Target target, in string output) @trusted pure {
    return target.isLeaf
        ? expandBuildDir(output)
        : realTargetPath(dirName, output);
}


//targets that have outputs with $builddir or $project in them want to be placed
//in a specific place. Those don't get touched. Other targets get
//placed in their top-level parent's object directory
string realTargetPath(in string dirName, in string output) @trusted pure {
    import std.algorithm: canFind;

    if(output.startsWith(gProjdir)) return output;

    return output.canFind(gBuilddir)
        ? output.expandBuildDir
        : buildPath(dirName, output);
}

//replace $builddir with the current directory
string expandBuildDir(in string output) @trusted pure {
    import std.path: buildNormalizedPath;
    import std.algorithm;
    return output.
        splitter.
        map!(a => a.canFind(gBuilddir) ? a.replace(gBuilddir, ".").buildNormalizedPath : a).
        join(" ");
}

 enum isTarget(alias T) =
     is(Unqual!(typeof(T)) == Target) ||
     is(Unqual!(typeof(T)) == Build.TopLevelTarget) ||
     isSomeFunction!T && is(ReturnType!T == Target) ||
     isSomeFunction!T && is(ReturnType!T == Build.TopLevelTarget);

unittest {
    auto  t1 = Target();
    const t2 = Target();
    static assert(isTarget!t1);
    static assert(isTarget!t2);
    const t3 = Build.TopLevelTarget(Target());
    static assert(isTarget!t3);
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
    private const(Command) _command; ///see $(D Command) struct
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

    @property string dependencyFilesString(in string projectPath = "") @safe pure const {
        return depFilesStringImpl(dependencies, projectPath);
    }

    @property string implicitFilesString(in string projectPath = "") @safe pure const {
        return depFilesStringImpl(implicits, projectPath);
    }

    bool isLeaf() @safe pure const nothrow {
        return dependencies is null && implicits is null;
    }

    string[] outputsInProjectPath(in string projectPath) @safe pure const {
        string inProjectPath(in string path) {
            return path.startsWith(gProjdir)
                ? path
                : path.startsWith(gBuilddir)
                    ? path.replace(gBuilddir ~ dirSeparator, "")
                    : buildPath(projectPath, path);
        }

        return outputs.map!(a => isLeaf ? inProjectPath(a) : a).
            map!(a => a.replace("$project", projectPath)).array;
    }

    Language getLanguage() @safe pure nothrow const {
        import reggae.range: Leaves;
        const leaves = () @trusted { return Leaves(this).array; }();
        foreach(language; [Language.D, Language.Cplusplus, Language.C]) {
            if(leaves.any!(a => reggae.rules.common.getLanguage(a.outputs[0]) == language)) return language;
        }

        return Language.unknown;
    }

    ///Replace special variables and return a list of outputs thus modified
    auto expandOutputs(in string projectPath) @safe pure const {
        return outputsInProjectPath(projectPath).map!(a => a.replace(gBuilddir ~ dirSeparator, ""));
    }

    ///replace all special variables with their expansion
    @property string expandCommand(in string projectPath = "") @trusted pure const {
        return _command.expand(projectPath, outputs, inputs(projectPath));
    }

    //@trusted because of replace
    string rawCmdString(in string projectPath = "") @trusted pure const {
        return _command.rawCmdString(projectPath);
    }

    ///returns a command string to be run by the shell
    string shellCommand(in string projectPath = "",
                        Flag!"dependencies" deps = Yes.dependencies) @safe pure const {
        return _command.shellCommand(projectPath, getLanguage(), outputs, inputs(projectPath), deps);
    }

    string[] execute(in string projectPath = "") @safe const {
        return _command.execute(projectPath, getLanguage(), outputs, inputs(projectPath));
    }

    bool hasDefaultCommand() @safe const pure {
        return _command.isDefaultCommand;
    }

    CommandType getCommandType() @safe pure const nothrow {
        return _command.getType;
    }

    string[] getCommandParams(in string projectPath, in string key, string[] ifNotFound) @safe pure const {
        return _command.getParams(projectPath, key, ifNotFound);
    }

    const(string)[] commandParamNames() @safe pure nothrow const {
        return _command.paramNames;
    }

    static Target phony(in string output, in string shellCommand,
                        in Target[] dependencies = [], in Target[] implicits = []) @safe pure {
        return Target(output, Command.phony(shellCommand), dependencies, implicits);
    }

    string toString(string projectPath = "") const pure nothrow {
        try {
            if(isLeaf) return outputs[0];
            immutable outputs = outputs.length == 1 ? `"` ~ outputs[0] ~ `"` : text(outputs);
            immutable depsStr = dependencies.length == 0 ? "" : text(dependencies);
            immutable impsStr = implicits.length == 0 ? "" : text(implicits);
            auto parts = [text(outputs), `"` ~ shellCommand(projectPath) ~ `"`];
            if(depsStr != "") parts ~= depsStr;
            if(impsStr != "") parts ~= impsStr;
            return text("Target(", parts.join(", "), ")");
        } catch(Exception) {
            assert(0);
        }
    }

private:


    //@trusted because of join
    string depFilesStringImpl(in Target[] deps, in string projectPath) @trusted pure const {
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
                inputs ~= dep.isLeaf ? inProjectPath(projectPath, output) : output;
            }
        }
        return inputs;
    }
}

string inProjectPath(in string projectPath, in string name) @safe pure nothrow {
    if(name.startsWith(gBuilddir)) return name;
    return buildPath(projectPath, name);
}


enum CommandType {
    shell,
    compile,
    link,
    compileAndLink,
    code,
    phony,
}

alias CommandFunction = void function(in string[], in string[]);

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

    ///If constructed with a string, it's a shell command
    this(string shellCommand) @safe pure nothrow {
        command = shellCommand;
        type = CommandType.shell;
    }

    /**Explicitly request a command of this type with these parameters
       In general to create one of the builtin high level rules*/
    this(CommandType type, Params params = Params()) @safe pure {
        if(type == CommandType.shell) throw new Exception("Command rule cannot be shell");
        this.type = type;
        this.params = params;
    }

    ///A D function call command
    this(CommandFunction func) @safe pure nothrow {
        type = CommandType.code;
        this.func = func;
    }

    static Command phony(in string shellCommand) @safe pure nothrow {
        Command cmd;
        cmd.type = CommandType.phony;
        cmd.command = shellCommand;
        return cmd;
    }

    const(string)[] paramNames() @safe pure nothrow const {
        return params.keys;
    }

    CommandType getType() @safe pure const nothrow {
        return type;
    }

    bool isDefaultCommand() @safe pure const {
        return type == CommandType.compile || type == CommandType.link || type == CommandType.compileAndLink;
    }

    string[] getParams(in string projectPath, in string key, string[] ifNotFound) @safe pure const {
        return getParams(projectPath, key, true, ifNotFound);
    }

    const(Command) expandVariables() @safe pure const {
        switch(type) with(CommandType) {
        case shell:
            auto cmd = Command(expandBuildDir(command));
            cmd.type = this.type;
            return cmd;
        default:
            return this;
        }
    }

    ///Replace $in, $out, $project with values
    string expand(in string projectPath, in string[] outputs, in string[] inputs) @safe pure const {
        return expandCmd(command, projectPath, outputs, inputs);
    }

    private static string expandCmd(in string cmd, in string projectPath,
                                    in string[] outputs, in string[] inputs) @safe pure {
        auto replaceIn = cmd.dup.replace("$in", inputs.join(" "));
        auto replaceOut = replaceIn.replace("$out", outputs.join(" "));
        return replaceOut.replace("$project", projectPath).replace(gBuilddir ~ dirSeparator, "");
    }

    //@trusted because of replace
    string rawCmdString(in string projectPath) @trusted pure const {
        if(getType != CommandType.shell)
            throw new Exception("Command type 'code' not supported for ninja backend");
        return command.replace("$project", projectPath);
    }

    //@trusted because of replace
    private string[] getParams(in string projectPath, in string key,
                               bool useIfNotFound, string[] ifNotFound = []) @safe pure const {
        return params.get(key, ifNotFound).map!(a => a.replace("$project", projectPath)).array;
    }

    static string builtinTemplate(CommandType type,
                                  Language language,
                                  Flag!"dependencies" deps = Yes.dependencies) @safe pure {
        import reggae.config: options;

        final switch(type) with(CommandType) {
            case phony:
                assert(0, "builtinTemplate cannot be phony");

            case shell:
                assert(0, "builtinTemplate cannot be shell");

            case link:
                final switch(language) with(Language) {
                    case D:
                    case unknown:
                        return options.dCompiler ~ " -of$out $flags $in";
                    case Cplusplus:
                        return options.cppCompiler ~ " -o $out $flags $in";
                    case C:
                        return options.cCompiler ~ " -o $out $flags $in";
                }

            case code:
                throw new Exception("Command type 'code' has no built-in template");

            case compile:
                return compileTemplate(type, language, deps).replace("$out $in", "$out -c $in");

            case compileAndLink:
                return compileTemplate(type, language, deps);
        }
    }

    private static string compileTemplate(CommandType type,
                                          Language language,
                                          Flag!"dependencies" deps = Yes.dependencies) @safe pure {
        import reggae.config: options;

        immutable ccParams = deps
            ? " $flags $includes -MMD -MT $out -MF $out.dep -o $out $in"
            : " $flags $includes -o $out $in";

        final switch(language) with(Language) {
            case D:
                return deps
                    ? ".reggae/dcompile --objFile=$out --depFile=$out.dep " ~
                    options.dCompiler ~ " $flags $includes $stringImports $in"
                    : options.dCompiler ~ " $flags $includes $stringImports -of$out $in";
            case Cplusplus:
                return options.cppCompiler ~ ccParams;
            case C:
                return options.cCompiler ~ ccParams;
            case unknown:
                throw new Exception("Unsupported language for compiling");
        }
    }

    string defaultCommand(in string projectPath,
                          in Language language,
                          in string[] outputs,
                          in string[] inputs,
                          Flag!"dependencies" deps = Yes.dependencies) @safe pure const {
        assert(isDefaultCommand, text("This command is not a default command: ", this));
        auto cmd = builtinTemplate(type, language, deps);
        foreach(key; params.keys) {
            immutable var = "$" ~ key;
            immutable value = getParams(projectPath, key, []).join(" ");
            cmd = cmd.replace(var, value);
        }
        return expandCmd(cmd, projectPath, outputs, inputs);
    }

    ///returns a command string to be run by the shell
    string shellCommand(in string projectPath,
                        in Language language,
                        in string[] outputs,
                        in string[] inputs,
                        Flag!"dependencies" deps = Yes.dependencies) @safe pure const {
        return isDefaultCommand
            ? defaultCommand(projectPath, language, outputs, inputs, deps)
            : expand(projectPath, outputs, inputs);
    }


    string[] execute(in string projectPath, in Language language,
                     in string[] outputs, in string[] inputs) const @trusted {
        import std.process;

        final switch(type) with(CommandType) {
            case shell:
            case compile:
            case link:
            case compileAndLink:
            case phony:
                immutable cmd = shellCommand(projectPath, language, outputs, inputs);
                immutable res = executeShell(cmd);
                enforce(res.status == 0, "Could not execute phony " ~ cmd ~ ":\n" ~ res.output);
                return [cmd, res.output];
            case code:
                assert(func !is null, "Command of type code with null function");
                func(inputs, outputs);
                return [];
        }
    }

    ubyte[] toBytes() @safe pure nothrow const {
        return [];
    }

    static Command fromBytes(in ubyte[] bytes) @safe pure nothrow {
        return Command();
    }
}
