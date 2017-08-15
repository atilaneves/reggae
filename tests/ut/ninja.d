module tests.ut.ninja;

import unit_threaded;
import reggae;
import reggae.options;


void testEmpty() {
    auto ninja = Ninja();
    ninja.buildEntries.shouldEqual([]);
    ninja.ruleEntries.shouldEqual([]);
}

void testCppLinker() {
    auto ninja = Ninja(Build(Target("mybin",
                                     "/usr/bin/c++ $in -o $out",
                                     [Target("foo.o"), Target("bar.o")],
                                  )));
    ninja.buildEntries.shouldEqual([NinjaEntry("build mybin: cpp foo.o bar.o",
                                               ["between = -o"])
                                       ]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule cpp",
                                              ["command = /usr/bin/c++ $in $between $out"])
                                      ]);
}

void testCppLinkerProjectPath() {
    auto ninja = Ninja(Build(Target("mybin",
                                     "/usr/bin/c++ $in -o $out",
                                     [Target("foo.o"), Target("bar.o")],
                                  )),
                        "/home/user/myproject");
    ninja.buildEntries.shouldEqual([NinjaEntry("build mybin: cpp /home/user/myproject/foo.o /home/user/myproject/bar.o",
                                               ["between = -o"])
                                       ]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule cpp",
                                              ["command = /usr/bin/c++ $in $between $out"])
                                      ]);
}


void testCppLinkerProjectPathAndBuild() {
    auto ninja = Ninja(Build(Target("mybin",
                                     "/usr/bin/c++ $in -o $out",
                                     [Target("foo.o"), Target("bar.o")],
                                  )),
                        "/home/user/myproject");
    ninja.buildEntries.shouldEqual([NinjaEntry("build mybin: cpp /home/user/myproject/foo.o /home/user/myproject/bar.o",
                                               ["between = -o"])
                                       ]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule cpp",
                                              ["command = /usr/bin/c++ $in $between $out"])
                                      ]);
}


void testIccBuild() {
    auto ninja = Ninja(Build(Target("/path/to/foo.o",
                                     "icc.12.0.022b.i686-linux -pe-file-prefix=/usr/intel/12.0.022b/cc/12.0.022b/include/ @/usr/lib/icc-cc.cfg -I/path/to/headers -gcc-version=345 -fno-strict-aliasing -nostdinc -include /path/to/myheader.h -DTOOL_CHAIN_GCC=gcc-user -D__STUFF__ -imacros /path/to/preinclude_macros.h -I/path/to -Wall -c -MD -MF /path/to/foo.d -o $out $in",
                                     [Target("/path/to/foo.c")])));
    ninja.buildEntries.shouldEqual([NinjaEntry("build /path/to/foo.o: icc.12.0.022b.i686-linux /path/to/foo.c",
                                               ["before = -pe-file-prefix=/usr/intel/12.0.022b/cc/12.0.022b/include/ @/usr/lib/icc-cc.cfg -I/path/to/headers -gcc-version=345 -fno-strict-aliasing -nostdinc -include /path/to/myheader.h -DTOOL_CHAIN_GCC=gcc-user -D__STUFF__ -imacros /path/to/preinclude_macros.h -I/path/to -Wall -c -MD -MF /path/to/foo.d -o"])]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule icc.12.0.022b.i686-linux",
                                              ["command = icc.12.0.022b.i686-linux $before $out $in"])]);
}


void testBeforeAndAfter() {
    auto ninja = Ninja(Build(Target("foo.temp",
                                     "icc @/path/to/icc-ld.cfg -o $out $in -Wl,-rpath-link -Wl,/usr/lib",
                                     [Target("main.o"), Target("extra.o"), Target("sub_foo.o"), Target("sub_bar.o"),
                                      Target("sub_baz.a")])));
    ninja.buildEntries.shouldEqual([NinjaEntry("build foo.temp: icc main.o extra.o sub_foo.o sub_bar.o sub_baz.a",
                                               ["before = @/path/to/icc-ld.cfg -o",
                                                "after = -Wl,-rpath-link -Wl,/usr/lib"])]);
    ninja.ruleEntries.shouldEqual([NinjaEntry("rule icc",
                                              ["command = icc $before $out $in $after"])]);
}

void testSimpleDBuild() {
    auto mainObj  = Target(`main.o`,  `dmd -I$project/src -c $in -of$out`, Target(`src/main.d`));
    auto mathsObj = Target(`maths.o`, `dmd -c $in -of$out`, Target(`src/maths.d`));
    auto app = Target(`myapp`,
                       `dmd -of$out $in`,
                       [mainObj, mathsObj]
        );
    auto build = Build(app);
    auto ninja = Ninja(build, "/path/to/project");

    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build .reggae/objs/myapp.objs/main.o: dmd /path/to/project/src/main.d",
                    ["before = -I/path/to/project/src -c",
                     "between = -of"]),
         NinjaEntry("build .reggae/objs/myapp.objs/maths.o: dmd /path/to/project/src/maths.d",
                    ["before = -c",
                     "between = -of"]),
         NinjaEntry("build myapp: dmd_2 .reggae/objs/myapp.objs/main.o .reggae/objs/myapp.objs/maths.o",
                    ["before = -of"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule dmd",
                    ["command = dmd $before $in $between$out"]),
         NinjaEntry("rule dmd_2",
                    ["command = dmd $before$out $in"])
            ]);
}


void testImplicitDependencies() {
    auto target = Target("foo.o", "gcc -o $out -c $in", [Target("foo.c")], [Target("foo.h")]);
    auto ninja = Ninja(Build(target));
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: gcc foo.c | foo.h",
                    ["before = -o",
                     "between = -c"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule gcc",
                    ["command = gcc $before $out $between $in"])]);
}

void testImplicitDependenciesMoreThanOne() {
    auto target = Target("foo.o", "gcc -o $out -c $in", [Target("foo.c")], [Target("foo.h"), Target("foo.idl")]);
    auto ninja = Ninja(Build(target));
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.o: gcc foo.c | foo.h foo.idl",
                    ["before = -o",
                     "between = -c"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule gcc",
                    ["command = gcc $before $out $between $in"])]);
}


void testDefaultRules() {
    import reggae.config: gDefaultOptions;
    defaultRules(gDefaultOptions).shouldEqual(
        [
            NinjaEntry("rule _ccompile",
                       ["command = gcc $flags $includes -MMD -MT $out -MF $out.dep -o $out -c $in",
                        "deps = gcc",
                        "depfile = $out.dep"]),
            NinjaEntry("rule _cppcompile",
                       ["command = g++ $flags $includes -MMD -MT $out -MF $out.dep -o $out -c $in",
                        "deps = gcc",
                        "depfile = $out.dep"]),
            NinjaEntry("rule _dcompile",
                       ["command = .reggae/dcompile --objFile=$out --depFile=$out.dep dmd $flags $includes $stringImports $in",
                        "deps = gcc",
                        "depfile = $out.dep"]),
            NinjaEntry("rule _clink",
                       ["command = gcc -o $out $flags $in"]),
            NinjaEntry("rule _cpplink",
                       ["command = g++ -o $out $flags $in"]),
            NinjaEntry("rule _dlink",
                       ["command = dmd -of$out $flags $in"]),
            NinjaEntry("rule _ulink",
                       ["command = dmd -of$out $flags $in"]),
            NinjaEntry("rule _ccompileAndLink",
                       ["command = gcc $flags $includes -MMD -MT $out -MF $out.dep -o $out $in",
                        "deps = gcc",
                        "depfile = $out.dep"]),
            NinjaEntry("rule _cppcompileAndLink",
                       ["command = g++ $flags $includes -MMD -MT $out -MF $out.dep -o $out $in",
                        "deps = gcc",
                        "depfile = $out.dep"]),
            NinjaEntry("rule _dcompileAndLink",
                       ["command = .reggae/dcompile --objFile=$out --depFile=$out.dep dmd $flags $includes $stringImports $in",
                        "deps = gcc",
                        "depfile = $out.dep"]),

            NinjaEntry("rule _phony",
                       ["command = $cmd"]),
            ]);
}

void testDefaultRulesWeirdCCompiler() {
    auto options = Options();
    options.cCompiler = "weirdcc";
    auto rules = defaultRules(options);
    auto entry = NinjaEntry("rule _ccompile",
                            ["command = weirdcc $flags $includes -MMD -MT $out -MF $out.dep -o $out -c $in",
                             "deps = gcc",
                             "depfile = $out.dep"]);
    entry.shouldBeIn(rules);
}

void testImplicitOutput() {
    auto foo = Target(["foo.h", "foo.c"], "protocomp $in", [Target("foo.proto")]);
    auto bar = Target(["bar.h", "bar.c"], "protocomp $in", [Target("bar.proto")]);
    auto ninja = Ninja(Build(foo, bar));

    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build foo.h foo.c: protocomp foo.proto"),
         NinjaEntry("build bar.h bar.c: protocomp bar.proto")]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule protocomp",
                    ["command = protocomp $in "])]);
}


void testImplicitInput() {
    auto protoSrcs = Target([`$builddir/gen/protocol.c`, `$builddir/gen/protocol.h`],
                             `./compiler $in`,
                             [Target(`protocol.proto`)]);
    auto protoObj = Target(`$builddir/bin/protocol.o`,
                            `gcc -o $out -c $builddir/gen/protocol.c`,
                            [], [protoSrcs]);
    auto protoD = Target(`$builddir/gen/protocol.d`,
                          `./translator $builddir/gen/protocol.h $out`,
                          [], [protoSrcs]);
    auto app = Target(`app`, `dmd -of$out $in`,
                       [Target("src/main.d"), protoObj, protoD]);

    auto ninja = Ninja(Build(app));

    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build gen/protocol.c gen/protocol.h: compiler protocol.proto"),
         NinjaEntry("build bin/protocol.o: gcc gen/protocol.c | gen/protocol.c gen/protocol.h",
                    ["before = -o",
                     "between = -c"]),
         NinjaEntry("build gen/protocol.d: translator gen/protocol.h | gen/protocol.c gen/protocol.h"),
         NinjaEntry("build app: dmd src/main.d bin/protocol.o gen/protocol.d",
                    ["before = -of"])
            ]);

    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule compiler",
                    ["command = ./compiler $in "]),
         NinjaEntry("rule gcc",
                    ["command = gcc $before $out $between $in"]),
         NinjaEntry("rule translator",
                    ["command = ./translator $in $out"]),
         NinjaEntry("rule dmd",
                    ["command = dmd $before$out $in"])
            ]);
}


void testOutputInProjectPathCustom() {
    auto tgt = Target("$project/foo.o", "gcc -o $out -c $in", Target("foo.c"));
    auto ninja = Ninja(Build(tgt), "/path/to/proj");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build /path/to/proj/foo.o: gcc /path/to/proj/foo.c",
                    ["before = -o",
                     "between = -c"])]);
}


void testOutputAndDepOutputInProjectPath() {
    auto fooLib = Target("$project/foo.so", "dmd -of$out $in", [Target("src1.d"), Target("src2.d")]);
    auto symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
    auto symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
    auto build = Build(symlink1, symlink2); //defined by the mixin
    auto ninja = Ninja(build, "/tmp/proj");

    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build /tmp/proj/foo.so: dmd /tmp/proj/src1.d /tmp/proj/src2.d",
                    ["before = -of"]),
         NinjaEntry("build /tmp/proj/weird/path/thingie1: ln /tmp/proj/foo.so",
                    ["before = -sf"]),
         NinjaEntry("build /tmp/proj/weird/path/thingie2: ln /tmp/proj/foo.so",
                    ["before = -sf"]),
            ]
        );
}

void testOutputInProjectPathDefault() {
    import reggae.ctaa;
    auto tgt = Target("$project/foo.o",
                       Command(CommandType.compile, assocListT("foo", ["bar"])),
                       Target("foo.c"));
    auto ninja = Ninja(Build(tgt), "/path/to/proj");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build /path/to/proj/foo.o: _ccompile /path/to/proj/foo.c",
                    ["foo = bar"])]);
}


void testPhonyRule() {
    auto tgt = Target("lephony",
                       Command.phony("whatever boo bop"),
                       [Target("toto"), Target("tata")],
                       [Target("implicit")]);
    auto ninja = Ninja(Build(tgt), "/path/to/proj");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build lephony: _phony /path/to/proj/toto /path/to/proj/tata | /path/to/proj/implicit",
                    ["cmd = whatever boo bop",
                     "pool = console"])]
        );
}

void testImplicitsWithNoIn() {
    Target[] emptyDependencies;
    auto stuff = Target("foo.o", "dmd -of$out -c $in", Target("foo.d"));
    auto foo = Target("$project/foodir", "mkdir -p $out", emptyDependencies, [stuff]);
    auto ninja = Ninja(Build(foo), "/path/to/proj"); //to make sure we can
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build .reggae/objs//path/to/proj/foodir.objs/foo.o: dmd /path/to/proj/foo.d",
                    ["before = -of",
                     "between = -c"]),
         NinjaEntry("build /path/to/proj/foodir: mkdir  | .reggae/objs//path/to/proj/foodir.objs/foo.o",
                    ["before = -p"]),
            ]);
    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule dmd",
                    ["command = dmd $before$out $between $in"]),
         NinjaEntry("rule mkdir",
                    ["command = mkdir $before $out$in"])
            ]);
}


void testCustomRuleInvolvingProjectPath() {
    auto foo = Target("foo.o", "$project/../dmd/src/dmd -of$out -c $in", Target("foo.d"));
    auto app = Target("app", "$project/../dmd/src/dmd -of$out -c $in", Target("foo.d"));
    auto ninja = Ninja(Build(app), "/path/to/proj");
    ninja.ruleEntries.shouldEqual(
        [NinjaEntry("rule dmd",
                    ["command = /path/to/proj/../dmd/src/dmd $before$out $between $in"]),
            ]);
}


void testTargetWithNoDependencies() {
    auto obj = Target("utmain.o", "dmd -of$out -c $in",
                       Target("utmain.d", "/home/atila/coding/d/dtest/bin/dtest -f $out --generate"));
    //before the fix this throws because of no $in and $out in the target
    auto ninja = Ninja(Build(obj), "/path/to/proj");
}
