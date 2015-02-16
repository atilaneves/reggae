import reggaefile;
import reggae;
import std.stdio;


int main(string[] args) {
    immutable options = getOptions(args);
    const build = getBuild!reggaefile;

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
        foreach(entry; ninja.ruleEntries ~ defaultRules) {
            rulesNinja.writeln(entry.toString);
        }

        break;

    case "":
        stderr.writeln("A backend must be specified with -b/--backend");
        return 1;

    default:
        stderr.writeln("Unsupported backend ", options.backend);
        return 1;
    }

    return 0;
}
