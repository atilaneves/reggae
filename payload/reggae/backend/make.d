module reggae.backend.make;


struct Makefile {

    import reggae.build: Build, Target;
    import reggae.options: Options;

    Build build;
    const(Options) options;
    string projectPath;
    private string[] _srcDirs;

    this(Build build, in Options options) @safe pure {
        this.build = build;
        this.options = options;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    //only the main targets
    string simpleOutput() @safe {

        import reggae.options: banner;
        import reggae.build: CommandType;
        import std.conv: text;
        import std.array: join;

        auto ret = banner;
        ret ~= text("all: ", build.defaultTargetsOutputs(options.projectPath).join(" "), "\n");
        ret ~= ".SUFFIXES:\n"; //disable default rules
        ret ~= options.compilerVariables.join("\n") ~ "\n";

        ret ~= "$(VERBOSE).SILENT:\n"; // Do not display executed commands

        foreach(target; build.range) {

            mkDir(target);

            immutable output = target.expandOutputs(options.projectPath).join(" ");
            if(target.getCommandType == CommandType.phony) {
                ret ~= ".PHONY: " ~ output ~ "\n";
            }
            ret ~= output ~  ": ";
            ret ~= (target.dependenciesInProjectPath(options.projectPath) ~
                    target.implicitsInProjectPath(options.projectPath)).join(" ");

            ret ~= " " ~ fileName() ~ "\n";
            ret ~= "\t@echo [make] Building " ~ output ~ "\n";
            ret ~= "\t" ~ command(target) ~ "\n";
        }

        return ret;
    }

    private static string replaceEnvVars(in string str) @safe {
        import std.regex: regex, matchAll;
        import std.algorithm: _sort = sort, uniq, map;
        import std.array: array, replace;
        import std.process: environment;

        auto re = regex(`\$(\w+)`);
        auto envVars = str.matchAll(re).map!(a => a.hit).array._sort.uniq;
        string ret = str;

        foreach(var; envVars) {
            ret = ret.replace(var, environment.get(var[1..$], ""));
        }

        return ret;
    }

    //includes rerunning reggae
    string output() @safe {

        import std.array: join, replace;
        import std.range: chain;
        import std.algorithm: sort, uniq, map;

        auto ret = simpleOutput;

        if(options.export_) {
            ret = options.eraseProjectPath(ret);
        } else {
            // add a dependency on the Makefile to reggae itself and the build description,
            // but only if not exporting a build
            auto srcDirs = _srcDirs.sort.uniq;
            const rerunLine = "\t" ~ options.rerunArgs.join(" ") ~ "\n";

            ret ~= fileName() ~ ": " ~ chain(options.reggaeFileDependencies, srcDirs.save).join(" ") ~ "\n";
            ret ~= rerunLine;
            ret ~= "\n" ~ srcDirs.save.map!(d => d ~ ":" ~ "\n" ~ rerunLine).join("\n");
        }

        return replaceEnvVars(ret);
    }

    void writeBuild() @safe {
        import std.stdio: File;
        import reggae.path: buildPath;

        auto output = output();
        auto file = File(buildPath(options.workingDir, fileName), "w");
        file.write(output);
    }

    //the only reason this is needed is to add auto dependency
    //tracking
    string command(Target target) @safe {
        import reggae.build: CommandType, replaceConcreteCompilersWithVars;
        import reggae.backend: maybeAddDirDependencies;

        immutable cmdType = target.getCommandType;
        if(cmdType == CommandType.code)
            throw new Exception("Command type 'code' not supported for make backend");

        _srcDirs ~= maybeAddDirDependencies(target, projectPath);

        immutable cmd = target.shellCommand(options).replaceConcreteCompilersWithVars(options);
        immutable depfile = target.expandOutputs(options.projectPath)[0] ~ ".dep";

        if(target.hasDefaultCommand) {
            return cmdType == CommandType.link ? cmd : cmd ~ makeAutoDeps(depfile);
        } else {
            return cmd;
        }
    }

    private void mkDir(Target target) @trusted const {
        import std.path: dirName;
        import std.file: exists, mkdirRecurse;

        foreach(output; target.expandOutputs(options.projectPath)) {
            import std.file;
            if(!output.dirName.exists) mkdirRecurse(output.dirName);
        }
    }
}


//For explanation of the crazy Makefile commands, see:
//http://stackoverflow.com/questions/8025766/makefile-auto-dependency-generation
//http://make.mad-scientist.net/papers/advanced-auto-dependency-generation/
private string makeAutoDeps(in string depfile) @safe pure nothrow {
    immutable pFile = depfile ~ ".P";
    return "\n\t@cp " ~ depfile ~ " " ~ pFile ~ "; \\\n" ~
        "    sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \\\n" ~
        "        -e '/^$$/ d' -e 's/$$/ :/' < " ~ depfile ~ " >> " ~ pFile ~"; \\\n" ~
        "    rm -f " ~ depfile ~ "\n\n" ~
        "-include " ~ pFile ~ "\n\n";
}
