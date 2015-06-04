import reggaefile; //the user's build description
import reggae;
import std.stdio;


int main() {
    try {
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

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}
