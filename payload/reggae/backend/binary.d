module reggae.backend.binary;


import reggae.build;
import reggae.range;
import reggae.config;
import std.algorithm;
import std.range;
import std.file: timeLastModified, thisExePath, exists;
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

        this.args = args;
    }

    bool earlyReturn() const pure nothrow {
        return _earlyReturn;
    }
}

struct Binary {
    Build build;
    string projectPath;

    this(Build build, string projectPath) pure {
        this.build = build;
        this.projectPath = projectPath;
    }

    void run(string[] args) const @system { //@system due to parallel
        auto options = BinaryOptions(args);
        handleOptions(options);
        if(options.earlyReturn) return;

        bool didAnything = checkReRun();

        foreach(topTarget; topLevelTargets(options.args)) {

            immutable didPhony = checkPhony(topTarget);
            didAnything = didPhony || didAnything;
            if(didPhony) continue;

            foreach(level; ByDepthLevel(topTarget)) {
                foreach(target; level.parallel) {

                    const outs = target.outputsInProjectPath(projectPath);
                    immutable depFileName = outs[0] ~ ".dep";
                    if(depFileName.exists) {
                        didAnything = checkDeps(target, depFileName) || didAnything;
                    }

                    didAnything = checkTimestamps(target) || didAnything;
                }
            }
        }
        if(!didAnything) writeln("[build] Nothing to do");
    }

    const(Target)[] topLevelTargets(string[] args) @trusted const pure nothrow {
        args = args[1..$];
        return args.empty ?
            build.defaultTargets :
            build.targets.filter!(a => args.canFind(a.outputs[0])).array;
    }


private:

    void handleOptions(BinaryOptions options) const {
        if(options.list) {
            writeln("List of available top-level targets:");
            const defaultTargets = topLevelTargets(options.args);
            foreach(topTarget; defaultTargets)
                writeln("- " ~ topTarget.outputsInProjectPath(projectPath).join(" "));

            auto optionalTargets = build.targets.filter!(a => !defaultTargets.canFind(a));
            foreach(optionalTarget; optionalTargets)
                writeln("- " ~ optionalTarget.outputs.join(" ") ~ " (optional)");
        }
    }

    bool checkReRun() const {
        immutable myPath = thisExePath;
        if(reggaePath.newerThan(myPath) || buildFilePath.newerThan(myPath)) {
            writeln("[build] " ~ reggaeCmd.join(" "));
            immutable reggaeRes = execute(reggaeCmd);
            enforce(reggaeRes.status == 0,
                    text("Could not run ", reggaeCmd.join(" "), " to regenerate build:\n",
                         reggaeRes.output));
            writeln(reggaeRes.output);

            //currently not needed because generating the build also runs it.
            immutable buildRes = execute([myPath]);
            enforce(buildRes.status == 0, "Could not redo the build:\n", buildRes.output);
            return true;
        }

        return false;
    }

    string[] reggaeCmd() pure nothrow const {
        immutable _dflags = dflags == "" ? "" : " --dflags='" ~ dflags ~ "'";
        auto mutCmd = [reggaePath, "-b", "binary"];
        if(_dflags != "") mutCmd ~= _dflags;
        return mutCmd ~ projectPath;
    }

    bool checkTimestamps(in Target target) const {
        foreach(dep; chain(target.dependencies, target.implicits)) {

            immutable anyNewer = cartesianProduct(dep.outputsInProjectPath(projectPath),
                                                  target.outputsInProjectPath(projectPath)).
                any!(a => a[0].newerThan(a[1]));

            if(anyNewer) {
                executeCommand(target);
                return true;
            }
        }

        return false;
    }

    bool checkPhony(in Target target) const {
        if(target.command.getType == CommandType.phony) {
            executeCommand(target);
            return true;
        }
        return false;
    }

    //Checks dependencies listed in the .dep file created by the compiler
    bool checkDeps(in Target target, in string depFileName) const @trusted {
        auto file = File(depFileName);
        const dependencies = file.byLine.map!(a => a.to!string).dependenciesFromFile;

        if(dependencies.any!(a => a.newerThan(target.outputsInProjectPath(projectPath)[0]))) {
            executeCommand(target);
            return true;
        }
        return false;
    }

    void executeCommand(in Target target) const @trusted {
        mkDir(target);
        target.execute(projectPath);
    }

    //@trusted because of mkdirRecurse
    private void mkDir(in Target target) @trusted const {
        foreach(output; target.outputsInProjectPath(projectPath)) {
            import std.file: exists, mkdirRecurse;
            import std.path: dirName;
            if(!output.dirName.exists) mkdirRecurse(output.dirName);
        }
    }
}

bool newerThan(in string a, in string b) nothrow {
    try {
        return a.timeLastModified > b.timeLastModified;
    } catch(Exception) { //file not there, so newer
        return true;
    }
}

string[] dependenciesFromFile(R)(R lines) @trusted if(isInputRange!R) {
    return lines.
        map!(a => a.replace(" \\", "")).
        filter!(a => !a.empty).
        map!(a => a.strip).
        array[1..$];
}
