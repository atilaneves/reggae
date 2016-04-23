import adder, muler;
import std.stdio, std.conv;
void main(string[] args) {
    immutable i = args[1].to!int;
    immutable j = args[2].to!int;
    writeln(`Adding      `, i, ` and `, j, `: `, add(i, j));
    writeln(`Multiplying `, i, ` and `, j, `: `, mul(i, j));
}
