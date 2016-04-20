extern(C++) int calc(int i);
import std.stdio;
import std.conv;
void main(string[] args) {
    immutable number = args[1].to!int;
    immutable result = calc(number);
    writeln(`The result of calc(`, number, `) is `, result);
}
