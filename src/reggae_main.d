import reggae;
import std.stdio;
import std.process;
import std.array;


int main(string[] args) {
    auto file = File("tmpfile.d", "w");
    immutable runMain = import("run_main.d");
    file.write(runMain);

    auto cmd = ["rdmd", "--chatty", "-I" ~ args[1], "-I~/coding/d/reggae/src", "tmpfile.d"];
    auto ret = execute(cmd);
    if(ret.status != 0) {
        stderr.writeln("Oops, couldn't execute ", cmd.join(" "), ":\n", ret.output);
        return 1;
    }

    return 0;
}
