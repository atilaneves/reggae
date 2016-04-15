import std.stdio;
import source.foo;
void main(string[] args) {
    writeln(`Appending to `, args[1], ` yields `, appender(args[1]));
}
