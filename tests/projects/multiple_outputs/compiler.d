import std.stdio;
import std.regex;
import std.path;
void main(string[] args) {
    auto file = File(args[1]);
    auto c = File(buildPath(args[1].baseName.stripExtension.defaultExtension(`.c`)), `w`);
    auto h = File(buildPath(args[1].baseName.stripExtension.defaultExtension(`.h`)), `w`);
    auto reg = regex(`(\{.+?\})$`);
    foreach(line; file.byLine) {
        c.writeln(line);
        auto headerLine = line.replaceAll(reg, `;`);
        h.writeln(headerLine);
    }
}
