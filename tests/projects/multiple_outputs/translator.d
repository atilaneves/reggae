import std.stdio;
import std.path;
import std.file;
import std.exception;
import std.conv;
import std.algorithm;
void main(string[] args) {
    enforce(args.length == 3, text(`Invalid translator args `, args));
    immutable dir = args[2].dirName;
    if(!dir.exists()) mkdir(dir);
    auto input  = File(args[1], `r`);
    auto output = File(args[2], `w`);
    foreach(l; input.byLine) output.write(`extern(C) ` ~ l);
    output.writeln;
}
