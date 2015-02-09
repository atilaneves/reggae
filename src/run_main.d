import reggaefile;
import reggae;
import std.stdio;

void main(string[] args) {
    auto build = getBuild!reggaefile;
    auto makefile = new Makefile(build);
    auto file = File(makefile.fileName, "w");
    file.write(makefile.output);
}
