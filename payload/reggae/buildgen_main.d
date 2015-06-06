import reggaefile; //the user's build description
import reggae;
import reggae.dependencies;
import std.stdio;


int main(string[] args) {
    try {
        generateBuild;
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}


private void generateBuild() {
    const buildFunc = getBuild!(reggaefile); //get the function to call by CT reflection
    const build = buildFunc(); //actually call the function to get the build description

    final switch(backend) with(Backend) {

        case make:
            const makefile = Makefile(build, projectPath);
            auto file = File(makefile.fileName, "w");
            file.write(makefile.output);
            break;

        case ninja:
            const ninja = Ninja(build, projectPath);

            auto buildNinja = File("build.ninja", "w");
            buildNinja.writeln("include rules.ninja\n");
            buildNinja.writeln(ninja.buildOutput);

            auto rulesNinja = File("rules.ninja", "w");
            rulesNinja.writeln(ninja.rulesOutput);

            break;

        case binary:
            const binary = Binary(build, projectPath);
            binary.run();
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
}
