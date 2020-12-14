module tests.ut.high_rules;


import reggae;
import reggae.options;
import reggae.path: buildPath;
import unit_threaded;
import std.typecons: No;


void testCObjectFile() {
    immutable fileName = "foo.c";
    enum objPath = "foo" ~ objExt;
    auto obj = objectFile(SourceFile(fileName),
                           Flags("-g -O0"),
                           IncludePaths(["myhdrs", "otherhdrs"]));
    auto cmd = Command(CommandType.compile,
                        assocListT("includes", [buildPath("-I$project/myhdrs"), buildPath("-I$project/otherhdrs")],
                                   "flags", ["-g", "-O0"],
                                   "DEPFILE", [objPath ~ ".dep"]));

    obj.shouldEqual(Target(objPath, cmd, [Target(fileName)]));

    auto options = Options();
    options.cCompiler = "weirdcc";
    options.projectPath = "/project";
    obj.shellCommand(options).shouldEqual(
        "weirdcc -g -O0 -I" ~ buildPath("/project/myhdrs") ~ " -I" ~ buildPath("/project/otherhdrs") ~
        " -MMD -MT " ~ objPath ~ " -MF " ~ objPath ~ ".dep -o " ~ objPath ~ " -c " ~ buildPath("/project/foo.c"));
}

void testCppObjectFile() {
    foreach(ext; ["cpp", "CPP", "cc", "cxx", "C", "c++"]) {
        immutable fileName = "foo." ~ ext;
        enum objPath = "foo" ~ objExt;
        auto obj = objectFile(SourceFile(fileName),
                               Flags("-g -O0"),
                               IncludePaths(["myhdrs", "otherhdrs"]));
        auto cmd = Command(CommandType.compile,
                            assocListT("includes", [buildPath("-I$project/myhdrs"), buildPath("-I$project/otherhdrs")],
                                       "flags", ["-g", "-O0"],
                                       "DEPFILE", [objPath ~ ".dep"]));

        obj.shouldEqual(Target(objPath, cmd, [Target(fileName)]));
    }
}


void testDObjectFile() {
    auto obj = objectFile(SourceFile("foo.d"),
                           Flags("-g -debug"),
                           ImportPaths(["myhdrs", "otherhdrs"]),
                           StringImportPaths(["strings", "otherstrings"]));
    enum objPath = "foo" ~ objExt;
    auto cmd = Command(CommandType.compile,
                        assocListT("includes", [buildPath("-I$project/myhdrs"), buildPath("-I$project/otherhdrs")],
                                   "flags", ["-g", "-debug"],
                                   "stringImports", [buildPath("-J$project/strings"), buildPath("-J$project/otherstrings")],
                                   "DEPFILE", [objPath ~ ".dep"]));

    obj.shouldEqual(Target(objPath, cmd, [Target("foo.d")]));
}


void testBuiltinTemplateDeps() {
    import reggae.config;

    Command.builtinTemplate(CommandType.compile, Language.C, gDefaultOptions).shouldEqual(
        "gcc $flags $includes -MMD -MT $out -MF $out.dep -o $out -c $in");

    Command.builtinTemplate(CommandType.compile, Language.D, gDefaultOptions).shouldEqual(
        buildPath(".reggae/dcompile") ~ " --objFile=$out --depFile=$out.dep " ~
         "dmd $flags $includes $stringImports $in");

}

void testBuiltinTemplateNoDeps() {
    import reggae.config;

    Command.builtinTemplate(CommandType.compile, Language.C, gDefaultOptions, No.dependencies).shouldEqual(
        "gcc $flags $includes -o $out -c $in");

    Command.builtinTemplate(CommandType.compile, Language.D, gDefaultOptions, No.dependencies).shouldEqual(
        "dmd $flags $includes $stringImports -of$out -c $in");

}
