module reggae.buildgen;

import reggae.build;
import reggae.options;
import reggae.types;
import reggae.backend;
import reggae.reflect;

import std.stdio;
import std.file: timeLastModified;

/**
 Creates a build generator out of a module and a list of top-level targets.
 This will define a function with the signature $(D Build buildFunc()) in
 the calling module and a $(D main) entry point function for a command-line
 executable.
 */
mixin template buildGen(string buildModule, targets...) {
    mixin buildImpl!targets;
    mixin BuildGenMain!buildModule;
}

mixin template BuildGenMain(string buildModule = "reggaefile") {
    import std.stdio;

    int main(string[] args) {
        try {
            import reggae.config: options;
            generateBuildFor!(buildModule)(options, args); //the user's build description
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }

        return 0;
    }
}

void generateBuildFor(alias module_)(in Options options, string[] args) {
    auto build = getBuildObject!module_(options);
    if(!options.noCompilationDB) writeCompilationDB(build, options);
    generateBuild(build, options, args);
}

private Build getBuildObject(alias module_)(in Options options) {
    immutable cacheFileName = buildPath(".reggae", "cache");
    if(!options.cacheBuildInfo ||
       !cacheFileName.exists ||
        thisExePath.timeLastModified > cacheFileName.timeLastModified) {
        const buildFunc = getBuild!(module_); //get the function to call by CT reflection
        auto build = buildFunc(); //actually call the function to get the build description

        if(options.cacheBuildInfo) {
            auto file = File(cacheFileName, "w");
            file.rawWrite(build.toBytes(options));
        }

        return build;
    } else {
        auto file = File(cacheFileName);
        auto buffer = new ubyte[file.size];
        return Build.fromBytes(file.rawRead(buffer));
    }
}

void generateBuild(Build build, in Options options, string[] args = []) {
    options.export_ ? exportBuild(build, options) : generateOneBuild(build, options, args);
}

private void generateOneBuild(Build build, in Options options, string[] args = []) {
    final switch(options.backend) with(Backend) {

        case make:
            handleMake(build, options);
            break;

        case ninja:
            handleNinja(build, options);
            break;

        case tup:
            handleTup(build, options);
            break;

        case binary:
            Binary(build, options).run(args);
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
}

private void exportBuild(Build build, in Options options) {
    enforce(options.backend == Backend.none, "Cannot specify a backend and export at the same time");

    handleMake(build, options);
    handleNinja(build, options);
    handleTup(build, options);
}

private void handleNinja(Build build, in Options options) {
    version(minimal) {
        throw new Exception("Ninja backend support not compiled in");
    } else {

        auto ninja = Ninja(build, options);

        auto buildNinja = File("build.ninja", "w");
        buildNinja.writeln(ninja.buildOutput);

        auto rulesNinja = File("rules.ninja", "w");
        rulesNinja.writeln(ninja.rulesOutput);
    }
}


private void handleMake(Build build, in Options options) {
    version(minimal) {
        throw new Exception("Make backend support not compiled in");
    } else {

        auto makefile = Makefile(build, options);
        auto file = File(makefile.fileName, "w");
        file.write(makefile.output);
    }
}

private void handleTup(Build build, in Options options) {
    version(minimal) {
        throw new Exception("Tup backend support not compiled in");
    } else {
        if(!".tup".exists) {
            import std.process;
            immutable args = ["tup", "init"];
            try
                execute(args);
            catch(ProcessException _)
                stderr.writeln("Could not execute '", args.join(" "), "'. tup builds need to do that first.");
        }
        auto tup = Tup(build, options);
        auto file = File(tup.fileName, "w");
        file.write(tup.output);
    }
}


private void writeCompilationDB(Build build, in Options options) {
    import std.file;
    import std.conv;
    import std.algorithm;

    auto file = File("compile_commands.json", "w");
    file.writeln("[");

    immutable cwd = getcwd;
    string entry(Target target) {
        return
            "    {\n" ~
            text(`        "directory": "`, cwd, `"`) ~ ",\n" ~
            text(`        "command": "`, target.shellCommand(options), `"`) ~ ",\n" ~
            text(`        "file": "`, target.outputsInProjectPath(options.projectPath).join(" "), `"`) ~ "\n" ~
            "    }";
    }

    file.write(build.range.map!(a => entry(a)).join(",\n"));
    file.writeln;
    file.writeln("]");
}
