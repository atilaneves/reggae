import std.stdio;


void main() {
    auto makefile = File("Makefile", "w");
    makefile.writeln("all: myapp");
    makefile.writeln("main.o: path/to/src/main.d");
    makefile.writeln("\tdmd -Ipath/to/src -ofmain.o -c path/to/src/main.d");
    makefile.writeln("maths.o: path/to/src/maths.d");
    makefile.writeln("\tdmd -Ipath/to/src -ofmaths.o -c path/to/src/maths.d");
    makefile.writeln("myapp: main.o maths.o");
    makefile.writeln("\tdmd -ofmyapp main.o maths.o");
}
