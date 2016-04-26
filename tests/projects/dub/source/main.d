import strings;
import cerealed;
import std.stdio;
void main(string[] args) {
    writeln(import(`banner.txt`));
    auto enc = Cerealiser();
    enc ~= 4;
    writeln(enc.bytes);
    writeln(string1);
}
