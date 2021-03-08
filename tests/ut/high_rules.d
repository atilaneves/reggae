module tests.ut.high_rules;


import reggae;
import reggae.options;
import reggae.path: buildPath;
import unit_threaded;


version(Windows)
    immutable defaultDCModel = " -m32mscoff";
else
    enum defaultDCModel = null;

@("C object file") unittest {
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
    version(Windows) {
        enum expected = `weirdcc /nologo -g -O0 -I\project\myhdrs -I\project\otherhdrs /showIncludes ` ~
                        `/Fofoo.obj -c \project\foo.c`;
    } else {
        enum expected = "weirdcc -g -O0 -I/project/myhdrs -I/project/otherhdrs -MMD -MT foo.o -MF foo.o.dep " ~
                        "-o foo.o -c /project/foo.c";
    }
    obj.shellCommand(options).shouldEqual(expected);
}

@("C++ object file") unittest {
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


@("D object file") unittest {
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


@("builtinTemplate deps") unittest {
    import reggae.config;

    version(Windows)
        enum expectedC = "cl.exe /nologo $flags $includes /showIncludes /Fo$out -c $in";
    else
        enum expectedC = "gcc $flags $includes -MMD -MT $out -MF $out.dep -o $out -c $in";
    Command.builtinTemplate(CommandType.compile, Language.C, gDefaultOptions).shouldEqual(expectedC);

    Command.builtinTemplate(CommandType.compile, Language.D, gDefaultOptions).shouldEqual(
        buildPath(".reggae/dcompile") ~ " --objFile=$out --depFile=$out.dep " ~
         dCompiler ~ defaultDCModel ~ " $flags $includes $stringImports $in");

}

@("builtinTemplate no deps") unittest {
    import reggae.config;
    import std.typecons: No;

    version(Windows)
        enum expectedC = "cl.exe /nologo $flags $includes /Fo$out -c $in";
    else
        enum expectedC = "gcc $flags $includes -o $out -c $in";
    Command.builtinTemplate(CommandType.compile, Language.C, gDefaultOptions, No.dependencies).shouldEqual(expectedC);

    Command.builtinTemplate(CommandType.compile, Language.D, gDefaultOptions, No.dependencies).shouldEqual(
        dCompiler ~ defaultDCModel ~ " $flags $includes $stringImports -of$out -c $in");

}
