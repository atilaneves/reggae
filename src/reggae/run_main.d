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
        foreach(fileName; ["build.ninja", "rules.ninja"]) {
            auto file = File(fileName, "w");
            file.write("");
        }
    }

    return 0;
}
