/**
 This module contains the core data definitions that allow a build
 to be expressed in. $(D Build) is a container struct for top-level
 targets, $(D Target) is the heart of the system.
 */

module reggae.build;

import reggae.ctaa;
import reggae.rules.common: Language, getLanguage;
import reggae.options;
import reggae.path: buildPath, deabsolutePath;

import std.string: replace;
import std.algorithm;
import std.path: dirSeparator;
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

    private TopLevelTarget[] _targets;

    this(Target[] targets) {
        _targets = targets.map!createTopLevelTarget.array;
    }

    this(R)(R targets) if(isInputRange!R && is(Unqual!(ElementType!R) == TopLevelTarget)) {
        _targets = targets.array;
    }

    this(T...)(T targets) {
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

    auto targets() @trusted pure nothrow {
        return _targets.map!(a => a.target);
    }

    auto defaultTargets() @trusted pure nothrow {
        return _targets.filter!(a => !a.optional).map!(a => a.target);
    }

    string[] defaultTargetsOutputs(in string projectPath) @trusted pure {
        return defaultTargets.map!(a => a.expandOutputs(projectPath)).join();
    }

    auto range() @safe pure {
        import reggae.range;
        return UniqueDepthFirst(this);
    }

    ubyte[] toBytes(in Options options) @safe pure {
        ubyte[] bytes;
        bytes ~= setUshort(cast(ushort)targets.length);
        foreach(t; targets) bytes ~= t.toBytes(options);
        return bytes;
    }

    static Build fromBytes(ubyte[] bytes) @trusted {
        immutable length = getUshort(bytes);
        auto build = Build();
        foreach(_; 0 .. length) {
            build._targets ~= TopLevelTarget(Target.fromBytes(bytes), false);
        }
        return build;
    }
}


/**
 Designate a target as optional so it won't be built by default.
 "Compile-time" version that can be aliased
 */
Build.TopLevelTarget optional(alias targetFunc)() {
    return optional(targetFunc());
}

/**
 Designate a target as optional so it won't be built by default.
 */
Build.TopLevelTarget optional(Target target) {
    return createTopLevelTarget(target, true);
}

Build.TopLevelTarget createTopLevelTarget(Target target, bool optional = false) {
    return Build.TopLevelTarget(target.inTopLevelObjDirOf(objDirOf(target), Yes.topLevel), optional);
}


immutable gBuilddir = "$builddir";
immutable gProjdir  = "$project";

//a directory for each top-level target to avoid name clashes
//@trusted because of map -> buildPath -> array
Target inTopLevelObjDirOf(Target target, string objDir, Flag!"topLevel" isTopLevel = No.topLevel) @trusted {
    if (target._outputs.any!(a => a.startsWith(gBuilddir) || a.startsWith(gProjdir)))
        objDir = objDirOf(target);

    // base dir for relative outputs:
    const baseDir = isTopLevel ? null :        // don't touch top-level target outputs
                    target.isLeaf ? gProjdir : // leaf targets are src files in the project dir
                    objDir;                    // obj directory specific to top-level target

    auto outputs = target._outputs.map!(a => expandOutput(a, gProjdir, baseDir)).array;

    return Target(outputs,
                  target._command.expandVariables,
                  target._dependencies.map!(a => a.inTopLevelObjDirOf(objDir)).array,
                  target._implicits.map!(a => a.inTopLevelObjDirOf(objDir)).array);
}


string objDirOf(in Target target) @safe pure nothrow {
    // remove $builddir and shorten $project to __project__
    const output = expandOutput(target._outputs[0], "__project__");
    return buildPath(".reggae", "objs", output.deabsolutePath ~ ".objs");
}

string expandOutput(string path, in string projectPath, in string basePath = null) @safe pure nothrow {
    path = buildPath(path); // normalize to native slashes
    // $builddir/foo => foo
    if (path.startsWith(gBuilddir ~ dirSeparator)) return path[gBuilddir.length+1 .. $];
    // $project/foo => <projectPath>/foo
    if (path.startsWith(gProjdir ~ dirSeparator)) return buildPath(projectPath, path[gProjdir.length+1 .. $]);
    // don't touch paths starting with env variables
    if (path.startsWith("$")) return path;
    // /foo => /foo
    // bar => <basePath>/bar
    return buildPath(basePath, path);
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


private static auto arrayify(E, T)(T value) {
    import std.array: array;

    static if(isInputRange!T && is(Unqual!(ElementType!T) == E))
        return value.array;
    else static if(is(Unqual!T == E))
        return [value];
    else static if(is(Unqual!T == void[])) {
        E[] nothing;
        return nothing;
    } else static if(is(Unqual!T == string))
        return [E(value)];
    else {
        import std.conv: text;
        static assert(false, text("Can not arraify value of type ", T.stringof));
    }
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
    private string[] _outputs;
    private Command _command; ///see $(D Command) struct
    private Target[] _dependencies;
    private Target[] _implicits;

    enum Target[] noTargets = [];

    this(string output) @safe pure nothrow {
        this(output, "", noTargets, noTargets);
    }

    this(O, C)(O outputs, C command) {
        this(outputs, command, noTargets, noTargets);
    }

    this(O, C, D)(O outputs, C command, D dependencies) {
        this(outputs, command, dependencies, noTargets);
    }

    this(O, C, D, I)(O outputs, C command, D dependencies, I implicits) {

        this._outputs = arrayify!string(outputs);

        static if(is(C == Command))
            this._command = command;
        else
            this._command = Command(command);

        this._dependencies = arrayify!Target(dependencies);
        this._implicits = arrayify!Target(implicits);
    }

    /**
       The outputs without expanding special variables
     */
    @property inout(string)[] rawOutputs(in string projectPath = "") @safe pure inout {
        return _outputs;
    }

    @property inout(Target)[] dependencyTargets(in string projectPath = "") @safe pure nothrow inout {
        return _dependencies;
    }

    @property inout(Target)[] implicitTargets(in string projectPath = "") @safe pure nothrow inout {
        return _implicits;
    }

    @property string[] dependenciesInProjectPath(in string projectPath) @safe pure const {
        return depsInProjectPath(_dependencies, projectPath);
    }

    @property string[] implicitsInProjectPath(in string projectPath) @safe pure const {
        return depsInProjectPath(_implicits, projectPath);
    }

    bool isLeaf() @safe pure const nothrow {
        return _dependencies is null && _implicits is null && getCommandType == CommandType.shell && _command.command == "";
    }

    Language getLanguage() @safe pure const nothrow {
        import reggae.range: Leaves;
        import reggae.rules.common: getLanguage;
        import std.algorithm: any;

        auto leaves = () @trusted { return Leaves(this).array; }();

        foreach(language; [Language.D, Language.Cplusplus, Language.C]) {
            if(leaves.any!(a => a._outputs.length && .getLanguage(a._outputs[0]) == language))
                return language;
        }

        return Language.unknown;
    }

    ///Replace special variables and return a list of outputs thus modified
    string[] expandOutputs(in string projectPath) @safe pure const {
        return _outputs.map!(o => expandOutput(o, projectPath)).array;
    }

    string rawCmdString(in string projectPath = "") @safe pure const {
        return _command.rawCmdString(projectPath);
    }

    ///returns a command string to be run by the shell
    string shellCommand(in Options options,
                        Flag!"dependencies" deps = Yes.dependencies) @safe pure const {
        return _command.shellCommand(options, getLanguage(), _outputs, inputs(options.projectPath), deps);
    }

    // not const because the code commands take inputs and outputs as non-const strings
    const(string)[] execute(in Options options) @safe const {
        return _command.execute(options, getLanguage(), _outputs, inputs(options.projectPath));
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

    static Target phony(T...)(string name, string shellCommand, T args) {
        return Target(name, Command.phony(shellCommand), args);
    }

    string toString(in Options options) nothrow const {
        try {
            if(isLeaf) return _outputs[0];
            immutable _outputs = _outputs.length == 1 ? `"` ~ _outputs[0] ~ `"` : text(_outputs);
            immutable depsStr = _dependencies.length == 0 ? "" : text(_dependencies);
            immutable impsStr = _implicits.length == 0 ? "" : text(_implicits);
            auto parts = [text(_outputs), `"` ~ shellCommand(options) ~ `"`];
            if(depsStr != "") parts ~= depsStr;
            if(impsStr != "") parts ~= impsStr;
            return text("Target(", parts.join(",\n"), ")");
        } catch(Exception) {
            assert(0);
        }
    }

    ubyte[] toBytes(in Options options) @safe pure const {
        ubyte[] bytes;
        bytes ~= setUshort(cast(ushort)_outputs.length);
        foreach(output; _outputs) {
            bytes ~= arrayToBytes(expandOutput(output, options.projectPath, isLeaf ? options.projectPath : null));
        }

        bytes ~= arrayToBytes(shellCommand(options));

        bytes ~= setUshort(cast(ushort)_dependencies.length);
        foreach(dep; _dependencies) bytes ~= dep.toBytes(options);

        bytes ~= setUshort(cast(ushort)_implicits.length);
        foreach(imp; _implicits) bytes ~= imp.toBytes(options);

        return bytes;
    }

    static Target fromBytes(ref ubyte[] bytes) @trusted pure nothrow {
        string[] outputs;
        immutable numOutputs = getUshort(bytes);

        foreach(i; 0 .. numOutputs) {
            outputs ~= cast(string)bytesToArray!char(bytes);
        }

        auto command = Command(cast(string)bytesToArray!char(bytes));

        Target[] dependencies;
        immutable numDeps = getUshort(bytes);
        foreach(i; 0..numDeps) dependencies ~= Target.fromBytes(bytes);

        Target[] implicits;
        immutable numImps = getUshort(bytes);
        foreach(i; 0..numImps) implicits ~= Target.fromBytes(bytes);

        return Target(outputs, command, dependencies, implicits);
    }

    bool opEquals()(auto ref const Target other) @safe pure const {

        bool sameSet(T)(const(T)[] fst, const(T)[] snd) {
            if(fst.length != snd.length) return false;
            return fst.all!(a => snd.any!(b => a == b));
        }

        return
            sameSet(_outputs, other._outputs) &&
            _command == other._command &&
            sameSet(_dependencies, other._dependencies) &&
            sameSet(_implicits, other._implicits);
    }

private:

    string[] depsInProjectPath(in Target[] deps, in string projectPath) @safe pure const {
        import reggae.range;
        return deps.map!(a => a.expandOutputs(projectPath)).join;
    }

    string[] inputs(in string projectPath) @safe pure nothrow const {
        //functional didn't work here, I don't know why so sticking with loops for now
        string[] inputs;
        foreach(dep; _dependencies) {
            foreach(output; dep._outputs) {
                //leaf objects are references to source files in the project path,
                //those need their path built. Any other dependencies are in the
                //build path, so they don't need the same treatment
                inputs ~= expandOutput(output, projectPath, dep.isLeaf ? projectPath : null);
            }
        }
        return inputs;
    }
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
alias CommandDelegate = void delegate(in string[], in string[]);

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
    private CommandFunction function_;
    private CommandDelegate delegate_;

    ///If constructed with a string, it's a shell command
    this(string shellCommand) @safe pure nothrow {
        command = shellCommand;
        type = CommandType.shell;
    }

    /**Explicitly request a command of this type with these parameters
       In general to create one of the builtin high level rules*/
    this(CommandType type, Params params = Params()) @safe pure {
        if(type == CommandType.shell || type == CommandType.code)
            throw new Exception("Command rule cannot be shell or code");
        this.type = type;
        this.params = params;
    }

    ///A D function call command
    this(CommandDelegate dg) @safe pure nothrow {
        type = CommandType.code;
        this.delegate_ = dg;
    }

    ///A D function call command
    this(CommandFunction func) @safe pure nothrow {
        type = CommandType.code;
        this.function_ = func;
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

    Command expandVariables() @safe pure {
        switch(type) with(CommandType) {
            case shell:
            case phony:
                string expCommand = command.replace(gBuilddir ~ dirSeparator, "");
                version(Windows)
                    expCommand = expCommand.replace(gBuilddir ~ "/", "");
                expCommand = expCommand.replace(gBuilddir, ".");
                auto cmd = Command(expCommand);
                cmd.type = this.type;
                return cmd;
            default:
                return this;
        }
    }

    ///Replace $in, $out, $project with values and remove $builddir
    private static string expandCmd(in string cmd, in string projectPath,
                                    in string[] outputs, in string[] inputs) @safe pure {
        auto outs = outputs.map!buildPath;
        auto ins = inputs.map!buildPath;
        auto replaceIn = cmd.dup.replace("$in", ins.join(" "));
        auto replaceOut = replaceIn.replace("$out", outs.join(" "));
        auto r = replaceOut.replace(gProjdir, buildPath(projectPath));
        r = r.replace(gBuilddir ~ dirSeparator, "");
        version(Windows)
            r = r.replace(gBuilddir ~ "/", "");
        r = r.replace(gBuilddir, ".");
        return r;
    }

    string rawCmdString(in string projectPath) @safe pure const {
        if(getType != CommandType.shell)
            throw new Exception("Command type 'code' not supported for ninja backend");
        return command.replace(gProjdir, buildPath(projectPath));
    }

    private string[] getParams(string projectPath, in string key,
                               bool useIfNotFound, string[] ifNotFound = []) @safe pure const {
        projectPath = buildPath(projectPath);
        return params.get(key, ifNotFound).map!(a => a.replace(gProjdir, projectPath)).array;
    }

    static private string[] getDefaultDCompilerModelArg(in Options options) @safe pure nothrow {
        version(Windows) {
            import std.path: baseName, stripExtension;
            const isDMD = baseName(stripExtension(options.dCompiler)) == "dmd";
            return isDMD ? ["-m32mscoff"] : null;
        } else {
            return null;
        }
    }

    // public because ninja needs string[] instead of a shell command to execute.
    static string[] builtinTemplate(in CommandType type,
                                    in Language language,
                                    in Options options,
                                    in Flag!"dependencies" deps = Yes.dependencies) @safe pure {

        import std.algorithm : startsWith, endsWith;

        final switch(type) with(CommandType) {
            case phony:
                assert(0, "builtinTemplate cannot be phony");

            case shell:
                assert(0, "builtinTemplate cannot be shell");

            case link: {
                version(Windows)
                    auto cArgs = ["/nologo", "/Fo$out", "$flags", "$in"];
                else
                    auto cArgs = ["-o", "$out", "$flags", "$in"];

                final switch(language) with(Language) {
                    case D:
                    case unknown:
                        return options.dCompiler ~ getDefaultDCompilerModelArg(options) ~ ["-of$out", "$flags", "$in"];
                    case Cplusplus:
                        return options.cppCompiler ~ cArgs;
                    case C:
                        return options.cCompiler ~ cArgs;
                }
            }

            case code:
                throw new Exception("Command type 'code' has no built-in template");

            case compile:

                auto template_ = compileTemplate(type, language, options, deps);

                string[] outThenIn() {
                    foreach(i; 0 .. template_.length - 1) {
                        if(template_[i].endsWith("$out") && template_[i+1].startsWith("$in"))
                           return template_[i .. i + 2];
                    }
                    return [];
                }

                const toReplace = outThenIn;
                return toReplace
                    ? template_.replace(toReplace, [toReplace[0], "-c", toReplace[1]])
                    : template_;

            case compileAndLink:
                return compileTemplate(type, language, options, deps);
        }
    }

    // The `deps` flag is whether or not to automatically compute dependencies for D files.
    // The reason for its existence is that tup does it itself.
    private static string[] compileTemplate(in CommandType type,
                                            in Language language,
                                            in Options options,
                                            in Flag!"dependencies" deps = Yes.dependencies) @safe pure {

        import std.path: baseName, stripExtension;
        import std.algorithm: among;

        version(Windows)
        {
            auto ccParams =
                ["/nologo", "$flags", "$includes"] ~ (deps ? ["/showIncludes"] : null) ~ ["/Fo$out", "$in"];
        }
        else
        {
            auto ccParams = deps
                ? ["$flags", "$includes", "-MMD", "-MT", "$out", "-MF", "$out.dep", "-o", "$out", "$in"]
                : ["$flags", "$includes", "-o", "$out", "$in"];
        }

        final switch(language) with(Language) {
            case D: {
                const compilerBinName = baseName(stripExtension(options.dCompiler));
                const colour = compilerBinName == "gdc"
                    ? "-fdiagnostics-color=always"
                    : compilerBinName.among("ldc", "ldc2")
                    ? "-enable-color"
                    : "-color=on";
                const output = compilerBinName == "gdc"
                    ? "-o$out"
                    : "-of$out";
                const modelArg = getDefaultDCompilerModelArg(options);
                const prefix = deps
                    ? buildPath(".reggae/dcompile") ~ ["--objFile=$out", "--depFile=$out.dep"]
                    : [];
                const postfix = deps
                    ? ["$in"]
                    : [output, "$in"];
                auto meat = options.dCompiler ~ modelArg ~ ["$flags", "$includes", "$stringImports", output, colour, "-c"];
                return prefix ~ meat ~ postfix;
            }
            case Cplusplus:
                return options.cppCompiler ~ ccParams;
            case C:
                return options.cCompiler ~ ccParams;
            case unknown:
                throw new Exception("Unsupported language for compiling");
        }
    }

    private string defaultCommand(
        in Options options,
        in Language language,
        in string[] outputs,
        in string[] inputs,
        Flag!"dependencies" deps = Yes.dependencies)
        @safe pure const
    {

        import std.conv: text;
        import std.string: join;
        import std.process : escapeShellCommand;
        import std.algorithm : map, canFind;
        import std.array : array;

        assert(isDefaultCommand, text("This command is not a default command: ", this));

        auto cmd = () {
            try
                return
                    builtinTemplate(type, language, options, deps)
                    .array;
            catch(Exception ex)
                throw new Exception(text(ex.msg, "\noutputs: ", outputs, "\ninputs: ", inputs));
        }();

        foreach(key; params.keys) {
            const var = "$" ~ key;
            const value = getParams(options.projectPath, key, []);
            cmd = cmd.replace(var, value);
        }

        auto cmdString = cmd
            .map!(e => e.canFind(" ") ? escapeShellCommand(e) : e)
            .join(" ");

        // FIXME: expandCmd should take string[]
        return expandCmd(cmdString, options.projectPath, outputs, inputs);
    }

    ///returns a command string to be run by the shell
    string shellCommand(in Options options,
                        in Language language,
                        in string[] outputs,
                        in string[] inputs,
                        Flag!"dependencies" deps = Yes.dependencies) @safe pure const {
        return isDefaultCommand
            ? defaultCommand(options, language, outputs, inputs, deps)
            : expandCmd(command, options.projectPath, outputs, inputs);
    }

    const(string)[] execute(in Options options, in Language language,
                            in string[] outputs, in string[] inputs) const @trusted {
        import std.process;

        final switch(type) with(CommandType) {
            case shell:
            case compile:
            case link:
            case compileAndLink:
            case phony:
                immutable cmd = shellCommand(options, language, outputs, inputs);
                if(cmd == "") return outputs;

                const string[string] env = null;
                Config config = Config.none;
                size_t maxOutput = size_t.max;

                immutable res = executeShell(cmd, env, config, maxOutput, options.workingDir);
                enforce(res.status == 0, "Could not execute phony " ~ cmd ~ ":\n" ~ res.output);
                return [res.output];
            case code:
                assert(function_ !is null || delegate_ !is null,
                       "Command of type code with null function");
                function_ !is null ? function_(inputs, outputs) : delegate_(inputs, outputs);
                return ["code"];
        }
    }

    ubyte[] toBytes() @safe pure nothrow const {
        final switch(type) {

        case CommandType.shell:
            return [cast(ubyte)type] ~ cast(ubyte[])command.dup;

        case CommandType.compile:
        case CommandType.compileAndLink:
        case CommandType.link:
        case CommandType.phony:
            ubyte[] bytes;
            bytes ~= cast(ubyte)type;
            bytes ~= cast(ubyte)(params.keys.length >> 8);
            bytes ~= (params.keys.length & 0xff);
            foreach(key; params.keys) {
                bytes ~= arrayToBytes(key);
                bytes ~= cast(ubyte)(params[key].length >> 8);
                bytes ~= (params[key].length & 0xff);
                foreach(value; params[key])
                    bytes ~= arrayToBytes(value);
            }
            return bytes;

        case CommandType.code:
            assert(0);
        }
    }

    static Command fromBytes(ubyte[] bytes) @trusted pure {
        immutable type = cast(CommandType)bytes[0];
        bytes = bytes[1..$];

        final switch(type) {

        case CommandType.shell:
            char[] chars;
            foreach(b; bytes) chars ~= cast(char)b;
            return Command(cast(string)chars);

        case CommandType.compile:
        case CommandType.compileAndLink:
        case CommandType.link:
        case CommandType.phony:
            Params params;

            immutable numKeys = getUshort(bytes);
            foreach(i; 0..numKeys) {
                immutable key = cast(string)bytesToArray!char(bytes);
                immutable numValues = getUshort(bytes);

                string[] values;
                foreach(j; 0..numValues) {
                    values ~= bytesToArray!(immutable char)(bytes);
                }
                params[key] = values;
            }
            return Command(type, params);

        case CommandType.code:
            throw new Exception("Cannot serialise Command of type code");
        }
    }

    string toString() const pure @safe {
        final switch(type) with(CommandType) {
            case shell:
            case phony:
                return `Command("` ~ command ~ `")`;
            case compile:
            case link:
            case compileAndLink:
            case code:
                return `Command(` ~ type.to!string ~
                    (params.keys.length ? ", " ~ text(params) : "") ~
                    `)`;
        }
    }
}


private ubyte[] arrayToBytes(T)(in T[] arr) {
    auto bytes = new ubyte[arr.length + 2];
    immutable length = cast(ushort)arr.length;
    bytes[0] = length >> 8;
    bytes[1] = length & 0xff;
    foreach(i, c; arr) bytes[i + 2] = cast(ubyte)c;
    return bytes;
}


private T[] bytesToArray(T)(ref ubyte[] bytes) {
    import std.traits: Unqual;
    Unqual!T[] arr;
    arr.length = getUshort(bytes);
    foreach(i, b; bytes[0 .. arr.length]) arr[i] = cast(T) b;
    bytes = bytes[arr.length .. $];
    return arr;
}


private ushort getUshort(ref ubyte[] bytes) @safe pure nothrow {
    immutable length = (bytes[0] << 8) + bytes[1];
    bytes = bytes[2..$];
    return length;
}

private ubyte[] setUshort(in ushort length) @safe pure nothrow {
    auto bytes = new ubyte[2];
    bytes[0] = length >> 8;
    bytes[1] = length & 0xff;
    return bytes;
}


string replaceConcreteCompilersWithVars(in string cmd, in Options options) @safe pure nothrow {
    return cmd.
        replace(options.dCompiler, "$(DC)").
        replace(options.cppCompiler, "$(CXX)").
        replace(options.cCompiler, "$(CC)");
}
