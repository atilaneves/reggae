import reggaefile;
import reggae;
import std.stdio;


int main(string[] args) {
    try {
        immutable options = getOptions(args);
        const buildFunc = getBuild!(reggaefile);
        const build = buildFunc();

        switch(options.backend) {

        case "make":
            const makefile = Makefile(build, options.projectPath);
            auto file = File(makefile.fileName, "w");
            file.write(makefile.output);
            break;

        case "ninja":
            const ninja = Ninja(build, options.projectPath);

            auto buildNinja = File("build.ninja", "w");
            buildNinja.writeln("include rules.ninja\n");

            foreach(entry; ninja.buildEntries) {
                buildNinja.writeln(entry.toString);
            }

            auto rulesNinja = File("rules.ninja", "w");
            foreach(entry; ninja.allRuleEntries) {
                rulesNinja.writeln(entry.toString);
            }

            break;

        case "":
            throw new Exception("A backend must be specified with -b/--backend");

        default:
            throw new Exception("Unsupported backend " ~ options.backend);
        }
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}
