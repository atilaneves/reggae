module tests.high_rules;


import reggae;
import unit_threaded;


void testCObjectFile() {
    immutable fileName = "foo.c";
    const obj = objectFile(SourceFile(fileName),
                           Flags("-g -O0"),
                           IncludePaths(["myhdrs", "otherhdrs"]));
    const cmd = Command(CommandType.compile,
                        assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                   "flags", ["-g", "-O0"],
                                   "DEPFILE", ["foo.o.dep"]));

    obj.shouldEqual(Target("foo.o", cmd, [Target(fileName)]));

}

void testCppObjectFile() {
    foreach(ext; ["cpp", "CPP", "cc", "cxx", "C", "c++"]) {
        immutable fileName = "foo." ~ ext;
        const obj = objectFile(SourceFile(fileName),
                               Flags("-g -O0"),
                               IncludePaths(["myhdrs", "otherhdrs"]));
        const cmd = Command(CommandType.compile,
                            assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                       "flags", ["-g", "-O0"],
                                       "DEPFILE", ["foo.o.dep"]));

        obj.shouldEqual(Target("foo.o", cmd, [Target(fileName)]));
    }
}


void testDObjectFile() {
    const obj = objectFile(SourceFile("foo.d"),
                           Flags("-g -debug"),
                           ImportPaths(["myhdrs", "otherhdrs"]),
                           StringImportPaths(["strings", "otherstrings"]));
    const cmd = Command(CommandType.compile,
                        assocListT("includes", ["-I$project/myhdrs", "-I$project/otherhdrs"],
                                   "flags", ["-g", "-debug"],
                                   "stringImports", ["-J$project/strings", "-J$project/otherstrings"],
                                   "DEPFILE", ["foo.o.dep"]));

    obj.shouldEqual(Target("foo.o", cmd, [Target("foo.d")]));
}


void testBuiltinTemplateDeps() {
    import reggae.config: options;

    Command.builtinTemplate(CommandType.compile, Language.C, options).shouldEqual(
        "gcc $flags $includes -MMD -MT $out -MF $out.dep -o $out -c $in");

    Command.builtinTemplate(CommandType.compile, Language.D, options).shouldEqual(
        ".reggae/dcompile --objFile=$out --depFile=$out.dep " ~
         "dmd $flags $includes $stringImports $in");

}

void testBuiltinTemplateNoDeps() {
    import reggae.config: options;
    Command.builtinTemplate(CommandType.compile, Language.C, options, No.dependencies).shouldEqual(
        "gcc $flags $includes -o $out -c $in");

    Command.builtinTemplate(CommandType.compile, Language.D, options, No.dependencies).shouldEqual(
        "dmd $flags $includes $stringImports -of$out -c $in");

}


void testLinkC() {
    const tgt = link(ExeName("app"), [objectFile(SourceFile("foo.c"))]);
    tgt.shellCommand.shouldEqual("gcc -o app  foo.o");
}

void testLinkCpp() {
    const tgt = link(ExeName("app"), [objectFile(SourceFile("foo.cpp"))]);
    tgt.shellCommand.shouldEqual("g++ -o app  foo.o");
}
