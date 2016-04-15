import maths;
import std.stdio;
import std.conv;
void main(string[] args) {
    auto a = args[1].to!int;
    auto b = args[2].to!int;
    writeln(`The sum     of `, a, ` and `, b, ` is `, adder(a, b));
    writeln(`The product of `, a, ` and `, b, ` is `, prodder(a, b));
}
