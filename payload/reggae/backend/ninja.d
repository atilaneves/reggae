module reggae.backend.ninja;


import reggae.build: CommandType;
import reggae.rules.common: Language;
import reggae.options: Options;


struct Ninja {

    import reggae.build: Build, Target;

    NinjaEntry[] buildEntries;
    NinjaEntry[] ruleEntries;

    version(unittest) {
        this(Build build, in string projectPath = "") @safe {
            import reggae.config: options;
            auto modOptions = options.dup;
            modOptions.projectPath = projectPath;
            this(build, modOptions);
        }
    }

    this(Build build, in Options options) @safe {
        _build = build;
        _options = options.dup;
        _projectPath = _options.projectPath;

        foreach(target; _build.range) {
            target.hasDefaultCommand
                ? defaultRule(target)
                : target.getCommandType == CommandType.phony
                ? phonyRule(target)
                : customRule(target);
        }
    }

    //includes rerunning reggae
    const(NinjaEntry)[] allBuildEntries() @safe {
        import std.array: array, replace;
        import std.algorithm: sort, uniq, map;
        import std.range: chain, only;

        const(NinjaEntry)[] rerunEntries() {
            // if exporting the build system, don't include rerunning reggae
            if(_options.export_)
                return [];

            auto srcDirs = _srcDirs.sort.uniq;
            const flattenedInputs = flattenEntriesInBuildLine(
                chain(_options.reggaeFileDependencies, srcDirs).array
            );
            auto paramLines = _options.oldNinja ? [] : ["pool = console"];

            auto rerun = NinjaEntry("build build.ninja: _rerun | " ~ flattenedInputs, paramLines);
            // the reason this is needed is because inputs (files and
            // source directories) can be deleted or renamed. If they are,
            // ninja will complain about the missing files/directories
            // since they are a dependency of the build.ninja file for
            // rerunning reggae.  So use a dummy phony target 'outputting'
            // all build.ninja inputs, so that ninja will happily rerun
            // reggae, which will generate a new build.ninja with an
            // updated list of build.ninja inputs.
            auto phonyInputs = NinjaEntry("build " ~ flattenedInputs ~ ": phony");
            return [rerun, phonyInputs];
        }

        const defaultOutputs = _build.defaultTargetsOutputs(_projectPath);
        const defaultEntry = NinjaEntry("default " ~ flattenEntriesInBuildLine(defaultOutputs));

        return buildEntries ~ rerunEntries ~ defaultEntry;
    }

    //includes rerunning reggae
    const(NinjaEntry)[] allRuleEntries() @safe pure const {
        import std.array: join;

        return ruleEntries ~ defaultRules(_options) ~
            NinjaEntry("rule _rerun",
                       ["command = " ~ _options.rerunArgs.join(" "),
                        "generator = 1",
                           ]);
    }

    string buildOutput() @safe {
        auto ret = "include rules.ninja\n" ~ output(allBuildEntries);
        if(_options.export_) ret = _options.eraseProjectPath(ret);
        return ret;
    }

    string rulesOutput() @safe pure const {
        return output(allRuleEntries);
    }

    void writeBuild() @safe {
        import std.stdio: File;
        import reggae.path: buildPath;

        auto buildNinja = File(buildPath(_options.workingDir, "build.ninja"), "w");
        buildNinja.writeln(buildOutput);

        auto rulesNinja = File(buildPath(_options.workingDir, "rules.ninja"), "w");
        rulesNinja.writeln(rulesOutput);
    }

private:
    Build _build;
    string _projectPath;
    const(Options) _options;
    int _counter = 1;
    // we keep a list of directories with sources here to add them as
    // dependencies for a reggae rerun
    string[] _srcDirs;

    void defaultRule(Target target) @safe {
        import reggae.backend: maybeAddDirDependencies;
        import std.algorithm: canFind, map, startsWith;
        import std.array: join, replace;
        import std.path: extension;

        static string flattenShellArgs(in string[] args) {
            static string quoteArgIfNeeded(string a) {
                return !a.canFind(' ') ? a : `"` ~ a.replace(`"`, `\"`) ~ `"`;
            }
            return args.map!quoteArgIfNeeded.join(" ");
        }

        string[] paramLines;
        foreach(immutable param; target.commandParamNames) {
            // skip the DEPFILE parameter, it's already specified in the rule
            if (param == "DEPFILE") continue;
            const values = target.getCommandParams(_projectPath, param, []);
            const flat = flattenShellArgs(values);
            if(!flat.length) continue;
            // the flat value still needs to be escaped for Ninja ($ => $$, e.g. for env vars)
            paramLines ~= param ~ " = " ~ flat.replace("$", "$$");
        }

        const ruleName = cmdTypeToNinjaRuleName(target.getCommandType, target.getLanguage);
        // includeImplicitInputs used to be set to `false` here, and I don't know why.
        // No tests fail if set to true, and one test in particular
        // (tests.it.runtime.dependencies.ninja) *requires* it to pass.
        const buildLine = buildLine(target, ruleName, /*includeImplicitInputs=*/true);

        buildEntries ~= NinjaEntry(buildLine, paramLines);
        _srcDirs ~= maybeAddDirDependencies(target, _projectPath);
    }

    void phonyRule(Target target) @safe {
        const cmd = target.shellCommand(_options);

        //no projectPath for phony rules since they don't generate output
        const outputs = target.expandOutputs("");
        const inputs = targetDependencies(target);
        const implicitInputs = target.implicitTargets.length
            ? target.implicitsInProjectPath(_projectPath)
            : null;
        const buildLine = buildLine(outputs, cmd is null ? "phony" : "_phony", inputs, implicitInputs);

        buildEntries ~= NinjaEntry(buildLine, cmd is null
                                              ? ["pool = console"]
                                              : ["cmd = " ~ cmd, "pool = console"]);
    }

    // a random shell command the user wrote themselves
    void customRule(Target target) @safe {

        import std.string: indexOf;
        import std.conv: text;

        // rawCmdString is used because ninja needs to find where $in and $out are,
        // so shellCommand wouldn't work
        const shellCommand = target.rawCmdString(_projectPath);
        const i_in = shellCommand.indexOf("$in");
        const i_out = shellCommand.indexOf("$out");

        if(i_in < 0 && i_out < 0)
            throw new Exception(
                text("Cannot have a custom rule with no $in or $out: use `phony` or explicit $in/$out instead."
                )
            );

        string ruleName;
        string[] paramLines;
        void addParamLine(string name, ptrdiff_t startIndex, ptrdiff_t endIndex) {
            assert(startIndex >= 0);
            if (endIndex < 0) endIndex = shellCommand.length;

            if (startIndex < endIndex) {
                const value = shellCommand[startIndex .. endIndex];
                // if the value starts with a space, it needs to be escaped as `$ ` (for ninja's lexer)
                paramLines ~= name ~ " = " ~ (value[0] == ' ' ? "$" : "") ~ value;
            }
        }

        if (i_out < 0) {
            ruleName = "_custom_in";
            addParamLine("before", 0, i_in);
            addParamLine("after", i_in + 3, -1);
        } else if (i_in < 0) {
            ruleName = "_custom_out";
            addParamLine("before", 0, i_out);
            addParamLine("after", i_out + 4, -1);
        } else if (i_in < i_out) {
            ruleName = "_custom_in_out";
            addParamLine("before", 0, i_in);
            addParamLine("between", i_in + 3, i_out);
            addParamLine("after", i_out + 4, -1);
        } else {
            ruleName = "_custom_out_in";
            addParamLine("before", 0, i_out);
            addParamLine("between", i_out + 4, i_in);
            addParamLine("after", i_in + 3, -1);
        }

        const includeImplicitInputs = (i_out >= 0);
        // TODO: weird inputsOverride for implicitInput case?!
        const buildLine = buildLine(target, ruleName, includeImplicitInputs);

        buildEntries ~= NinjaEntry(buildLine, paramLines);
    }

    string output(const(NinjaEntry)[] entries) @safe pure const nothrow {
        import reggae.options: banner;
        import std.algorithm.iteration: map;
        import std.array: join;
        return banner ~ entries.map!(a => a.toString).join("\n\n");
    }

    string buildLine(Target target, in string rule, in bool includeImplicitInputs,
                     in string[] inputsOverride = null) @safe pure const {

        const outputs = target.expandOutputs(_projectPath);
        const inputs = inputsOverride !is null ? inputsOverride : targetDependencies(target);
        const implicitInputs = includeImplicitInputs && target.implicitTargets.length
            ? target.implicitsInProjectPath(_projectPath)
            : null;

        return buildLine(outputs, rule, inputs, implicitInputs);
    }

    // Creates a Ninja build statement line:
    // `build <outputs>: <rule> <inputs> | <implicitInputs>`
    static string buildLine(in string[] outputs, in string rule, in string[] inputs,
                     in string[] implicitInputs) @safe pure {
        auto ret = "build " ~ flattenEntriesInBuildLine(outputs) ~ ": " ~ rule ~ " " ~ flattenEntriesInBuildLine(inputs);
        if (implicitInputs.length)
            ret ~= " | " ~ flattenEntriesInBuildLine(implicitInputs);
        return ret;
    }

    // Inputs and outputs in build lines need extra escaping of some chars
    // like colon and space.
    static string flattenEntriesInBuildLine(in string[] entries) @safe pure {
        import std.algorithm: map;
        import std.array: join, replace;
        return entries
            .map!escapePathInBuildLine
            .join(" ");
    }

    //@trusted because of splitter
    private string targetCommand(Target target) @trusted pure const {
        return targetRawCommand(target).sanitizeCmd;
    }

    //@trusted because of splitter
    private string targetRawCommand(Target target) @trusted pure const {
        import std.algorithm: splitter;
        import std.array: front;

        auto cmd = target.shellCommand(_options);
        if(cmd == "") return "";
        return cmd.splitter(" ").front;
    }

    private string[] targetDependencies(in Target target) @safe pure const {
        return target.dependenciesInProjectPath(_projectPath);
    }

    private string dirSentinelFileName(in Target target) @safe pure const {
        return target.expandOutputs(_projectPath)[0] ~ ".files.txt";
    }
}

private string escapePathInBuildLine(string path) @safe pure {
    import std.array: replace;
    return path.replace(":", "$:").replace(" ", "$ ");
}

struct NinjaEntry {
    string mainLine;
    string[] paramLines;
    string toString() @safe pure nothrow const {

        import std.array: join;
        import std.range: chain, only;
        import std.algorithm.iteration: map;

        return chain(only(mainLine), paramLines.map!(a => "  " ~ a)).join("\n");
    }
}


private bool hasDepFile(in CommandType type) @safe pure nothrow {
    return type == CommandType.compile || type == CommandType.compileAndLink;
}

/**
 * Pre-built rules
 */
NinjaEntry[] defaultRules(in Options options) @safe pure {

    import reggae.build: Command;

    NinjaEntry createNinjaEntry(in CommandType type, in Language language) @safe pure {

        const command = Command.builtinTemplate(type, language, options);

        string[] paramLines = initializeRuleParamLines(language, command);

        if(hasDepFile(type)) {
            version(Windows)
                const isMSVC = language == Language.C || language == Language.Cplusplus;
            else
                enum isMSVC = false;

            if (isMSVC) {
                paramLines ~= "deps = msvc";
            } else {
                // Disable the ninja deps database (.ninja_deps file) with --dub-objs-dir
                // to enable sharing the build artifacts (incl. .dep files) across reggae
                // builds with identical --dub-objs-dir.
                // Ninja otherwise complains about local .ninja_deps being out of date when
                // the shared build output is more recent, and rebuilds.
                if (options.dubObjsDir.length == 0)
                    paramLines ~= "deps = gcc";

                paramLines ~= "depfile = $out.dep";
            }
        }

        string getDescription() {
            switch(type) with(CommandType) {
                case compile:        return "Compiling $out";
                case link:           return "Linking $out";
                case compileAndLink: return "Building $out";
                default:             return null;
            }
        }

        const description = getDescription();
        if (description.length)
            paramLines ~= "description = " ~ description;

        return NinjaEntry("rule " ~ cmdTypeToNinjaRuleName(type, language), paramLines);
    }

    NinjaEntry[] entries;
    foreach(type; [CommandType.compile, CommandType.link, CommandType.compileAndLink]) {
        for(Language language = Language.min; language <= Language.max; ++language) {
            if(hasDepFile(type) && language == Language.unknown) continue;
            entries ~= createNinjaEntry(type, language);
        }
    }

    version(Windows)
        enum phonyParamLines = [`command = cmd.exe /c "$cmd"`, "description = $cmd"];
    else
        enum phonyParamLines = ["command = $cmd"];

    entries ~= NinjaEntry("rule _phony", phonyParamLines);

    entries ~= NinjaEntry("rule _custom_in", ["command = ${before}${in}${after}"]);
    entries ~= NinjaEntry("rule _custom_out", ["command = ${before}${out}${after}"]);
    entries ~= NinjaEntry("rule _custom_in_out", ["command = ${before}${in}${between}${out}${after}"]);
    entries ~= NinjaEntry("rule _custom_out_in", ["command = ${before}${out}${between}${in}${after}"]);

    return entries;
}

private string[] initializeRuleParamLines(in Language language, in string[] command) @safe pure {
    import std.string : join;

    version(Windows) {
        import std.algorithm: among;

        // On Windows, the max command line length is ~32K.
        // Make ninja use a response file for all D/C[++] rules.
        if (language.among(Language.D, Language.C, Language.Cplusplus) && command.length > 1) {
            const program = command[0];
            const args = command[1 .. $];
            return [
                "command = " ~ program ~ " @$out.rsp",
                "rspfile = $out.rsp",
                "rspfile_content = " ~ args.join(" "),
            ];
        }
    }

    return ["command = " ~ command.join(" ")];
}

private string cmdTypeToNinjaRuleName(CommandType commandType, Language language) @safe pure {
    final switch(commandType) with(CommandType) {
        case shell: assert(0, "cmdTypeToNinjaRuleName doesn't work for shell");
        case phony: assert(0, "cmdTypeToNinjaRuleName doesn't work for phony");
        case code: throw new Exception("Command type 'code' not supported for ninja backend");
        case link:
            final switch(language) with(Language) {
                case D: return "_dlink";
                case Cplusplus: return "_cpplink";
                case C: return "_clink";
                case unknown: return "_ulink";
            }
        case compile:
            final switch(language) with(Language) {
                case D: return "_dcompile";
                case Cplusplus: return "_cppcompile";
                case C: return "_ccompile";
                case unknown: throw new Exception("Unsupported language");
            }
        case compileAndLink:
            final switch(language) with(Language) {
                case D: return "_dcompileAndLink";
                case Cplusplus: return "_cppcompileAndLink";
                case C: return "_ccompileAndLink";
                case unknown: throw new Exception("Unsupported language");
            }
    }
}


//ninja doesn't like symbols in rule names
//@trusted because of replace
private string sanitizeCmd(string cmd) @trusted pure nothrow {
    import std.path: baseName;
    import std.array: replace;
    //only handles c++ compilers so far...
    return cmd.baseName.replace("+", "p");
}
