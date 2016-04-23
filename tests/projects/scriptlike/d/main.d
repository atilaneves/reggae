extern(C++) int calc(int i, int j);
import std.stdio;
import std.conv;
import logger;
void main(string[] args) {
    immutable a = args[1].to!int;
    immutable b = args[2].to!int;
    writeln(import(`banner.txt`));
    log(`The result of feeding `, a, ` and `, b, ` to C++ is `, calc(a, b));
}
