import reggaefile;
import reggae;
import std.stdio;

int main(string[] args) {
    if(args.length != 2) {
        stderr.writeln("Error! Usage: <bin> project_path");
        return 1;
    }
    auto projectPath = args[1];
    auto build = getBuild!reggaefile;
    auto makefile = new Makefile(build, projectPath);
    auto file = File(makefile.fileName, "w");
    file.write(makefile.output);

    return 0;
}
