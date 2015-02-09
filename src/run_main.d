import reggaefile;
import reggae;
import std.stdio;

void main(string[] args) {
    if(args.length != 2) {
        stderr.writeln("Usage: <bin> project_path");
    }
    auto projectPath = args[1];
    auto build = getBuild!reggaefile;
    auto makefile = new Makefile(build, projectPath);
    auto file = File(makefile.fileName, "w");
    file.write(makefile.output);
}
