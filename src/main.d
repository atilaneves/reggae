import reggae;
import std.stdio;
import std.process;
import std.array;

int main(string[] args) {
    auto file = File("tmpfile.d", "w");
    file.writeln("import reggaefile;");
    file.writeln("import reggae;");
    file.writeln("import std.stdio;");
    file.writeln("void main() {");
    file.writeln("    auto build = getBuild!reggaefile;");
    file.writeln("    auto makefile = new Makefile(build);");
    file.writeln("    auto file = File(makefile.fileName, `w`);");
    file.writeln("    file.write(makefile.output);");
    file.writeln("}");

    auto cmd = ["rdmd", "--chatty", "-I" ~ args[1], "-I~/coding/d/reggae/src", "tmpfile.d"];
    auto ret = execute(cmd);
    if(ret.status != 0) {
        stderr.writeln("Oops, couldn't execute ", cmd.join(" "), ":\n", ret.output);
        return 1;
    }

    return 0;
}
