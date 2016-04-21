import std.stdio;
import std.conv;
import constants;


extern(C++) int calc(int i);


void main(string[] args) {
    immutable number = args[1].to!int * leconst;
    immutable result = calc(number);
    writeln(`The result of calc(`, number, `) is `, result);
}
