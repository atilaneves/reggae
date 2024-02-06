import std.stdio;
import std.conv;

extern(C++) {
    int add(int a, int b);
    int subtract(int a, int b);
    int multiply(int a, int b);
}

void main(string[] args) {
    int num1 = args[1].to!int;
    int num2 = args[2].to!int;

    writeln(add(num1, num2));
    writeln(subtract(num1, num2));
    writeln(multiply(num1, num2));
}
