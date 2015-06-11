module tests.high_rules;


import reggae;
import unit_threaded;


void testWeirdFile() {
    objectFile("foo.weird").shouldThrow;
}

void testCObjectFile() {
    const obj = objectFile("foo.c", "-g -O0", ["myhdrs", "otherhdrs"]);
    const cmd = Command(CommandType.compileC, assocList([assocEntry("includes", ["-I$project/myhdrs",
                                                                          "-I$project/otherhdrs"]),
                                                  assocEntry("flags", ["-g", "-O0"])]));
    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.c")]));
}

void testCppObjectFile() {
    foreach(ext; ["cpp", "CPP", "cc", "cxx", "C", "c++"]) {
        immutable fileName = "foo." ~ ext;
        const obj = objectFile(fileName, "-g -O0", ["myhdrs", "otherhdrs"]);
        const cmd = Command(CommandType.compileCpp, assocList([assocEntry("includes", ["-I$project/myhdrs",
                                                                              "-I$project/otherhdrs"]),
                                                        assocEntry("flags", ["-g", "-O0"])]));

        obj.shouldEqual(Target("foo.o", cmd, [Target(fileName)]));
    }
}


void testDObjectFile() {
    const obj = objectFile("foo.d", "-g -debug", ["myhdrs", "otherhdrs"], ["strings", "otherstrings"]);
    const cmd = Command(CommandType.compileD, assocList([assocEntry("includes", ["-I$project/myhdrs",
                                                                                 "-I$project/otherhdrs"]),
                                                         assocEntry("flags", ["-g", "-debug"]),
                                                         assocEntry("stringImports",
                                                                    ["-J$project/strings",
                                                                     "-J$project/otherstrings"])]));

    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.d")]));
}
