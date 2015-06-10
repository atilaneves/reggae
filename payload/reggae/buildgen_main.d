import reggae;
import std.stdio;


int main(string[] args) {
    try {
        generateBuildFor!("reggaefile"); //the user's build description
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}

private void generateBuildFor(alias moduleOrString)() {
    static if(is(moduleOrString == string)) {
        mixin("import " ~ moduleOrString ~ ";");
        mixin("alias module_ = " ~ moduleOrString);
    } else {
        alias module_ = moduleOrString;
    }

    const buildFunc = getBuild!(module_); //get the function to call by CT reflection
    const build = buildFunc(); //actually call the function to get the build description
    generateBuild(build);
}

private void generateBuild(in Build build) {
    final switch(backend) with(Backend) {

        case make:
            handleMake(build);
            break;

        case ninja:
            handleNinja(build);
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
