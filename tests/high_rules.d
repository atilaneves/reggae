module tests.high_rules;


import reggae;
import unit_threaded;


void testWeirdFile() {
    objectFile("foo.weird").shouldThrow;
}

void testCObjectFile() {
    const obj = objectFile("foo.c", "-g -O0", ["myhdrs", "otherhdrs"]);
    immutable cmd = "_ccompile includes=-I$project/myhdrs,-I$project/otherhdrs flags=-g,-O0";
    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.c")]));

    obj.shouldEqual(cCompile("foo.c", "-g -O0", ["myhdrs", "otherhdrs"]));
}

void testCppObjectFile() {
    const obj = objectFile("foo.cpp", "-g -O0", ["myhdrs", "otherhdrs"]);
    immutable cmd = "_cppcompile includes=-I$project/myhdrs,-I$project/otherhdrs flags=-g,-O0";
    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.cpp")]));
    obj.shouldEqual(cppCompile("foo.cpp", "-g -O0", ["myhdrs", "otherhdrs"]));
}


void testDObjectFile() {
    const obj = objectFile("foo.d", "-g -debug", ["myhdrs", "otherhdrs"], ["strings", "otherstrings"]);
    immutable cmd = "_dcompile includes=-I$project/myhdrs,-I$project/otherhdrs flags=-g,-debug " ~
        "stringImports=-J$project/strings,-J$project/otherstrings";
    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.d")]));
    obj.shouldEqual(dCompile("foo.d", "-g -debug", ["myhdrs", "otherhdrs"], ["strings", "otherstrings"]));
}
