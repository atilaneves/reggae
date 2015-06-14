module reggae.buildgen;

import reggae;
import std.stdio;

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
            generateBuildFor!(buildModule); //the user's build description
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }

        return 0;
    }
}

void generateBuildFor(alias module_)() {
    const buildFunc = getBuild!(module_); //get the function to call by CT reflection
    const build = buildFunc(); //actually call the function to get the build description
    generateBuild(build);
}

void generateBuild(in Build build) {
    final switch(backend) with(Backend) {

        case make:
            handleMake(build);
            break;

        case ninja:
            handleNinja(build);
            break;

        case tup:
            handleTup(build);
            break;

        case binary:
            Binary(build, projectPath).run();
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
}

private void handleNinja(in Build build) {
    version(minimal) {
        throw new Exception("Ninja backend support not compiled in");
    } else {

        const ninja = Ninja(build, projectPath);

        auto buildNinja = File("build.ninja", "w");
        buildNinja.writeln("include rules.ninja\n");
        buildNinja.writeln(ninja.buildOutput);

        auto rulesNinja = File("rules.ninja", "w");
        rulesNinja.writeln(ninja.rulesOutput);
    }
}


private void handleMake(in Build build) {
    version(minimal) {
        throw new Exception("Make backend support not compiled in");
    } else {

        const makefile = Makefile(build, projectPath);
        auto file = File(makefile.fileName, "w");
        file.write(makefile.output);
    }
}

private void handleTup(in Build build) {
    version(minimal) {
        throw new Exception("Tup backend support not compiled in");
    } else {
        if(!".tup".exists) execute(["tup", "init"]);
        const tup = Tup(build, projectPath);
        auto file = File(tup.fileName, "w");
        file.write(tup.output);
    }
}
