module reggae.backend.binary;


import reggae.build;
import reggae.range;
import reggae.options;
import reggae.file;
import std.algorithm;
import std.range;
import std.file: thisExePath, exists;
import std.process: execute, executeShell;
import std.typecons: tuple;
import std.exception;
import std.stdio;
import std.parallelism: parallel;
import std.conv;
import std.array: replace, empty;
import std.string: strip;
import std.getopt;
import std.range.primitives: isInputRange;


private struct BinaryOptions {
    bool list;
    bool norerun;
    bool singleThreaded;
    private bool _earlyReturn;
    string[] args;

    this(string[] args) @trusted {
        auto optInfo = getopt(
            args,
            "list|l", "List available build targets", &list,
            "norerun|n", "Don't check for rerun", &norerun,
            "single|s", "Use only one thread", &singleThreaded,
            );
        if(optInfo.helpWanted) {
            defaultGetoptPrinter("Usage: build <targets>", optInfo.options);
            _earlyReturn = true;
        }
        if(list) {
            _earlyReturn = true;
        }

        this.args = args[1..$];
    }

    bool earlyReturn() @safe const pure nothrow {
        return _earlyReturn;
    }
}

auto Binary(Build build, in Options options) @system {
    version(unittest) {
        import tests.utils: FakeFile;
        auto file = new FakeFile;
        return Binary(build, options, *file);
    }
    else {
        import std.stdio: stdout;
        return Binary(build, options, stdout);
    }
}

auto Binary(T)(Build build, in Options options, ref T output) {
    return BinaryT!(T)(build, options, output);
}


struct BinaryT(T) {
    Build build;
    const(Options) options;
    T* output;
    private string[] _srcDirs;

    this(Build build, in Options options, ref T output) @trusted {
        version(unittest) {
            static if(is(T == File)) {
                assert(&output != &stdout,
                       "stdio not allowed for Binary output in testing, " ~
                       "use tests.utils.FakeFile instead");
            }
        }

        this.build = build;
        this.options = options;
        this.output = &output;
    }

    void run(string[] args) @system { //@system due to parallel

        version(unittest) {
            scope(exit) {
                import unit_threaded;
                writelnUt(*output);
            }
        }

        auto binaryOptions = BinaryOptions(args);

        handleOptions(binaryOptions);
        if(binaryOptions.earlyReturn) return;

        auto topTargets = topLevelTargets(binaryOptions.args);
        if(topTargets.empty)
            throw new Exception(text("Unknown target(s) ", binaryOptions.args.map!(a => "'" ~ a ~ "'").join(" ")));

        bool didAnything = binaryOptions.norerun ? false : checkReRun(topTargets);

        if(binaryOptions.singleThreaded)
            didAnything = mainLoop(topTargets, binaryOptions, didAnything);
        else
            didAnything = mainLoop(topTargets.parallel, binaryOptions, didAnything);

        if(!didAnything) output.writeln("[build] Nothing to do");
    }

    Target[] topLevelTargets(string[] args) @trusted pure {
        return args.empty ?
            build.defaultTargets.array :
            build.targets.filter!(a => args.canFind(a.expandOutputs(options.projectPath))).array;
    }

    string[] listTargets(BinaryOptions binaryOptions) @safe pure {

        string targetOutputsString(in Target target) {
            return "- " ~ target.expandOutputs(options.projectPath).join(" ");
        }

        const defaultTargets = topLevelTargets(binaryOptions.args);
        auto optionalTargets = build.targets.filter!(a => !defaultTargets.canFind(a));
        auto rng = chain(
            defaultTargets.map!targetOutputsString,
            optionalTargets.map!targetOutputsString.map!(a => a ~ " (optional)"));
        return () @trusted { return rng.array; }();
    }


private:

    bool mainLoop(R)(R topTargets_, in BinaryOptions binaryOptions, bool didAnything) @system {
        foreach(topTarget; topTargets_) {

            immutable didPhony = checkChildlessPhony(topTarget);
            didAnything = didPhony || didAnything;
            if(didPhony) continue;

            foreach(level; ByDepthLevel(topTarget)) {
                if(binaryOptions.singleThreaded)
                    foreach(target; level)
                        handleTarget(target, didAnything);
                else
                    foreach(target; level.parallel)
                        handleTarget(target, didAnything);
            }
        }
        return didAnything;
    }

    void handleTarget(Target target, ref bool didAnything) @safe {
        const outs = target.expandOutputs(options.projectPath);
        immutable depFileName = outs[0] ~ ".dep";

        if(depFileName.exists) {
            didAnything = checkDeps(target, depFileName) || didAnything;
        }

        didAnything = checkTimestamps(target) || didAnything;
    }

    void handleOptions(BinaryOptions binaryOptions) @safe {
        if(binaryOptions.list) {
            output.writeln("List of available top-level targets:");
            foreach(l; listTargets(binaryOptions)) output.writeln(l);
        }
    }

    bool checkReRun(Target[] topTargets) @safe {
        import reggae.backend: maybeAddDirDependencies;
        import reggae.range: ByDepthLevel;
        import std.range: chain;
        import std.algorithm: map, joiner, uniq;
        import std.array: array;

        // don't bother if the build system was exported
        if(options.export_) return false;

        auto srcDirs = topTargets
            .map!ByDepthLevel
            .map!(l => l.map!(ts => ts.map!(t => maybeAddDirDependencies(t, options.projectPath)).joiner).joiner)
            .joiner
            .array
            .sort
            .uniq;

        auto deps = chain(options.reggaeFileDependencies, srcDirs);

        immutable myPath = thisExePath;
        if(deps.any!(a => a.newerThan(myPath))) {
            output.writeln("[build] " ~ options.rerunArgs.join(" "));
            immutable reggaeRes = execute(options.rerunArgs);
            enforce(reggaeRes.status == 0,
                    text("Could not run ", options.rerunArgs.join(" "), " to regenerate build:\n",
                         reggaeRes.output));
            output.writeln(reggaeRes.output);

            //currently not needed because generating the build also runs it.
            immutable buildRes = execute([myPath]);
            enforce(buildRes.status == 0, "Could not redo the build:\n", buildRes.output);
            output.writeln(buildRes.output);
            return true;
        }

        return false;
    }

    bool checkTimestamps(Target target) @safe {
        auto allDeps = chain(target.dependencyTargets, target.implicitTargets);
        immutable isPhonyLike = target.getCommandType == CommandType.phony ||
            allDeps.empty;

        if(isPhonyLike) {
            executeCommand(target);
            return true;
        }

        foreach(dep; allDeps) {
            if(anyNewer(options.projectPath,
                        dep.expandOutputs(options.projectPath),
                        target)) {
                executeCommand(target);
                return true;
            }
        }

        return false;
    }

    //always run phony rules with no dependencies at top-level
    //ByDepthLevel won't include them
    bool checkChildlessPhony(Target target) @safe {
        if(target.getCommandType == CommandType.phony &&
           target.dependencyTargets.empty && target.implicitTargets.empty) {
            executeCommand(target);
            return true;
        }
        return false;
    }

    //Checks dependencies listed in the .dep file created by the compiler
    bool checkDeps(Target target, in string depFileName) @trusted {
        import std.array: array;

        // byLine splits at `\n`, so open Windows text files with CRLF line terminators in non-binary mode
        auto lines = File(depFileName, "r")
            .byLine
            .map!(a => a.to!string)
            .array
            ;
        auto dependencies = dependenciesFromFile(lines);

        if(anyNewer(options.projectPath, dependencies, target)) {
            executeCommand(target);
            return true;
        }

        return false;
    }

    void executeCommand(Target target) @trusted {
        output.writeln("[build] ", target.shellCommand(options));

        mkDir(target);
        auto targetOutput = target.execute(options);

        if(target.getCommandType == CommandType.phony && targetOutput.length > 0)
            output.writeln("\n", targetOutput[0]);
    }

    //@trusted because of mkdirRecurse
    private void mkDir(Target target) @trusted const {
        import std.file: exists, mkdirRecurse;
        import std.path: dirName;

        foreach(output; target.expandOutputs(options.projectPath)) {
            if(!output.dirName.exists)
                mkdirRecurse(output.dirName);
        }
    }
}


bool anyNewer(in string projectPath, in string[] dependencies, in Target target) @safe {
    return cartesianProduct(dependencies, target.expandOutputs(projectPath)).
        any!(a => a[0].newerThan(a[1]));
}

string[] dependenciesFromFile(R)(R lines) if(isInputRange!R) {
    import std.algorithm: map, filter, find, endsWith;
    import std.array: empty, join, array, split;

    if(lines.empty) return [];

    static removeBackslash(in string str) {
        return str.endsWith(` \`)
            ? str[0 .. $-2]
            : str;
    }

    return lines
        .map!removeBackslash
        .join(" ")
        .find(":")
        .split(" ")
        .filter!(a => a != "")
        .array[1..$];
}
