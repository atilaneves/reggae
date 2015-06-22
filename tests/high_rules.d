module tests.high_rules;


import reggae;
import unit_threaded;


void testCObjectFile() {
    immutable fileName = "foo.c";
    const obj = objectFile(fileName, "-g -O0", ["myhdrs", "otherhdrs"]);
    const cmd = Command(CommandType.compile,
                        assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                   "flags", ["-g", "-O0"],
                                   "DEPFILE", ["$out.dep"]));

    obj.shouldEqual(Target("foo.o", cmd, [Target(fileName)]));

}

void testCppObjectFile() {
    foreach(ext; ["cpp", "CPP", "cc", "cxx", "C", "c++"]) {
        immutable fileName = "foo." ~ ext;
        const obj = objectFile(fileName, "-g -O0", ["myhdrs", "otherhdrs"]);
        const cmd = Command(CommandType.compile,
                            assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                       "flags", ["-g", "-O0"],
                                       "DEPFILE", ["$out.dep"]));

        obj.shouldEqual(Target("foo.o", cmd, [Target(fileName)]));
    }
}


void testDObjectFile() {
    const obj = objectFile("foo.d", "-g -debug", ["myhdrs", "otherhdrs"], ["strings", "otherstrings"]);
    const cmd = Command(CommandType.compile,
                        assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                   "flags", ["-g", "-debug"],
                                   "stringImports", ["-J$project/strings", "-J$project/otherstrings"],
                                   "DEPFILE", ["$out.dep"]));

    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.d")]));
}


void testBuiltinTemplateDeps() {
    Command.builtinTemplate(CommandType.compile, Language.C).shouldEqual(
        "gcc $flags $includes -MMD -MT $out -MF $DEPFILE -o $out -c $in");

    Command.builtinTemplate(CommandType.compile, Language.D).shouldEqual(
        ".reggae/dcompile --objFile=$out --depFile=$DEPFILE " ~
         "dmd $flags $includes $stringImports $in");

}

void testBuiltinTemplateNoDeps() {
    Command.builtinTemplate(CommandType.compile, Language.C, No.dependencies).shouldEqual(
        "gcc $flags $includes -o $out -c $in");

    Command.builtinTemplate(CommandType.compile, Language.D, No.dependencies).shouldEqual(
        "dmd $flags $includes $stringImports -of$out -c $in");

}


void testLinkC() {
    const tgt = link("app", [objectFile("foo.c")]);
    tgt.shellCommand.shouldEqual("gcc -o app  foo.o");
}

void testLinkCpp() {
    const tgt = link("app", [objectFile("foo.cpp")]);
    tgt.shellCommand.shouldEqual("g++ -o app  foo.o");
}
