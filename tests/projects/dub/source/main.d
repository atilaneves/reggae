import strings;
import std.stdio;

void main(string[] args) {
    writeln(import(`banner.txt`));
    writeln(string1);
}


unittest {
    assert(1 == 2, `oopsie`);
}
