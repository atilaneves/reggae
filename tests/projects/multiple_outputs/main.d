import protocol;
import std.stdio;
import std.conv;
void main(string[] args) {
    auto arg = args[1].to!int;
    writeln(`I call protoFunc(`, arg, `) and get `, protoFunc(arg));
}
