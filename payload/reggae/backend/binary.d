module reggae.backend.binary;


import reggae.build;
import reggae.range;
import reggae.options;
import reggae.file;
import reggae.dependencies;
import std.algorithm;
import std.range;
import std.file: thisExePath, exists;
import std.process: execute, executeShell;
import std.path: absolutePath;
import std.typecons: tuple;
import std.exception;
import std.stdio;
import std.parallelism: parallel;
import std.conv;
import std.array: replace, empty;
import std.string: strip;
import std.getopt;

@safe:

struct BinaryOptions {
    bool list;
    private bool _earlyReturn;
    string[] args;

    this(string[] args) @trusted {
        auto optInfo = getopt(
            args,
            "list|l", "List available build targets", &list,
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

    bool earlyReturn() const pure nothrow {
        return _earlyReturn;
    }
}

struct Binary {
    Build build;
    const(Options) options;
    File output;

    this(Build build, in Options options) @trusted {
        this(build, options, stdout);
        this.build = build;
    }

    this(Build build, in Options options, File output) @trusted {
        this.build = build;
        this.options = options;
        this.output = output;
    }


    void run(string[] args) @system { //@system due to parallel
        auto binaryOptions = BinaryOptions(args);

        handleOptions(binaryOptions);
        if(binaryOptions.earlyReturn) return;

        bool didAnything = checkReRun();

        auto topTargets = topLevelTargets(binaryOptions.args);
        if(topTargets.empty)
            throw new Exception(text("Unknown target(s) ", binaryOptions.args.map!(a => "'" ~ a ~ "'").join(" ")));

        foreach(topTarget; topTargets) {

            immutable didPhony = checkChildlessPhony(topTarget);
            didAnything = didPhony || didAnything;
            if(didPhony) continue;

            foreach(level; ByDepthLevel(topTarget)) {
                foreach(target; level.parallel) {
                    const outs = target.outputsInProjectPath(options.projectPath);
                    immutable depFileName = outs[0] ~ ".dep";
                    if(depFileName.exists) {
                        didAnything = checkDeps(target, depFileName) || didAnything;
                    }

                    didAnything = checkTimestamps(target) || didAnything;
                }
            }
        }
        if(!didAnything) output.writeln("[build] Nothing to do");
    }

    Target[] topLevelTargets(string[] args) @trusted pure {
        return args.empty ?
            build.defaultTargets.array :
            build.targets.filter!(a => args.canFind(a.expandOutputs(options.projectPath))).array;
    }

    string[] listTargets(BinaryOptions binaryOptions) pure {
        string[] result;

        const defaultTargets = topLevelTargets(binaryOptions.args);
        foreach(topTarget; defaultTargets)
            result ~= "- " ~ topTarget.expandOutputs(options.projectPath).join(" ");

        auto optionalTargets = build.targets.filter!(a => !defaultTargets.canFind(a));
        foreach(optionalTarget; optionalTargets)
            result ~= "- " ~ optionalTarget.rawOutputs.join(" ") ~
                " (optional)";

        return result;
    }


private:

    void handleOptions(BinaryOptions binaryOptions) {
        if(binaryOptions.list) {
            output.writeln("List of available top-level targets:");
            foreach(l; listTargets(binaryOptions)) output.writeln(l);
        }
    }

    bool checkReRun() {
        // don't bother if the build system was exported
        if(options.export_) return false;

        immutable myPath = thisExePath;
        if((options.reggaeFileDependencies ~ getReggaeFileDependencies).any!(a => a.newerThan(myPath))) {
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

    bool checkTimestamps(Target target) {
        foreach(dep; chain(target.dependencies, target.implicits)) {

            immutable isPhony = target.getCommandType == CommandType.phony;

            if(isPhony || anyNewer(options.projectPath,
                                   dep.outputsInProjectPath(options.projectPath),
                                   target)) {
                executeCommand(target);
                return true;
            }
        }

        return false;
    }

    //always run phony rules with no dependencies at top-level
    //ByDepthLevel won't include them
    bool checkChildlessPhony(Target target) {
        if(target.getCommandType == CommandType.phony &&
           target.dependencies.empty && target.implicits.empty) {
            executeCommand(target);
            return true;
        }
        return false;
    }

    //Checks dependencies listed in the .dep file created by the compiler
    bool checkDeps(Target target, in string depFileName) @trusted {
        auto file = File(depFileName);
        auto dependencies = file.byLine.map!(a => a.to!string).dependenciesFromFile;

        if(anyNewer(options.projectPath, dependencies, target)) {
            executeCommand(target);
            return true;
        }

        return false;
    }

    void executeCommand(Target target) @trusted {
        mkDir(target);
        auto targetOutput = target.execute(options);
        output.writeln("[build] ", targetOutput[0]);
        if(target.getCommandType == CommandType.phony)
            output.writeln("\n", targetOutput[1]);
    }

    //@trusted because of mkdirRecurse
    private void mkDir(Target target) @trusted const {
        foreach(output; target.outputsInProjectPath(options.projectPath)) {
            import std.file: exists, mkdirRecurse;
            import std.path: dirName;
            if(!output.dirName.exists) mkdirRecurse(output.dirName);
        }
    }
}



bool anyNewer(in string projectPath, in string[] dependencies, in Target target) @safe {
    return cartesianProduct(dependencies, target.outputsInProjectPath(projectPath)).
        any!(a => a[0].newerThan(a[1]));
}
