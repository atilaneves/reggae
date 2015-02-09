import reggaefile;
import reggae;
import std.stdio;

void main(string[] args) {
    auto projectPath = args[1];
    auto build = getBuild!reggaefile;
    auto makefile = new Makefile(build, projectPath);
    auto file = File(makefile.fileName, "w");
    file.write(makefile.output);
}
