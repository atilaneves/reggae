import reggae;
import std.stdio;
import std.process: execute;
import std.array: array, join;
import std.path: absolutePath;

int main(string[] args) {
    {
        auto file = File("tmpfile.d", "w");
        file.write(import("run_main.d"));
    }

    const path = args[1];
    auto cmd = ["rdmd", "--chatty", "-I" ~ path, "-I~/coding/d/reggae/src",
                "tmpfile.d", path];
    auto ret = execute(cmd);
    if(ret.status != 0) {
        stderr.writeln("Couldn't execute ", cmd.join(" "), ":\n", ret.output);
        return 1;
    }

    return 0;
}
