import reggaefile;
import reggae;
import std.stdio;


int main(string[] args) {
    immutable options = getOptions(args);
    const build = getBuild!reggaefile;

    if(options.backend == "make") {
        const makefile = new Makefile(build, options.projectPath);
        auto file = File(makefile.fileName, "w");
        file.write(makefile.output);
    } else if(options.backend == "ninja") {
        auto ninja = Ninja(build, options.projectPath);

        auto buildNinja = File("build.ninja", "w");
        buildNinja.writeln("include rules.ninja\n");

        foreach(entry; ninja.buildEntries) {
            buildNinja.writeln(entry.toString);
        }

        auto rulesNinja = File("rules.ninja", "w");
        foreach(entry; ninja.ruleEntries) {
            rulesNinja.writeln(entry.toString);
        }
    }

    return 0;
}
