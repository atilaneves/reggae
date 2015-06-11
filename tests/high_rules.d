module tests.high_rules;


import reggae;
import unit_threaded;


void testWeirdFile() {
    objectFile("foo.weird").shouldThrow;
}

void testCObjectFile() {
    immutable fileName = "foo.c";
    const obj = objectFile(fileName, "-g -O0", ["myhdrs", "otherhdrs"]);
    const cmd = Command(CommandType.compileC,
                        assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                   "flags", ["-g", "-O0"],
                                   "DEPFILE", ["$out.dep"]));

    obj.shouldEqual(Target("foo.o", cmd, [Target(fileName)]));

}

void testCppObjectFile() {
    foreach(ext; ["cpp", "CPP", "cc", "cxx", "C", "c++"]) {
        immutable fileName = "foo." ~ ext;
        const obj = objectFile(fileName, "-g -O0", ["myhdrs", "otherhdrs"]);
        const cmd = Command(CommandType.compileCpp,
                            assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                       "flags", ["-g", "-O0"],
                                       "DEPFILE", ["$out.dep"]));

        obj.shouldEqual(Target("foo.o", cmd, [Target(fileName)]));
    }
}


void testDObjectFile() {
    const obj = objectFile("foo.d", "-g -debug", ["myhdrs", "otherhdrs"], ["strings", "otherstrings"]);
    const cmd = Command(CommandType.compileD,
                        assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                   "flags", ["-g", "-debug"],
                                   "stringImports", ["-J$project/strings", "-J$project/otherstrings"],
                                   "DEPFILE", ["$out.dep"]));

    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.d")]));
}
